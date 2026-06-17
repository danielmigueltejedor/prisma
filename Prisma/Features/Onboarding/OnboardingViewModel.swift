import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
  var currentPage = 0
  let totalPages = 5
  var selectedCountry: NewsCountry
  var selectedFeedIDs: Set<String> = []
  var suggestedFeeds: [RecommendedFeed] = []

  private let preferenceRepository: PreferenceRepository
  private let feedSourceRepository: FeedSourceRepository

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
    refreshSuggestedFeeds()
  }

  func next() {
    if currentPage == 1 {
      refreshSuggestedFeeds()
    }
    currentPage = min(currentPage + 1, totalPages - 1)
  }

  func refreshSuggestedFeeds() {
    let local = RecommendedFeeds.local(for: selectedCountry.code)
    let international = RecommendedFeeds.international()
    suggestedFeeds = Array(local.prefix(6)) + Array(international.prefix(2))

    if selectedFeedIDs.isEmpty {
      let defaults = Array(local.prefix(4).map(\.id)) + Array(international.prefix(1).map(\.id))
      selectedFeedIDs = Set(defaults)
    } else {
      let valid = Set(suggestedFeeds.map(\.id))
      selectedFeedIDs = selectedFeedIDs.intersection(valid)
      if selectedFeedIDs.isEmpty {
        selectedFeedIDs = Set(suggestedFeeds.prefix(4).map(\.id))
      }
    }
  }

  func toggleFeed(_ id: String) {
    if selectedFeedIDs.contains(id) {
      guard selectedFeedIDs.count > 1 else { return }
      selectedFeedIDs.remove(id)
    } else if selectedFeedIDs.count < 10 {
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
}
