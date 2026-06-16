import Foundation

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
    title
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { $0.count >= 4 && !stopWords.contains($0) }
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
    candidates
      .filter { $0.id != article.id }
      .map { ($0, similarity(between: article, and: $0)) }
      .filter { $0.1 >= 8 }
      .sorted { $0.1 > $1.1 }
      .prefix(limit)
      .map(\.0)
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
