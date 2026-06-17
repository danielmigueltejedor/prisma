import Foundation

struct RecommendationEngine {
  private let blocklist = BlocklistService()

  func rank(
    articles: [Article],
    favoriteSourceIds: Set<UUID>,
    savedCategoryNames: Set<String>,
    readSourceCounts: [UUID: Int],
    blockedKeywords: [String],
    blockedSourceIds: Set<UUID>,
    interest: ReadingInterestProfile = .empty
  ) -> [Article] {
    let filtered = articles.filter {
      !blocklist.isBlocked(article: $0, blockedKeywords: blockedKeywords, blockedSourceIds: blockedSourceIds)
    }

    let scored = filtered.map { article in
      (
        article,
        score(
          for: article,
          favoriteSourceIds: favoriteSourceIds,
          savedCategoryNames: savedCategoryNames,
          readSourceCounts: readSourceCounts,
          interest: interest
        )
      )
    }
    .sorted { lhs, rhs in
      if lhs.1 == rhs.1 {
        return (lhs.0.publishedAt ?? .distantPast) > (rhs.0.publishedAt ?? .distantPast)
      }
      return lhs.1 > rhs.1
    }

    return diversifyAndExplore(Array(scored), interest: interest)
  }

  private func diversifyAndExplore(
    _ scored: [(Article, Double)],
    interest: ReadingInterestProfile
  ) -> [Article] {
    var ranked: [Article] = []
    var deferred: [Article] = []
    var explorePool: [Article] = []
    var sourceCounts: [UUID: Int] = [:]
    var categoryCounts: [String: Int] = [:]

    for (article, score) in scored {
      let sourceCount = sourceCounts[article.sourceId, default: 0]
      let inTopTier = ranked.count < 30
      let tooManyFromSource = inTopTier && sourceCount >= 3
      let duplicateStory = inTopTier && ranked.prefix(12).contains {
        ArticleTopicMatcher.sameStorySimilarity(between: $0, and: article) >= 36
      }

      if tooManyFromSource || duplicateStory {
        deferred.append(article)
      } else if inTopTier, interest.strength >= 0.25, isExploreCandidate(article, score: score, interest: interest) {
        explorePool.append(article)
      } else {
        ranked.append(article)
        sourceCounts[article.sourceId, default: 0] += 1
        for category in article.categoryNames.map({ $0.lowercased() }) {
          categoryCounts[category, default: 0] += 1
        }
      }
    }

    ranked = injectExploration(into: ranked, from: explorePool, categoryCounts: categoryCounts)
    return ranked + deferred
  }

  private func isExploreCandidate(
    _ article: Article,
    score: Double,
    interest: ReadingInterestProfile
  ) -> Bool {
    guard score > 18 else { return false }
    let sourceAffinity = interest.sourceWeights[article.sourceId] ?? 0
    let categoryAffinity = article.categoryNames
      .map { $0.lowercased() }
      .compactMap { interest.categoryWeights[$0] }
      .max() ?? 0
    return sourceAffinity < 0.35 && categoryAffinity < 0.35
  }

  private func injectExploration(
    into ranked: [Article],
    from explorePool: [Article],
    categoryCounts: [String: Int]
  ) -> [Article] {
    guard !explorePool.isEmpty else { return ranked }

    var result = ranked
    var usedExploreIDs = Set<String>()
    let insertionSlots = [5, 11, 18]

    for slot in insertionSlots {
      guard slot <= result.count else { continue }
      guard let candidate = explorePool.first(where: { article in
        guard !usedExploreIDs.contains(article.id) else { return false }
        guard !result.contains(where: { $0.id == article.id }) else { return false }
        let categories = article.categoryNames.map { $0.lowercased() }
        let overrepresented = categories.contains { categoryCounts[$0, default: 0] >= 4 }
        return !overrepresented
      }) else { continue }

      usedExploreIDs.insert(candidate.id)
      result.insert(candidate, at: min(slot, result.count))
    }

    return result
  }

  private func score(
    for article: Article,
    favoriteSourceIds: Set<UUID>,
    savedCategoryNames: Set<String>,
    readSourceCounts: [UUID: Int],
    interest: ReadingInterestProfile
  ) -> Double {
    var value = 0.0
    let personalized = !interest.isEmpty

    if !article.isRead { value += personalized ? 28 : 34 }

    if favoriteSourceIds.contains(article.sourceId) {
      value += personalized ? 22 : 38
    }

    if article.isFavorite { value += 40 }
    else if article.isSaved { value += 32 }

    if article.isRead {
      let dwell = article.readingHistory?.totalDwellSeconds ?? 0
      if dwell > 0, dwell < 8 { value -= 18 }
      else if dwell >= 60 { value -= personalized ? 4 : 8 }
      else { value -= personalized ? 10 : 14 }
    }

    let loweredCategories = Set(article.categoryNames.map { $0.lowercased() })
    let categoryOverlap = loweredCategories.intersection(savedCategoryNames.map { $0.lowercased() })
    value += Double(categoryOverlap.count) * 12

    if let readCount = readSourceCounts[article.sourceId] {
      value += Double(min(readCount, 10)) * (personalized ? 1.8 : 2.8)
    }

    let recencyBase: Double
    if let published = article.publishedAt {
      let hours = Date().timeIntervalSince(published) / 3600
      recencyBase = max(0, 34 - hours * 0.85)
    } else {
      recencyBase = 5
    }
    let recencyScale = personalized ? max(0.18, 1 - interest.strength * 0.78) : 1
    value += recencyBase * recencyScale

    if personalized {
      value += (interest.sourceWeights[article.sourceId] ?? 0) * 72

      let articleKeywords = ArticleTopicMatcher.interestKeywords(from: article)
      let keywordScore = articleKeywords.reduce(0.0) {
        $0 + (interest.keywordWeights[$1] ?? 0)
      }
      value += keywordScore * 42

      let categoryScore = loweredCategories.reduce(0.0) {
        $0 + (interest.categoryWeights[$1] ?? 0)
      }
      value += categoryScore * 34

      let platform = article.feedSource?.platform
        ?? FeedPlatform.detect(feedURL: article.originalFeedUrl)
      value += (interest.platformWeights[platform.rawValue] ?? 0) * 28

      value += recentAffinityScore(for: article, interest: interest)
      value -= negativeAffinityPenalty(for: article, interest: interest)
    }

    return value
  }

  /// Impulso tipo TikTok/YouTube: lo parecido a lo que acabas de disfrutar sube enseguida.
  private func recentAffinityScore(for article: Article, interest: ReadingInterestProfile) -> Double {
    guard !interest.recentEngagements.isEmpty else { return 0 }

    let candidate = ArticleMatchInput(article)
    let now = Date()
    var best = 0.0

    for engagement in interest.recentEngagements {
      let similarity = ArticleTopicMatcher.similarity(anchor: engagement.match, candidate: candidate)
      let storySimilarity = ArticleTopicMatcher.sameStorySimilarity(
        anchor: engagement.match,
        candidate: candidate
      )
      let blended = max(similarity, storySimilarity * 0.92)
      guard blended >= 6 else { continue }

      let hours = max(0, now.timeIntervalSince(engagement.engagedAt) / 3600)
      let recencyBoost: Double
      if hours <= 2 { recencyBoost = 2.2 }
      else if hours <= 8 { recencyBoost = 1.55 }
      else if hours <= 24 { recencyBoost = 1.15 }
      else { recencyBoost = max(0.35, 1 - hours / 168) }

      let candidateScore = blended * engagement.signalStrength * recencyBoost
      best = max(best, candidateScore)
    }

    return best * 4.8
  }

  private func negativeAffinityPenalty(for article: Article, interest: ReadingInterestProfile) -> Double {
    var penalty = (interest.negativeSourceWeights[article.sourceId] ?? 0) * 38

    let articleKeywords = ArticleTopicMatcher.interestKeywords(from: article)
    penalty += articleKeywords.reduce(0.0) {
      $0 + (interest.negativeKeywordWeights[$1] ?? 0)
    } * 26

    let loweredCategories = Set(article.categoryNames.map { $0.lowercased() })
    penalty += loweredCategories.reduce(0.0) {
      $0 + (interest.negativeCategoryWeights[$1] ?? 0)
    } * 20

    return penalty
  }
}
