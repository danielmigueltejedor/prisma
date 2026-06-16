import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
  var currentPage = 0
  let totalPages = 5
  var selectedCountry: NewsCountry

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
  }

  func next() {
    currentPage = min(currentPage + 1, totalPages - 1)
  }

  @discardableResult
  func completeOnboarding() -> Bool {
    do {
      try preferenceRepository.completeOnboarding(homeCountryCode: selectedCountry.code)
      try feedSourceRepository.enableDefaultSources(forCountry: selectedCountry.code)
      return true
    } catch {
      return false
    }
  }
}
