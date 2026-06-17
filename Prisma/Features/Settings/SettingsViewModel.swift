import Foundation

@MainActor
@Observable
final class SettingsViewModel {
  private static let weatherLookupDebounceNanoseconds: UInt64 = 450_000_000

  var preferences: UserPreference?
  var blockedKeywordInput = ""
  var weatherLocationLookup: WeatherLocationLookupState = .idle

  private let preferenceRepository: PreferenceRepository
  private let feedSourceRepository: FeedSourceRepository
  private let weatherService: WeatherService
  private var weatherLookupTask: Task<Void, Never>?

  init(
    preferenceRepository: PreferenceRepository,
    feedSourceRepository: FeedSourceRepository,
    weatherService: WeatherService
  ) {
    self.preferenceRepository = preferenceRepository
    self.feedSourceRepository = feedSourceRepository
    self.weatherService = weatherService
  }

  func load() {
    preferences = try? preferenceRepository.getOrCreate()
    scheduleWeatherLocationLookup()
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
    scheduleWeatherLocationLookup()
    PreferencesNotifier.publish()
  }

  func setWeatherLocation(_ query: String) {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    preferences?.weatherLocationQuery = trimmed.isEmpty ? nil : query
    save()
    scheduleWeatherLocationLookup()
    if trimmed.isEmpty {
      PreferencesNotifier.publish()
    }
  }

  func scheduleWeatherLocationLookup() {
    weatherLookupTask?.cancel()

    let trimmed = preferences?.weatherLocationQuery?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !trimmed.isEmpty else {
      weatherLocationLookup = .idle
      return
    }

    weatherLocationLookup = .searching
    weatherLookupTask = Task {
      try? await Task.sleep(nanoseconds: Self.weatherLookupDebounceNanoseconds)
      guard !Task.isCancelled else { return }
      await performWeatherLocationLookup()
    }
  }

  func performWeatherLocationLookup() async {
    let trimmed = preferences?.weatherLocationQuery?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !trimmed.isEmpty else {
      weatherLocationLookup = .idle
      return
    }

    weatherLocationLookup = .searching
    let country = preferences?.homeCountry ?? .detected

    do {
      if let match = try await weatherService.resolveLocation(query: trimmed, country: country) {
        weatherLocationLookup = .resolved(match)
      } else {
        weatherLocationLookup = .notFound
      }
    } catch {
      weatherLocationLookup = .notFound
    }
    PreferencesNotifier.publish()
  }

  func setFontMultiplier(_ value: Double) {
    preferences?.readerFontSizeMultiplier = min(max(value, 0.8), 1.6)
    save()
  }

  func setReaderFontFamily(_ family: ReaderFontFamily) {
    preferences?.readerFontFamily = family
    save()
  }

  func setCascadeViewEnabled(_ enabled: Bool) {
    preferences?.cascadeViewEnabled = enabled
    save()
    PreferencesNotifier.publish()
  }

  func addBlockedKeyword() {
    let keyword = blockedKeywordInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !keyword.isEmpty else { return }
    if preferences?.blockedKeywords.contains(keyword) == false {
      preferences?.blockedKeywords.append(keyword)
    }
    blockedKeywordInput = ""
    save()
    PreferencesNotifier.publish()
  }

  func removeBlockedKeyword(_ keyword: String) {
    preferences?.blockedKeywords.removeAll { $0 == keyword }
    save()
    PreferencesNotifier.publish()
  }

  func clearAllData() {
    guard let sources = try? feedSourceRepository.fetchAll() else { return }
    for source in sources {
      try? feedSourceRepository.delete(source)
    }
    try? feedSourceRepository.seedRecommendedIfNeeded()
  }
}
