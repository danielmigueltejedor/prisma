import Foundation

@MainActor
@Observable
final class SourcesViewModel {
  var sources: [FeedSource] = []
  var searchText = ""
  var showOtherCountries = false
  var isRefreshing = false
  var errorMessage: String?
  var successMessage: String?

  private let feedSourceRepository: FeedSourceRepository
  private let feedService: FeedService
  private let preferenceRepository: PreferenceRepository

  init(
    feedSourceRepository: FeedSourceRepository,
    feedService: FeedService,
    preferenceRepository: PreferenceRepository
  ) {
    self.feedSourceRepository = feedSourceRepository
    self.feedService = feedService
    self.preferenceRepository = preferenceRepository
  }

  var homeCountryCode: String {
    (try? preferenceRepository.getOrCreate().homeCountryCode) ?? NewsCountry.detected.code
  }

  var homeCountry: NewsCountry {
    NewsCountry.from(code: homeCountryCode) ?? .detected
  }

  var localRecommended: [RecommendedFeed] {
    filtered(RecommendedFeeds.local(for: homeCountryCode))
  }

  var internationalRecommended: [RecommendedFeed] {
    filtered(RecommendedFeeds.international())
  }

  var otherRecommended: [RecommendedFeed] {
    filtered(RecommendedFeeds.other(excluding: homeCountryCode))
  }

  var isSearching: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var filteredRecommended: [RecommendedFeed] {
    if isSearching {
      return filtered(RecommendedFeeds.forHomeCountry(homeCountryCode) + RecommendedFeeds.other(excluding: homeCountryCode))
    }
    return []
  }

  private func filtered(_ feeds: [RecommendedFeed]) -> [RecommendedFeed] {
    guard isSearching else { return feeds }
    let query = searchText.lowercased()
    return feeds.filter {
      $0.name.lowercased().contains(query)
        || $0.category.lowercased().contains(query)
        || NewsCountry.from(code: $0.countryCode)?.displayName.lowercased().contains(query) == true
    }
  }

  func load() {
    do {
      sources = try feedSourceRepository.fetchAll()
      _ = try? preferenceRepository.getOrCreate()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func toggleEnabled(_ source: FeedSource) {
    source.isEnabled.toggle()
    try? feedSourceRepository.update(source)
    load()
  }

  func toggleFavorite(_ source: FeedSource) {
    source.isFavorite.toggle()
    try? feedSourceRepository.update(source)
    load()
  }

  func toggleBlocked(_ source: FeedSource) {
    source.isBlocked.toggle()
    try? feedSourceRepository.update(source)
    load()
  }

  func delete(_ source: FeedSource) {
    try? feedSourceRepository.delete(source)
    load()
  }

  func rename(_ source: FeedSource, to name: String) {
    source.name = name
    try? feedSourceRepository.update(source)
    load()
  }

  func addManual(name: String, url: String) async {
    isRefreshing = true
    defer { isRefreshing = false }
    do {
      let discovered = try await feedService.discoverFeedTitle(from: url)
      let finalName = name.isEmpty ? discovered.title : name
      _ = try await feedService.addSource(
        name: finalName,
        feedURL: url,
        siteURL: discovered.siteURL
      )
      successMessage = String(localized: "sources.added")
      load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func addRecommended(_ feed: RecommendedFeed) async {
    isRefreshing = true
    defer { isRefreshing = false }
    do {
      _ = try await feedService.addSource(
        name: feed.name,
        feedURL: feed.feedURL,
        siteURL: feed.siteURL,
        countryCode: feed.countryCode
      )
      if let source = try feedSourceRepository.find(byURL: feed.feedURL) {
        source.isRecommended = true
        source.countryCode = feed.countryCode
        try feedSourceRepository.update(source)
      }
      successMessage = String(localized: "sources.added")
      load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refreshSource(_ source: FeedSource) async {
    isRefreshing = true
    defer { isRefreshing = false }
    do {
      _ = try await feedService.refresh(source: source)
      load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func importOPML(data: Data) {
    do {
      let count = try feedService.importOPML(data: data)
      successMessage = String(localized: "sources.imported \(count)")
      load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func exportOPML() -> String? {
    try? feedService.exportOPML()
  }
}
