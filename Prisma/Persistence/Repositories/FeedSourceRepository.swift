import Foundation
import SwiftData

@MainActor
final class FeedSourceRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func fetchBlockedSourceIds() throws -> Set<UUID> {
    let descriptor = FetchDescriptor<FeedSource>(
      predicate: #Predicate { $0.isBlocked }
    )
    return Set(try context.fetch(descriptor).map(\.id))
  }

  func fetchAll() throws -> [FeedSource] {
    let descriptor = FetchDescriptor<FeedSource>(
      sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
    )
    return try context.fetch(descriptor)
  }

  func fetchEnabled() throws -> [FeedSource] {
    let descriptor = FetchDescriptor<FeedSource>(
      predicate: #Predicate { $0.isEnabled && !$0.isBlocked },
      sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
    )
    return try context.fetch(descriptor)
  }

  func fetchFavorites() throws -> [FeedSource] {
    let descriptor = FetchDescriptor<FeedSource>(
      predicate: #Predicate { $0.isFavorite && $0.isEnabled && !$0.isBlocked },
      sortBy: [SortDescriptor(\.name)]
    )
    return try context.fetch(descriptor)
  }

  func find(by id: UUID) throws -> FeedSource? {
    let descriptor = FetchDescriptor<FeedSource>(
      predicate: #Predicate { $0.id == id }
    )
    return try context.fetch(descriptor).first
  }

  func find(byURL url: String) throws -> FeedSource? {
    let descriptor = FetchDescriptor<FeedSource>(
      predicate: #Predicate { $0.feedURL == url }
    )
    return try context.fetch(descriptor).first
  }

  @discardableResult
  func add(
    name: String,
    feedURL: String,
    siteURL: String? = nil,
    isRecommended: Bool = false,
    countryCode: String? = nil,
    feedDescription: String? = nil,
    platform: FeedPlatform? = nil
  ) throws -> FeedSource {
    if let existing = try find(byURL: feedURL) {
      if existing.countryCode == nil, let countryCode {
        existing.countryCode = countryCode
      }
      if existing.feedDescription == nil, let feedDescription {
        existing.feedDescription = feedDescription
      }
      if existing.platform == .news, let platform {
        existing.platform = platform
      }
      try context.save()
      return existing
    }
    let resolvedPlatform = platform ?? FeedPlatform.detect(feedURL: feedURL, siteURL: siteURL)
    let resolvedURL = SocialFeedURLResolver.canonicalFeedURL(from: feedURL, platform: resolvedPlatform)
    let count = try fetchAll().count
    let source = FeedSource(
      name: name,
      feedURL: resolvedURL,
      siteURL: siteURL,
      isRecommended: isRecommended,
      sortOrder: count,
      countryCode: countryCode,
      feedDescription: feedDescription,
      platform: resolvedPlatform
    )
    context.insert(source)
    try context.save()
    return source
  }

  func update(_ source: FeedSource) throws {
    try context.save()
  }

  func delete(_ source: FeedSource) throws {
    context.delete(source)
    try context.save()
  }

  func seedRecommendedIfNeeded() throws {
    let existing = try fetchAll()
    if existing.isEmpty {
      for (index, feed) in RecommendedFeeds.loadFromBundle().enumerated() {
        let canonicalURL = SocialFeedURLResolver.canonicalFeedURL(
          from: feed.feedURL,
          platform: feed.feedPlatform
        )
        let source = FeedSource(
          name: feed.name,
          feedURL: canonicalURL,
          siteURL: feed.siteURL,
          isEnabled: false,
          isRecommended: true,
          sortOrder: index,
          countryCode: feed.countryCode,
          feedDescription: feed.description,
          platform: feed.feedPlatform
        )
        context.insert(source)
      }
      try context.save()
    } else {
      try syncCatalogWithExistingSources()
    }
  }

  /// Añade fuentes nuevas del catálogo JSON sin duplicar las existentes.
  private func syncCatalogWithExistingSources() throws {
    let allSources = try fetchAll()
    let existingURLs = Set(allSources.map(\.feedURL))
    var sortOrder = allSources.count

    for feed in RecommendedFeeds.loadFromBundle() {
      let canonicalURL = SocialFeedURLResolver.canonicalFeedURL(
        from: feed.feedURL,
        platform: feed.feedPlatform
      )

      if let existing = allSources.first(where: { stored in
        RecommendedFeeds.matching(stored)?.id == feed.id
          || stored.feedURL == feed.feedURL
          || stored.feedURL == canonicalURL
      }) {
        if feed.feedPlatform == .news {
          existing.feedURL = feed.feedURL
          if let siteURL = feed.siteURL {
            existing.siteURL = siteURL
          }
          existing.platform = .news
        } else {
          existing.feedURL = canonicalURL
          if let fallback = feed.fallbackFeedURL, existing.platform == .x {
            existing.feedURL = fallback
          }
          existing.platform = feed.feedPlatform
          if let siteURL = feed.siteURL {
            existing.siteURL = siteURL
          }
        }
        existing.feedDescription = feed.description ?? existing.feedDescription
        if existing.countryCode == nil { existing.countryCode = feed.countryCode }
        continue
      }

      guard !existingURLs.contains(canonicalURL) else { continue }

      let source = FeedSource(
        name: feed.name,
        feedURL: canonicalURL,
        siteURL: feed.siteURL,
        isEnabled: false,
        isRecommended: true,
        sortOrder: sortOrder,
        countryCode: feed.countryCode,
        feedDescription: feed.description,
        platform: feed.feedPlatform
      )
      context.insert(source)
      sortOrder += 1
    }

    try context.save()
  }

  func enableDefaultSources(forCountry countryCode: String) throws {
    guard try fetchEnabled().isEmpty else { return }

    let catalog = RecommendedFeeds.loadFromBundle()
    let local = catalog.filter {
      $0.countryCode.uppercased() == countryCode.uppercased() && !$0.isInternational
    }
    let international = catalog.filter(\.isInternational)

    let toEnable = Array(local.prefix(3)) + Array(international.prefix(1))
    try enableFeeds(toEnable, allSources: try fetchAll())
  }

  func enableSources(ids: Set<String>, countryCode: String) throws {
    guard !ids.isEmpty else {
      try enableDefaultSources(forCountry: countryCode)
      return
    }

    let catalog = RecommendedFeeds.loadFromBundle()
    let feeds = catalog.filter { ids.contains($0.id) }
    let allSources = try fetchAll()
    try enableFeeds(feeds, allSources: allSources)

    if try fetchEnabled().isEmpty {
      try enableDefaultSources(forCountry: countryCode)
    }
  }

  private func enableFeeds(_ feeds: [RecommendedFeed], allSources: [FeedSource]) throws {
    for feed in feeds {
      guard let source = allSources.first(where: { RecommendedFeeds.matching($0)?.id == feed.id }) else {
        continue
      }
      source.isEnabled = true
      source.countryCode = feed.countryCode
      try update(source)
    }
  }
}
