import Foundation

struct ArticleMatchInput: Sendable {
  let id: String
  let title: String
  let sourceId: UUID
  let publishedAt: Date?
  let categoryNames: [String]

  init(_ article: Article) {
    id = article.id
    title = article.title
    sourceId = article.sourceId
    publishedAt = article.publishedAt
    categoryNames = article.categoryNames
  }
}

enum ArticleTopicMatcher {
  private static let stopWords: Set<String> = [
    "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
    "from", "as", "is", "was", "are", "were", "be", "been", "being", "have", "has", "had",
    "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "shall",
    "can", "need", "dare", "ought", "used", "it", "its", "this", "that", "these", "those",
    "he", "she", "they", "we", "you", "i", "me", "him", "her", "them", "us", "my", "your",
    "his", "their", "our", "who", "whom", "which", "what", "when", "where", "why", "how",
    "not", "no", "nor", "so", "than", "too", "very", "just", "about", "into", "over", "after",
    "before", "between", "under", "again", "further", "then", "once", "here", "there", "all",
    "each", "few", "more", "most", "other", "some", "such", "only", "own", "same", "s", "t",
    "el", "la", "los", "las", "un", "una", "unos", "unas", "de", "del", "al", "y", "o", "en",
    "con", "por", "para", "que", "se", "su", "sus", "es", "son", "como", "más", "mas", "pero",
    "sobre", "entre", "sin", "hasta", "desde", "este", "esta", "estos", "estas", "ese", "esa",
  ]

  static func keywords(from title: String) -> Set<String> {
    keywords(fromText: title)
  }

  static func interestKeywords(from article: Article) -> Set<String> {
    var keys = keywords(fromText: article.title)
    if let summary = article.plainSummary ?? article.summary {
      keys.formUnion(keywords(fromText: summary, maxCount: 10))
    }
    return keys
  }

  private static func keywords(fromText text: String, maxCount: Int? = nil) -> Set<String> {
    let tokens = text
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { $0.count >= 4 && !stopWords.contains($0) }

    if let maxCount {
      return Set(tokens.prefix(maxCount))
    }
    return Set(tokens)
  }

  /// Stricter score for cross-source "same story" detection (concrete event, not broad topic).
  static func sameStorySimilarity(between lhs: Article, and rhs: Article) -> Double {
    guard lhs.id != rhs.id else { return 0 }

    let leftKeys = keywords(from: lhs.title)
    let rightKeys = keywords(from: rhs.title)
    let overlap = leftKeys.intersection(rightKeys)

    if overlap.count < 2 { return 0 }
    if overlap.count < 3 {
      let strongOverlap = overlap.filter { $0.count >= 6 }
      guard strongOverlap.count >= 2 else { return 0 }
    }

    var score = Double(overlap.count) * 16

    let leftRatio = Double(overlap.count) / Double(max(leftKeys.count, 1))
    let rightRatio = Double(overlap.count) / Double(max(rightKeys.count, 1))
    score += min(leftRatio, rightRatio) * 20

    let leftNumbers = significantNumbers(in: lhs.title)
    let rightNumbers = significantNumbers(in: rhs.title)
    score += Double(leftNumbers.intersection(rightNumbers).count) * 28

    if let lp = lhs.publishedAt, let rp = rhs.publishedAt {
      let hours = abs(lp.timeIntervalSince(rp)) / 3600
      guard hours <= 72 else { return 0 }
      score += max(0, 14 - hours / 5)
    } else {
      score *= 0.6
    }

    if lhs.sourceId != rhs.sourceId { score += 6 }

    return score
  }

  private static func significantNumbers(in title: String) -> Set<String> {
    title
      .components(separatedBy: CharacterSet.decimalDigits.inverted)
      .filter { $0.count >= 3 }
      .reduce(into: Set<String>()) { $0.insert($1) }
  }

  static func similarity(between lhs: Article, and rhs: Article) -> Double {
    guard lhs.id != rhs.id else { return 0 }

    let titleOverlap = keywords(from: lhs.title).intersection(keywords(from: rhs.title))
    var score = Double(titleOverlap.count) * 12

    let categoryOverlap = Set(lhs.categoryNames.map { $0.lowercased() })
      .intersection(rhs.categoryNames.map { $0.lowercased() })
    score += Double(categoryOverlap.count) * 6

    if lhs.sourceId != rhs.sourceId { score += 4 }

    if let lp = lhs.publishedAt, let rp = rhs.publishedAt {
      let hours = abs(lp.timeIntervalSince(rp)) / 3600
      if hours < 48 { score += max(0, 10 - hours / 5) }
    }

    return score
  }

  static func related(to article: Article, from candidates: [Article], limit: Int = 8) -> [Article] {
    let anchor = ArticleMatchInput(article)
    let ranked = relatedIDs(anchor: anchor, candidates: candidates.map(ArticleMatchInput.init), limit: limit)
    let order = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($1, $0) })
    return candidates
      .filter { order[$0.id] != nil }
      .sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
  }

  static func relatedIDs(
    anchor: ArticleMatchInput,
    candidates: [ArticleMatchInput],
    limit: Int = 8
  ) -> [String] {
    candidates
      .filter { $0.id != anchor.id }
      .map { ($0.id, similarity(anchor: anchor, candidate: $0)) }
      .filter { $0.1 >= 8 }
      .sorted { $0.1 > $1.1 }
      .prefix(limit)
      .map(\.0)
  }

  static func sameStoryIDs(
    anchor: ArticleMatchInput,
    candidates: [ArticleMatchInput],
    minimumScore: Double,
    limit: Int = 6
  ) -> [String] {
    candidates
      .filter { $0.id != anchor.id && $0.sourceId != anchor.sourceId }
      .map { ($0.id, sameStorySimilarity(anchor: anchor, candidate: $0)) }
      .filter { $0.1 >= minimumScore }
      .sorted { lhs, rhs in
        if lhs.1 == rhs.1 {
          let leftDate = candidates.first { $0.id == lhs.0 }?.publishedAt ?? .distantPast
          let rightDate = candidates.first { $0.id == rhs.0 }?.publishedAt ?? .distantPast
          return leftDate > rightDate
        }
        return lhs.1 > rhs.1
      }
      .prefix(limit)
      .map(\.0)
  }

  static func similarity(anchor: ArticleMatchInput, candidate: ArticleMatchInput) -> Double {
    guard anchor.id != candidate.id else { return 0 }

    let titleOverlap = keywords(from: anchor.title).intersection(keywords(from: candidate.title))
    var score = Double(titleOverlap.count) * 12

    let categoryOverlap = Set(anchor.categoryNames.map { $0.lowercased() })
      .intersection(candidate.categoryNames.map { $0.lowercased() })
    score += Double(categoryOverlap.count) * 6

    if anchor.sourceId != candidate.sourceId { score += 4 }

    if let lp = anchor.publishedAt, let rp = candidate.publishedAt {
      let hours = abs(lp.timeIntervalSince(rp)) / 3600
      if hours < 48 { score += max(0, 10 - hours / 5) }
    }

    return score
  }

  static func sameStorySimilarity(anchor: ArticleMatchInput, candidate: ArticleMatchInput) -> Double {
    guard anchor.id != candidate.id else { return 0 }

    let leftKeys = keywords(from: anchor.title)
    let rightKeys = keywords(from: candidate.title)
    let overlap = leftKeys.intersection(rightKeys)

    if overlap.count < 2 { return 0 }
    if overlap.count < 3 {
      let strongOverlap = overlap.filter { $0.count >= 6 }
      guard strongOverlap.count >= 2 else { return 0 }
    }

    var score = Double(overlap.count) * 16

    let leftRatio = Double(overlap.count) / Double(max(leftKeys.count, 1))
    let rightRatio = Double(overlap.count) / Double(max(rightKeys.count, 1))
    score += min(leftRatio, rightRatio) * 20

    let leftNumbers = significantNumbers(in: anchor.title)
    let rightNumbers = significantNumbers(in: candidate.title)
    score += Double(leftNumbers.intersection(rightNumbers).count) * 28

    if let lp = anchor.publishedAt, let rp = candidate.publishedAt {
      let hours = abs(lp.timeIntervalSince(rp)) / 3600
      guard hours <= 72 else { return 0 }
      score += max(0, 14 - hours / 5)
    } else {
      score *= 0.6
    }

    if anchor.sourceId != candidate.sourceId { score += 6 }

    return score
  }

  static func cluster(_ articles: [Article], minimumScore: Double = 10) -> [[Article]] {
    var remaining = articles
    var clusters: [[Article]] = []

    while let seed = remaining.first {
      remaining.removeFirst()
      var cluster = [seed]

      remaining.removeAll { candidate in
        let matchesCluster = cluster.contains {
          similarity(between: $0, and: candidate) >= minimumScore
        }
        if matchesCluster { cluster.append(candidate) }
        return matchesCluster
      }

      clusters.append(cluster)
    }

    return clusters
      .filter { $0.count >= 2 }
      .sorted { $0.count > $1.count }
  }
}
