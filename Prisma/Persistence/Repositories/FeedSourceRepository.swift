import Foundation
import SwiftData

@MainActor
final class FeedSourceRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
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
    countryCode: String? = nil
  ) throws -> FeedSource {
    if let existing = try find(byURL: feedURL) {
      if existing.countryCode == nil, let countryCode {
        existing.countryCode = countryCode
        try context.save()
      }
      return existing
    }
    let count = try fetchAll().count
    let source = FeedSource(
      name: name,
      feedURL: feedURL,
      siteURL: siteURL,
      isRecommended: isRecommended,
      sortOrder: count,
      countryCode: countryCode
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
        let source = FeedSource(
          name: feed.name,
          feedURL: feed.feedURL,
          siteURL: feed.siteURL,
          isEnabled: false,
          isRecommended: true,
          sortOrder: index,
          countryCode: feed.countryCode
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
    let existingURLs = Set(try fetchAll().map(\.feedURL))
    var sortOrder = try fetchAll().count

    for feed in RecommendedFeeds.loadFromBundle() where !existingURLs.contains(feed.feedURL) {
      let source = FeedSource(
        name: feed.name,
        feedURL: feed.feedURL,
        siteURL: feed.siteURL,
        isEnabled: false,
        isRecommended: true,
        sortOrder: sortOrder,
        countryCode: feed.countryCode
      )
      context.insert(source)
      sortOrder += 1
    }

    for source in try fetchAll() where source.countryCode == nil {
      if let feed = RecommendedFeeds.find(feedURL: source.feedURL) {
        source.countryCode = feed.countryCode
      }
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
    let allSources = try fetchAll()

    for feed in toEnable {
      guard let source = allSources.first(where: { $0.feedURL == feed.feedURL }) else { continue }
      source.isEnabled = true
      source.countryCode = feed.countryCode
      try update(source)
    }
  }
}
