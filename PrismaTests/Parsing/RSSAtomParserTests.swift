import XCTest
@testable import Prisma

final class RSSAtomParserTests: XCTestCase {
  func testParsesRSS2() throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Test Feed</title>
        <link>https://example.com</link>
        <item>
          <title>Hello World</title>
          <link>https://example.com/post</link>
          <guid>abc123</guid>
          <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
          <description><![CDATA[<p>Summary here</p>]]></description>
        </item>
      </channel>
    </rss>
    """.data(using: .utf8)!

    let parser = RSSAtomParser()
    let feed = try parser.parse(data: xml)

    XCTAssertEqual(feed.title, "Test Feed")
    XCTAssertEqual(feed.articles.count, 1)
    XCTAssertEqual(feed.articles[0].title, "Hello World")
    XCTAssertEqual(feed.articles[0].link, "https://example.com/post")
  }

  func testParsesAtom() throws {
    let xml = """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Atom Feed</title>
      <entry>
        <title>Atom Post</title>
        <link href="https://example.com/atom"/>
        <id>tag:example.com,2024:1</id>
        <updated>2024-01-01T12:00:00Z</updated>
        <summary>Atom summary</summary>
      </entry>
    </feed>
    """.data(using: .utf8)!

    let parser = RSSAtomParser()
    let feed = try parser.parse(data: xml)

    XCTAssertEqual(feed.title, "Atom Feed")
    XCTAssertEqual(feed.articles.count, 1)
    XCTAssertEqual(feed.articles[0].title, "Atom Post")
  }
}
