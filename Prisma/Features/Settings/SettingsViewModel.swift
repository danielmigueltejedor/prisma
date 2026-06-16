import Foundation

@MainActor
@Observable
final class SettingsViewModel {
  var preferences: UserPreference?
  var blockedKeywordInput = ""

  private let preferenceRepository: PreferenceRepository
  private let feedSourceRepository: FeedSourceRepository

  init(preferenceRepository: PreferenceRepository, feedSourceRepository: FeedSourceRepository) {
    self.preferenceRepository = preferenceRepository
    self.feedSourceRepository = feedSourceRepository
  }

  func load() {
    preferences = try? preferenceRepository.getOrCreate()
  }

  func save() {
    try? preferenceRepository.save()
  }

  func setAppearance(_ mode: AppearanceMode) {
    preferences?.appearanceMode = mode
    save()
  }

  func setHomeCountry(_ country: NewsCountry) {
    preferences?.homeCountryCode = country.code
    save()
  }

  func setFontMultiplier(_ value: Double) {
    preferences?.readerFontSizeMultiplier = value
    save()
  }

  func addBlockedKeyword() {
    let keyword = blockedKeywordInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !keyword.isEmpty else { return }
    if preferences?.blockedKeywords.contains(keyword) == false {
      preferences?.blockedKeywords.append(keyword)
    }
    blockedKeywordInput = ""
    save()
  }

  func removeBlockedKeyword(_ keyword: String) {
    preferences?.blockedKeywords.removeAll { $0 == keyword }
    save()
  }

  func clearAllData() {
    guard let sources = try? feedSourceRepository.fetchAll() else { return }
    for source in sources {
      try? feedSourceRepository.delete(source)
    }
    try? feedSourceRepository.seedRecommendedIfNeeded()
  }
}
