import XCTest
@testable import Prisma

final class LiveTimelineParserTests: XCTestCase {
  func testParsesTimeBlocksFromHTML() {
    let html = """
    <time datetime="2026-06-17T14:32:00Z">14:32</time>
    <p>Gol de Vinícius tras una contra rápida.</p>
    <time datetime="2026-06-17T14:18:00Z">14:18</time>
    <p>Tarjeta amarilla para el centrocampista local.</p>
    """

    let entries = LiveTimelineParser.parse(html: html)
    XCTAssertGreaterThanOrEqual(entries.count, 2)
    XCTAssertTrue(entries.contains { $0.body.contains("Vinícius") })
  }

  func testIntegratesLiveFeedUpdatesIntoSingleArticle() {
    let sourceId = UUID()
    let source = FeedSource(
      id: sourceId,
      name: "Test",
      feedURL: "https://example.com/rss",
      siteURL: "https://example.com"
    )

    let items = [
      ParsedArticle(
        title: "14:32 Gol de Vinícius",
        link: "https://example.com/partido#1",
        guid: "1",
        author: nil,
        publishedAt: Date(timeIntervalSince1970: 100),
        updatedAt: nil,
        summary: "Marca el delantero tras un pase de Rodrygo.",
        content: nil,
        imageURL: nil,
        categories: [],
        contentAvailability: .partialRSS
      ),
      ParsedArticle(
        title: "14:18 Tarjeta amarilla",
        link: "https://example.com/partido#2",
        guid: "2",
        author: nil,
        publishedAt: Date(timeIntervalSince1970: 200),
        updatedAt: nil,
        summary: "Amonestación por entrada dura en el centro del campo.",
        content: nil,
        imageURL: nil,
        categories: [],
        contentAvailability: .partialRSS
      ),
    ]

    let integrated = LiveFeedIntegrator.integrate(items, source: source)
    XCTAssertEqual(integrated.count, 1)
    let entries = LiveTimelineCodec.decode(from: integrated[0].content).0
    XCTAssertEqual(entries.count, 2)
  }

  func testDetectsLiveArticleWithTimelineEntries() {
    let sourceId = UUID()
    let source = FeedSource(
      id: sourceId,
      name: "Test",
      feedURL: "https://example.com/rss",
      siteURL: "https://example.com"
    )

    let items = [
      ParsedArticle(
        title: "22:45 Mbappé mete un pase en largo",
        link: "https://example.com/partido#1",
        guid: "1",
        author: nil,
        publishedAt: Date(timeIntervalSince1970: 100),
        updatedAt: nil,
        summary: "Pase en largo que falla Olise.",
        content: nil,
        imageURL: nil,
        categories: [],
        contentAvailability: .partialRSS
      ),
      ParsedArticle(
        title: "22:51 Falta para Francia",
        link: "https://example.com/partido#2",
        guid: "2",
        author: nil,
        publishedAt: Date(timeIntervalSince1970: 200),
        updatedAt: nil,
        summary: "Falta peligrosa cerca del área.",
        content: nil,
        imageURL: nil,
        categories: [],
        contentAvailability: .partialRSS
      ),
    ]

    let integrated = LiveFeedIntegrator.integrate(items, source: source)
    XCTAssertEqual(integrated.count, 1)

    let article = Article(
      id: Article.stableID(guid: integrated[0].guid, link: integrated[0].link),
      title: integrated[0].title,
      url: integrated[0].link,
      sourceName: "Test",
      sourceId: sourceId,
      publishedAt: integrated[0].publishedAt,
      content: integrated[0].content,
      summary: integrated[0].summary,
      originalFeedUrl: source.feedURL
    )

    XCTAssertTrue(LiveCoverageDetector.isLiveArticle(article))
  }

  func testTitleWithEnDirectoIsNotLiveWithoutTimeline() {
    let article = Article(
      id: "live-1",
      title: "Francia - Senegal, el partido del Mundial 2026 en directo",
      url: "https://example.com/deportes/partido",
      sourceName: "Test",
      sourceId: UUID(),
      publishedAt: .now,
      summary: "Mbappé, tras su doblete, habla en rueda de prensa.",
      originalFeedUrl: "https://example.com/rss"
    )

    XCTAssertFalse(LiveCoverageDetector.isLiveArticle(article))
  }
}
