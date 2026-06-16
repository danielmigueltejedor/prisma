import XCTest
@testable import Prisma

final class RecommendationEngineTests: XCTestCase {
  func testFavoritesRankHigher() {
    let engine = RecommendationEngine()
    let favoriteId = UUID()
    let otherId = UUID()

    let favoriteArticle = Article(
      id: "1",
      title: "Favorite",
      url: "https://a.com/1",
      sourceName: "A",
      sourceId: favoriteId,
      publishedAt: .now,
      originalFeedUrl: "https://a.com/feed"
    )
    let otherArticle = Article(
      id: "2",
      title: "Other",
      url: "https://b.com/2",
      sourceName: "B",
      sourceId: otherId,
      publishedAt: .now,
      originalFeedUrl: "https://b.com/feed"
    )

    let ranked = engine.rank(
      articles: [otherArticle, favoriteArticle],
      favoriteSourceIds: [favoriteId],
      savedCategoryNames: [],
      readSourceCounts: [:],
      blockedKeywords: [],
      blockedSourceIds: []
    )

    XCTAssertEqual(ranked.first?.id, "1")
  }
}
