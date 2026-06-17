import Foundation
import SwiftData

@MainActor
final class FeedService {
  private static let maxConcurrentRefreshes = 4

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
    guard !sources.isEmpty else { return 0 }

    var totalNew = 0
    for chunk in sources.chunked(into: Self.maxConcurrentRefreshes) {
      try await withThrowingTaskGroup(of: Int.self) { group in
        for source in chunk {
          group.addTask { [self] in
            try await self.refresh(source: source, save: false)
          }
        }
        for try await count in group {
          totalNew += count
        }
      }
    }
    try articleRepository.save()
    FeedRefreshNotifier.publish()
    return totalNew
  }

  /// Refresca todas las fuentes activas sin abortar si alguna falla (arranque en frío).
  @discardableResult
  func refreshAllLenient() async -> Int {
    let sources = (try? feedSourceRepository.fetchEnabled()) ?? []
    guard !sources.isEmpty else { return 0 }

    var totalNew = 0
    for chunk in sources.chunked(into: Self.maxConcurrentRefreshes) {
      await withTaskGroup(of: Int.self) { group in
        for source in chunk {
          group.addTask { [self] in
            return await self.refreshIgnoringErrors(source: source, save: false)
          }
        }
        for await count in group {
          totalNew += count
        }
      }
    }
    _ = try? articleRepository.save()
    FeedRefreshNotifier.publish()
    return totalNew
  }

  @discardableResult
  func refreshEnabledWithoutFetchedData() async -> Int {
    let pending = (try? feedSourceRepository.fetchEnabled())?.filter { $0.lastFetchedAt == nil } ?? []
    guard !pending.isEmpty else { return 0 }

    var totalNew = 0
    for source in pending {
      totalNew += await refreshIgnoringErrors(source: source, save: false)
    }
    _ = try? articleRepository.save()
    FeedRefreshNotifier.publish()
    return totalNew
  }

  @discardableResult
  func refresh(source: FeedSource, save: Bool = true) async throws -> Int {
    let (data, resolvedURL) = try await feedDownloader.downloadFeed(for: source)
    var parsed = try await Task.detached(priority: .userInitiated) {
      try RSSAtomParser().parse(data: data)
    }.value

    let usable = FeedJunkFilter.usableArticles(from: parsed)
    if usable.isEmpty {
      throw NetworkError.noData
    }
    parsed = ParsedFeed(
      title: parsed.title,
      siteURL: parsed.siteURL,
      feedURL: parsed.feedURL,
      articles: usable
    )

    if resolvedURL != source.feedURL {
      source.feedURL = resolvedURL
    }

    if let title = parsed.title, !title.isEmpty, source.name.isEmpty || source.isRecommended {
      source.name = title
    }
    if let siteURL = parsed.siteURL, source.platform != .x {
      source.siteURL = siteURL
    }
    source.platform = FeedPlatform.resolve(for: source)
    source.lastFetchedAt = .now

    _ = try articleRepository.upsertBatch(from: parsed.articles, source: source, save: save)
    try feedSourceRepository.update(source)
    if save {
      try articleRepository.save()
    }
    return parsed.articles.count
  }

  func discoverFeedTitle(from urlString: String) async throws -> (title: String, siteURL: String?) {
    let data = try await feedDownloader.downloadFeed(
      from: urlString,
      platform: FeedPlatform.detect(feedURL: urlString)
    )
    let parsed = try await Task.detached(priority: .utility) {
      try RSSAtomParser().parse(data: data)
    }.value
    return (parsed.title ?? urlString, parsed.siteURL)
  }

  func addSource(
    name: String,
    feedURL: String,
    siteURL: String? = nil,
    countryCode: String? = nil,
    feedDescription: String? = nil,
    platform: FeedPlatform? = nil
  ) async throws -> FeedSource {
    let source = try feedSourceRepository.add(
      name: name,
      feedURL: feedURL,
      siteURL: siteURL,
      countryCode: countryCode,
      feedDescription: feedDescription,
      platform: platform
    )
    source.isEnabled = true
    try feedSourceRepository.update(source)
    _ = try await refresh(source: source)
    FeedRefreshNotifier.publish()
    return source
  }

  func importOPML(data: Data) async throws -> Int {
    let outlines = try OPMLImporter().parse(data: data)
    var imported = 0
    var sourcesToRefresh: [FeedSource] = []

    for outline in outlines {
      let source = try feedSourceRepository.add(
        name: outline.title,
        feedURL: outline.xmlURL,
        siteURL: outline.htmlURL
      )
      source.isEnabled = true
      try feedSourceRepository.update(source)
      sourcesToRefresh.append(source)
      imported += 1
    }

    for source in sourcesToRefresh {
      _ = await refreshIgnoringErrors(source: source)
    }

    if imported > 0 {
      FeedRefreshNotifier.publish()
    }
    return imported
  }

  func exportOPML() throws -> String {
    let sources = try feedSourceRepository.fetchAll().filter(\.isEnabled)
    return OPMLExporter().export(sources: sources)
  }

  @discardableResult
  private func refreshIgnoringErrors(source: FeedSource, save: Bool = true) async -> Int {
    (try? await refresh(source: source, save: save)) ?? 0
  }
}

private extension Array {
  func chunked(into size: Int) -> [[Element]] {
    guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
    var chunks: [[Element]] = []
    chunks.reserveCapacity((count + size - 1) / size)
    var index = startIndex
    while index < endIndex {
      let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
      chunks.append(Array(self[index ..< end]))
      index = end
    }
    return chunks
  }
}
