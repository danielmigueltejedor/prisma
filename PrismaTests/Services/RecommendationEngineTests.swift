import XCTest
@testable import Prisma

final class RecommendationEngineTests: XCTestCase {
  func testFavoritesRankHigher() {
    let engine = RecommendationEngine()
    let favoriteId = UUID()
    let otherId = UUID()

    let favoriteArticle = makeArticle(id: "1", title: "Favorite", sourceId: favoriteId)
    let otherArticle = makeArticle(id: "2", title: "Other", sourceId: otherId)

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

  func testUnreadRanksAboveReadWithSameSource() {
    let engine = RecommendationEngine()
    let sourceId = UUID()

    let unread = makeArticle(id: "unread", title: "Fresh story", sourceId: sourceId)
    var read = makeArticle(id: "read", title: "Old story", sourceId: sourceId)
    read.isRead = true

    let ranked = engine.rank(
      articles: [read, unread],
      favoriteSourceIds: [sourceId],
      savedCategoryNames: [],
      readSourceCounts: [sourceId: 1],
      blockedKeywords: [],
      blockedSourceIds: []
    )

    XCTAssertEqual(ranked.first?.id, "unread")
  }

  func testSavedArticleBuildsInterestWithoutRead() {
    let sourceId = UUID()
    var saved = makeArticle(id: "saved", title: "Inteligencia artificial en salud", sourceId: sourceId)
    saved.isSaved = true
    saved.categoryNames = ["Tecnología"]

    let profile = ReadingInterestProfiler.build(
      from: [saved],
      favoriteSourceIds: [],
      sourcesById: [:]
    )

    XCTAssertFalse(profile.isEmpty)
    XCTAssertGreaterThan(profile.categoryWeights["tecnología"] ?? 0, 0)
    XCTAssertGreaterThan(profile.keywordWeights["inteligencia"] ?? 0, 0)
    XCTAssertEqual(profile.recentEngagements.count, 1)
  }

  func testDiversityLimitsSameSourceInTopResults() {
    let engine = RecommendationEngine()
    let dominantSource = UUID()
    let otherSource = UUID()

    let dominantArticles = (0..<5).map { index in
      makeArticle(id: "d\(index)", title: "Dominant \(index)", sourceId: dominantSource)
    }
    let otherArticles = (0..<3).map { index in
      makeArticle(id: "o\(index)", title: "Other \(index)", sourceId: otherSource)
    }

    let ranked = engine.rank(
      articles: dominantArticles + otherArticles,
      favoriteSourceIds: [dominantSource],
      savedCategoryNames: [],
      readSourceCounts: [:],
      blockedKeywords: [],
      blockedSourceIds: []
    )

    let topFive = ranked.prefix(5)
    let dominantCount = topFive.filter { $0.sourceId == dominantSource }.count
    let otherCount = topFive.filter { $0.sourceId == otherSource }.count

    XCTAssertLessThanOrEqual(dominantCount, 3)
    XCTAssertGreaterThan(otherCount, 0)
  }

  func testRecentEngagementBoostsSimilarUnread() {
    let engine = RecommendationEngine()
    let techSource = UUID()
    let sportsSource = UUID()

    var liked = makeArticle(
      id: "liked",
      title: "Mbappé marca dos goles en el Mundial 2026",
      sourceId: techSource,
      categories: ["Deportes"]
    )
    liked.isFavorite = true
    liked.readingHistory = ReadingHistory(readAt: .now, totalDwellSeconds: 90)

    let similarUnread = makeArticle(
      id: "similar",
      title: "Francia gana gracias a Mbappé en el Mundial",
      sourceId: sportsSource,
      categories: ["Deportes"]
    )
    let unrelated = makeArticle(
      id: "other",
      title: "Previsión del tiempo para mañana en Madrid",
      sourceId: sportsSource,
      categories: ["General"]
    )

    let profile = ReadingInterestProfiler.build(
      from: [liked],
      favoriteSourceIds: [],
      sourcesById: [:]
    )

    let ranked = engine.rank(
      articles: [unrelated, similarUnread],
      favoriteSourceIds: [],
      savedCategoryNames: [],
      readSourceCounts: [:],
      blockedKeywords: [],
      blockedSourceIds: [],
      interest: profile
    )

    XCTAssertEqual(ranked.first?.id, "similar")
  }

  func testBounceReducesSimilarTopicRanking() {
    let engine = RecommendationEngine()
    let sourceId = UUID()

    var bounced = makeArticle(
      id: "bounced",
      title: "Horóscopo diario para Cáncer",
      sourceId: sourceId,
      categories: ["Estilo"]
    )
    bounced.isRead = true
    bounced.readingHistory = ReadingHistory(readAt: .now, totalDwellSeconds: 3)

    let similarUnread = makeArticle(
      id: "similar",
      title: "Horóscopo semanal para Cáncer y Escorpio",
      sourceId: sourceId,
      categories: ["Estilo"]
    )
    let neutralUnread = makeArticle(
      id: "neutral",
      title: "El Banco Central mantiene tipos de interés",
      sourceId: sourceId,
      categories: ["Economía"]
    )

    let profile = ReadingInterestProfiler.build(
      from: [bounced],
      favoriteSourceIds: [],
      sourcesById: [:]
    )

    let ranked = engine.rank(
      articles: [similarUnread, neutralUnread],
      favoriteSourceIds: [],
      savedCategoryNames: [],
      readSourceCounts: [:],
      blockedKeywords: [],
      blockedSourceIds: [],
      interest: profile
    )

    XCTAssertEqual(ranked.first?.id, "neutral")
  }

  func testFewInteractionsActivatePersonalization() {
    var saved = makeArticle(id: "saved", title: "Startups europeas de inteligencia artificial", sourceId: UUID())
    saved.isSaved = true
    saved.categoryNames = ["Tecnología"]

    let profile = ReadingInterestProfiler.build(
      from: [saved],
      favoriteSourceIds: [],
      sourcesById: [:]
    )

    XCTAssertGreaterThanOrEqual(profile.strength, 0.25)
  }

  private func makeArticle(
    id: String,
    title: String,
    sourceId: UUID,
    categories: [String] = []
  ) -> Article {
    Article(
      id: id,
      title: title,
      url: "https://example.com/\(id)",
      sourceName: "Source",
      sourceId: sourceId,
      publishedAt: .now,
      categoryNames: categories,
      originalFeedUrl: "https://example.com/feed"
    )
  }
}
