import Foundation

@MainActor
@Observable
final class SourcesViewModel {
  var sources: [FeedSource] = []
  var searchText = ""
  var selectedStyle = "Todas"
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

  var redditRecommended: [RecommendedFeed] {
    filtered(RecommendedFeeds.reddit())
  }

  var socialRecommended: [RecommendedFeed] {
    filtered(RecommendedFeeds.social())
  }

  var isSearching: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var styleFilters: [String] {
    let styles = Set(sources.map { ContentStyleFilter.style(for: $0) })
    return ContentStyleFilter.filters(including: styles)
  }

  var recommendedStyleFilters: [String] {
    ContentStyleFilter.filters()
  }

  var filteredRecommended: [RecommendedFeed] {
    if isSearching {
      return filtered(
        RecommendedFeeds.loadFromBundle().filter {
          $0.feedPlatform == .news || $0.feedPlatform == .reddit || $0.feedPlatform == .x
        }
      )
    }
    return []
  }

  var displayedSources: [FeedSource] {
    let base: [FeedSource]
    if isSearching {
      let query = searchText.lowercased()
      base = sources.filter {
        $0.name.lowercased().contains(query)
          || $0.feedURL.lowercased().contains(query)
          || ($0.siteURL?.lowercased().contains(query) ?? false)
          || $0.platform.displayName.lowercased().contains(query)
      }
    } else {
      base = sources
    }
    return base.filter {
      ContentStyleFilter.matches(
        style: ContentStyleFilter.style(for: $0),
        selection: selectedStyle
      )
    }
  }

  private func filtered(_ feeds: [RecommendedFeed]) -> [RecommendedFeed] {
    var result = feeds
    if isSearching {
      let query = searchText.lowercased()
      result = result.filter {
        $0.name.lowercased().contains(query)
          || $0.category.lowercased().contains(query)
          || NewsCountry.from(code: $0.countryCode)?.displayName.lowercased().contains(query) == true
      }
    }
    if selectedStyle != ContentStyleFilter.allSelection {
      result = result.filter {
        ContentStyleFilter.matches(
          style: ContentStyleFilter.style(for: $0),
          selection: selectedStyle
        )
      }
    }
    return result
  }

  private var hasLoadedData = false

  func loadIfNeeded() {
    guard !hasLoadedData else { return }
    reload()
  }

  func reload() {
    do {
      sources = try feedSourceRepository.fetchAll()
      hasLoadedData = true
      _ = try? preferenceRepository.getOrCreate()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func load() {
    reload()
  }

  func toggleEnabled(_ source: FeedSource) {
    let willEnable = !source.isEnabled
    source.isEnabled.toggle()
    try? feedSourceRepository.update(source)
    if willEnable {
      Task { await refreshSource(source) }
    }
  }

  func toggleFavorite(_ source: FeedSource) {
    source.isFavorite.toggle()
    try? feedSourceRepository.update(source)
    PreferencesNotifier.publish()
  }

  func toggleBlocked(_ source: FeedSource) {
    source.isBlocked.toggle()
    try? feedSourceRepository.update(source)
    PreferencesNotifier.publish()
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

  @discardableResult
  func addManual(name: String, url: String) async -> Bool {
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
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  @discardableResult
  func addRecommended(_ feed: RecommendedFeed) async -> Bool {
    isRefreshing = true
    defer { isRefreshing = false }
    do {
      _ = try await feedService.addSource(
        name: feed.name,
        feedURL: feed.feedURL,
        siteURL: feed.siteURL,
        countryCode: feed.countryCode,
        feedDescription: feed.description,
        platform: feed.feedPlatform
      )
      if let source = try feedSourceRepository.find(byURL: feed.feedURL) {
        source.isRecommended = true
        source.countryCode = feed.countryCode
        source.feedDescription = feed.description
        source.platform = feed.feedPlatform
        source.feedURL = SocialFeedURLResolver.canonicalFeedURL(
          from: feed.feedURL,
          platform: feed.feedPlatform
        )
        try feedSourceRepository.update(source)
      }
      successMessage = String(localized: "sources.added")
      load()
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  func refreshSource(_ source: FeedSource) async {
    isRefreshing = true
    defer { isRefreshing = false }
    do {
      _ = try await feedService.refresh(source: source)
      load()
      FeedRefreshNotifier.publish()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func importOPML(data: Data) {
    Task {
      isRefreshing = true
      defer { isRefreshing = false }
      do {
        let count = try await feedService.importOPML(data: data)
        successMessage = String(localized: "sources.imported \(count)")
        load()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func exportOPML() -> String? {
    try? feedService.exportOPML()
  }
}
