import Foundation

struct RecommendationEngine {
  private let blocklist = BlocklistService()

  func rank(
    articles: [Article],
    favoriteSourceIds: Set<UUID>,
    savedCategoryNames: Set<String>,
    readSourceCounts: [UUID: Int],
    blockedKeywords: [String],
    blockedSourceIds: Set<UUID>
  ) -> [Article] {
    let filtered = articles.filter {
      !blocklist.isBlocked(article: $0, blockedKeywords: blockedKeywords, blockedSourceIds: blockedSourceIds)
    }

    return filtered.sorted { lhs, rhs in
      score(
        for: lhs,
        favoriteSourceIds: favoriteSourceIds,
        savedCategoryNames: savedCategoryNames,
        readSourceCounts: readSourceCounts
      ) > score(
        for: rhs,
        favoriteSourceIds: favoriteSourceIds,
        savedCategoryNames: savedCategoryNames,
        readSourceCounts: readSourceCounts
      )
    }
  }

  private func score(
    for article: Article,
    favoriteSourceIds: Set<UUID>,
    savedCategoryNames: Set<String>,
    readSourceCounts: [UUID: Int]
  ) -> Double {
    var value = 0.0

    if favoriteSourceIds.contains(article.sourceId) { value += 30 }
    if article.isSaved || article.isFavorite { value += 20 }
    if article.isRead { value -= 25 }

    let categoryOverlap = Set(article.categoryNames.map { $0.lowercased() })
      .intersection(savedCategoryNames.map { $0.lowercased() })
    value += Double(categoryOverlap.count) * 8

    if let readCount = readSourceCounts[article.sourceId] {
      value += Double(min(readCount, 10)) * 2
    }

    if let published = article.publishedAt {
      let hours = Date().timeIntervalSince(published) / 3600
      value += max(0, 48 - hours)
    }

    return value
  }
}
