import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
  var currentPage = 0
  let totalPages = 5
  var selectedCountry: NewsCountry
  var selectedFeedIDs: Set<String> = []
  var searchText = ""
  var selectedStyle = ContentStyleFilter.allSelection

  private let preferenceRepository: PreferenceRepository
  private let feedSourceRepository: FeedSourceRepository
  private var preparedCountryCode: String?
  private static let maxSelectedFeeds = 10

  init(
    preferenceRepository: PreferenceRepository,
    feedSourceRepository: FeedSourceRepository
  ) {
    self.preferenceRepository = preferenceRepository
    self.feedSourceRepository = feedSourceRepository
    if let prefs = try? preferenceRepository.getOrCreate(),
       let code = prefs.homeCountryCode,
       let country = NewsCountry.from(code: code) {
      selectedCountry = country
    } else {
      selectedCountry = .detected
    }
  }

  var isSearching: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var displayedFeeds: [RecommendedFeed] {
    filterFeeds(feedPool)
  }

  /// Compatibilidad con vistas de onboarding anteriores a la búsqueda/filtros.
  var suggestedFeeds: [RecommendedFeed] {
    displayedFeeds
  }

  var styleFilters: [String] {
    let styles = Set(filterPool.map { ContentStyleFilter.style(for: $0) })
    return ContentStyleFilter.filters(including: styles)
  }

  var selectedCountLabel: String {
    String(localized: "onboarding.sources.selected \(selectedFeedIDs.count)")
  }

  func next() {
    goToPage(currentPage + 1)
  }

  func goToPage(_ page: Int) {
    let clamped = min(max(page, 0), totalPages - 1)
    if currentPage == 1, clamped >= 2 {
      prepareSourcesPage()
    }
    currentPage = clamped
  }

  func prepareSourcesPage() {
    let code = selectedCountry.code
    guard preparedCountryCode != code else { return }
    preparedCountryCode = code
    searchText = ""
    selectedStyle = ContentStyleFilter.allSelection
    applyDefaultSelections(for: code)
  }

  func toggleFeed(_ id: String) {
    if selectedFeedIDs.contains(id) {
      guard selectedFeedIDs.count > 1 else { return }
      selectedFeedIDs.remove(id)
    } else if selectedFeedIDs.count < Self.maxSelectedFeeds {
      selectedFeedIDs.insert(id)
    }
  }

  func isFeedSelected(_ id: String) -> Bool {
    selectedFeedIDs.contains(id)
  }

  @discardableResult
  func completeOnboarding() -> Bool {
    do {
      try preferenceRepository.completeOnboarding(homeCountryCode: selectedCountry.code)
      try feedSourceRepository.enableSources(ids: selectedFeedIDs, countryCode: selectedCountry.code)
      return true
    } catch {
      return false
    }
  }

  private var feedPool: [RecommendedFeed] {
    if isSearching {
      return RecommendedFeeds.loadFromBundle().filter {
        $0.feedPlatform == .news || $0.feedPlatform == .reddit || $0.feedPlatform == .x
      }
    }
    return browseFeeds(for: selectedCountry.code)
  }

  private var filterPool: [RecommendedFeed] {
    isSearching ? feedPool : browseFeeds(for: selectedCountry.code)
  }

  private func browseFeeds(for countryCode: String) -> [RecommendedFeed] {
    var byID: [String: RecommendedFeed] = [:]
    for feed in RecommendedFeeds.forHomeCountry(countryCode)
      + RecommendedFeeds.reddit()
      + RecommendedFeeds.social() {
      byID[feed.id] = feed
    }
    return Array(byID.values)
  }

  private func applyDefaultSelections(for countryCode: String) {
    let local = RecommendedFeeds.local(for: countryCode)
    let international = RecommendedFeeds.international()
    selectedFeedIDs = Set(
      Array(local.prefix(4).map(\.id)) + Array(international.prefix(1).map(\.id))
    )
  }

  private func filterFeeds(_ feeds: [RecommendedFeed]) -> [RecommendedFeed] {
    var result = feeds
    if isSearching {
      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      result = result.filter {
        $0.name.lowercased().contains(query)
          || $0.category.lowercased().contains(query)
          || ($0.description?.lowercased().contains(query) ?? false)
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
    return result.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }
}
