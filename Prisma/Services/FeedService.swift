import Foundation
import SwiftData

@MainActor
final class FeedService {
  private let feedSourceRepository: FeedSourceRepository
  private let articleRepository: ArticleRepository
  private let feedDownloader: FeedDownloader
  private let parser: FeedParserProtocol

  init(
    feedSourceRepository: FeedSourceRepository,
    articleRepository: ArticleRepository,
    feedDownloader: FeedDownloader,
    parser: FeedParserProtocol = RSSAtomParser()
  ) {
    self.feedSourceRepository = feedSourceRepository
    self.articleRepository = articleRepository
    self.feedDownloader = feedDownloader
    self.parser = parser
  }

  func refreshAll() async throws -> Int {
    let sources = try feedSourceRepository.fetchEnabled()
    var totalNew = 0
    for source in sources {
      totalNew += try await refresh(source: source)
    }
    return totalNew
  }

  @discardableResult
  func refresh(source: FeedSource) async throws -> Int {
    let data = try await feedDownloader.downloadFeed(from: source.feedURL)
    let parsed = try parser.parse(data: data)

    if let title = parsed.title, !title.isEmpty, source.name.isEmpty || source.isRecommended {
      source.name = title
    }
    if let siteURL = parsed.siteURL {
      source.siteURL = siteURL
    }
    source.lastFetchedAt = .now

    var count = 0
    for item in parsed.articles {
      _ = try articleRepository.upsert(from: item, source: source)
      count += 1
    }
    try feedSourceRepository.update(source)
    return count
  }

  func discoverFeedTitle(from urlString: String) async throws -> (title: String, siteURL: String?) {
    let data = try await feedDownloader.downloadFeed(from: urlString)
    let parsed = try parser.parse(data: data)
    return (parsed.title ?? urlString, parsed.siteURL)
  }

  func addSource(
    name: String,
    feedURL: String,
    siteURL: String? = nil,
    countryCode: String? = nil
  ) async throws -> FeedSource {
    let source = try feedSourceRepository.add(
      name: name,
      feedURL: feedURL,
      siteURL: siteURL,
      countryCode: countryCode
    )
    source.isEnabled = true
    try feedSourceRepository.update(source)
    _ = try await refresh(source: source)
    return source
  }

  func importOPML(data: Data) throws -> Int {
    let outlines = try OPMLImporter().parse(data: data)
    var imported = 0
    for outline in outlines {
      _ = try feedSourceRepository.add(
        name: outline.title,
        feedURL: outline.xmlURL,
        siteURL: outline.htmlURL
      )
      imported += 1
    }
    return imported
  }

  func exportOPML() throws -> String {
    let sources = try feedSourceRepository.fetchAll().filter(\.isEnabled)
    return OPMLExporter().export(sources: sources)
  }
}
