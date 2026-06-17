import Foundation

struct RecentEngagement: Sendable {
  let match: ArticleMatchInput
  let engagedAt: Date
  /// Fuerza de la señal positiva (like > guardado > lectura profunda).
  let signalStrength: Double
}

struct ReadingInterestProfile {
  let sourceWeights: [UUID: Double]
  let keywordWeights: [String: Double]
  let categoryWeights: [String: Double]
  let platformWeights: [String: Double]
  let negativeSourceWeights: [UUID: Double]
  let negativeKeywordWeights: [String: Double]
  let negativeCategoryWeights: [String: Double]
  let recentEngagements: [RecentEngagement]
  /// 0…1 — cuánta señal hay; modula recencia vs personalización.
  let strength: Double

  static let empty = ReadingInterestProfile(
    sourceWeights: [:],
    keywordWeights: [:],
    categoryWeights: [:],
    platformWeights: [:],
    negativeSourceWeights: [:],
    negativeKeywordWeights: [:],
    negativeCategoryWeights: [:],
    recentEngagements: [],
    strength: 0
  )

  var isEmpty: Bool { strength < 0.06 }
}

enum ReadingInterestProfiler {
  private static let readWindowDays = 30.0
  private static let explicitWindowDays = 21.0
  private static let bounceDwellThreshold = 8.0
  private static let engagedDwellThreshold = 15.0
  private static let maxRecentEngagements = 12

  static func build(
    from articles: [Article],
    favoriteSourceIds: Set<UUID>,
    sourcesById: [UUID: FeedSource]
  ) -> ReadingInterestProfile {
    let now = Date()
    var sourceScores: [UUID: Double] = [:]
    var keywordScores: [String: Double] = [:]
    var categoryScores: [String: Double] = [:]
    var platformScores: [String: Double] = [:]
    var negativeSourceScores: [UUID: Double] = [:]
    var negativeKeywordScores: [String: Double] = [:]
    var negativeCategoryScores: [String: Double] = [:]
    var recentEngagements: [RecentEngagement] = []
    var signalCount = 0.0

    for sourceId in favoriteSourceIds {
      sourceScores[sourceId, default: 0] += 3.6
      signalCount += 0.85
      if let source = sourcesById[sourceId] {
        platformScores[source.platform.rawValue, default: 0] += 1.8
      }
    }

    for article in articles {
      if article.isSaved {
        signalCount += 1
        let weight = 3.2 * explicitRecencyMultiplier(for: article, now: now)
        accumulatePositive(
          article: article,
          weight: weight,
          sourcesById: sourcesById,
          sourceScores: &sourceScores,
          keywordScores: &keywordScores,
          categoryScores: &categoryScores,
          platformScores: &platformScores
        )
        appendRecentEngagement(
          article: article,
          signalStrength: 0.82,
          engagedAt: engagementDate(for: article, now: now),
          recentEngagements: &recentEngagements
        )
      }

      if article.isFavorite {
        signalCount += 1.2
        let weight = 4.2 * explicitRecencyMultiplier(for: article, now: now)
        accumulatePositive(
          article: article,
          weight: weight,
          sourcesById: sourcesById,
          sourceScores: &sourceScores,
          keywordScores: &keywordScores,
          categoryScores: &categoryScores,
          platformScores: &platformScores
        )
        appendRecentEngagement(
          article: article,
          signalStrength: 1.0,
          engagedAt: engagementDate(for: article, now: now),
          recentEngagements: &recentEngagements
        )
      }

      guard article.isRead else { continue }

      let dwellSeconds = article.readingHistory?.totalDwellSeconds ?? 0
      let engagedAt = engagementDate(for: article, now: now)

      if dwellSeconds > 0, dwellSeconds < bounceDwellThreshold {
        signalCount += 0.35
        let bounceWeight = (1 - dwellSeconds / bounceDwellThreshold) * sessionMultiplier(for: engagedAt, now: now)
        accumulateNegative(
          article: article,
          weight: bounceWeight,
          negativeSourceScores: &negativeSourceScores,
          negativeKeywordScores: &negativeKeywordScores,
          negativeCategoryScores: &negativeCategoryScores
        )
        continue
      }

      guard dwellSeconds >= bounceDwellThreshold else { continue }

      signalCount += 1
      let days = max(0, now.timeIntervalSince(engagedAt) / 86_400)
      let recencyMultiplier = max(0.12, 1 - days / readWindowDays)
      let dwellMultiplier = dwellSeconds >= engagedDwellThreshold
        ? 1 + min(dwellSeconds / 60, 6)
        : 1 + min(dwellSeconds / 120, 1.4)
      let completionRatio = article.readingTimeEstimate > 0
        ? dwellSeconds / Double(article.readingTimeEstimate * 60)
        : 0
      let completionMultiplier = completionRatio >= 0.45 ? 1 + min(completionRatio, 1.8) : 1
      let revisitMultiplier = 1 + min(Double(max(article.viewCount, 1) - 1) * 0.22, 1.1)
      let weight = recencyMultiplier * dwellMultiplier * completionMultiplier * revisitMultiplier
        * sessionMultiplier(for: engagedAt, now: now)

      accumulatePositive(
        article: article,
        weight: weight,
        sourcesById: sourcesById,
        sourceScores: &sourceScores,
        keywordScores: &keywordScores,
        categoryScores: &categoryScores,
        platformScores: &platformScores
      )

      if dwellSeconds >= engagedDwellThreshold || completionRatio >= 0.35 {
        let readStrength = min(1, 0.35 + dwellMultiplier * 0.12 + completionMultiplier * 0.08)
        appendRecentEngagement(
          article: article,
          signalStrength: readStrength,
          engagedAt: engagedAt,
          recentEngagements: &recentEngagements
        )
      }
    }

    recentEngagements.sort {
      if $0.engagedAt == $1.engagedAt { return $0.signalStrength > $1.signalStrength }
      return $0.engagedAt > $1.engagedAt
    }
    if recentEngagements.count > maxRecentEngagements {
      recentEngagements = Array(recentEngagements.prefix(maxRecentEngagements))
    }

    let strength = min(1, signalCount / 3.5)

    return ReadingInterestProfile(
      sourceWeights: normalize(sourceScores),
      keywordWeights: normalize(keywordScores),
      categoryWeights: normalize(categoryScores),
      platformWeights: normalize(platformScores),
      negativeSourceWeights: normalize(negativeSourceScores),
      negativeKeywordWeights: normalize(negativeKeywordScores),
      negativeCategoryWeights: normalize(negativeCategoryScores),
      recentEngagements: recentEngagements,
      strength: strength
    )
  }

  private static func appendRecentEngagement(
    article: Article,
    signalStrength: Double,
    engagedAt: Date,
    recentEngagements: inout [RecentEngagement]
  ) {
    recentEngagements.append(
      RecentEngagement(
        match: ArticleMatchInput(article),
        engagedAt: engagedAt,
        signalStrength: signalStrength
      )
    )
  }

  private static func engagementDate(for article: Article, now: Date) -> Date {
    article.readingHistory?.readAt ?? article.publishedAt ?? now
  }

  /// Las interacciones recientes pesan mucho más, como en feeds tipo TikTok.
  private static func sessionMultiplier(for engagedAt: Date, now: Date) -> Double {
    let hours = max(0, now.timeIntervalSince(engagedAt) / 3600)
    if hours <= 2 { return 2.4 }
    if hours <= 8 { return 1.7 }
    if hours <= 24 { return 1.25 }
    return 1
  }

  private static func accumulatePositive(
    article: Article,
    weight: Double,
    sourcesById: [UUID: FeedSource],
    sourceScores: inout [UUID: Double],
    keywordScores: inout [String: Double],
    categoryScores: inout [String: Double],
    platformScores: inout [String: Double]
  ) {
    sourceScores[article.sourceId, default: 0] += weight

    for keyword in ArticleTopicMatcher.interestKeywords(from: article) {
      keywordScores[keyword, default: 0] += weight * 0.72
    }
    for category in article.categoryNames.map({ $0.lowercased() }) where !category.isEmpty {
      categoryScores[category, default: 0] += weight * 0.9
      keywordScores[category, default: 0] += weight * 0.28
    }

    let platform = article.feedSource?.platform
      ?? sourcesById[article.sourceId]?.platform
      ?? FeedPlatform.detect(feedURL: article.originalFeedUrl)
    platformScores[platform.rawValue, default: 0] += weight * 0.95
  }

  private static func accumulateNegative(
    article: Article,
    weight: Double,
    negativeSourceScores: inout [UUID: Double],
    negativeKeywordScores: inout [String: Double],
    negativeCategoryScores: inout [String: Double]
  ) {
    negativeSourceScores[article.sourceId, default: 0] += weight * 0.85

    for keyword in ArticleTopicMatcher.interestKeywords(from: article) {
      negativeKeywordScores[keyword, default: 0] += weight * 0.55
    }
    for category in article.categoryNames.map({ $0.lowercased() }) where !category.isEmpty {
      negativeCategoryScores[category, default: 0] += weight * 0.75
      negativeKeywordScores[category, default: 0] += weight * 0.2
    }
  }

  private static func explicitRecencyMultiplier(for article: Article, now: Date) -> Double {
    let engagedAt = engagementDate(for: article, now: now)
    let days = max(0, now.timeIntervalSince(engagedAt) / 86_400)
    return max(0.35, 1 - days / explicitWindowDays) * sessionMultiplier(for: engagedAt, now: now)
  }

  private static func normalize(_ scores: [UUID: Double]) -> [UUID: Double] {
    guard let maxValue = scores.values.max(), maxValue > 0 else { return [:] }
    return scores.mapValues { smoothUnit($0, maxValue: maxValue) }
  }

  private static func normalize(_ scores: [String: Double]) -> [String: Double] {
    guard let maxValue = scores.values.max(), maxValue > 0 else { return [:] }
    return scores.mapValues { smoothUnit($0, maxValue: maxValue) }
  }

  private static func smoothUnit(_ value: Double, maxValue: Double) -> Double {
    sqrt(value / maxValue)
  }
}
