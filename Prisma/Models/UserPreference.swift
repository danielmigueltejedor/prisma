import Foundation
import SwiftData

@Model
final class UserPreference {
  @Attribute(.unique) var id: UUID
  var hasCompletedOnboarding: Bool
  var appearanceModeRaw: String
  var readerFontSizeMultiplier: Double
  var blockedKeywords: [String]
  var lastRefreshAt: Date?
  var homeCountryCode: String?

  var appearanceMode: AppearanceMode {
    get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
    set { appearanceModeRaw = newValue.rawValue }
  }

  init(
    id: UUID = UUID(),
    hasCompletedOnboarding: Bool = false,
    appearanceMode: AppearanceMode = .system,
    readerFontSizeMultiplier: Double = 1.0,
    blockedKeywords: [String] = [],
    lastRefreshAt: Date? = nil,
    homeCountryCode: String? = nil
  ) {
    self.id = id
    self.hasCompletedOnboarding = hasCompletedOnboarding
    self.appearanceModeRaw = appearanceMode.rawValue
    self.readerFontSizeMultiplier = readerFontSizeMultiplier
    self.blockedKeywords = blockedKeywords
    self.lastRefreshAt = lastRefreshAt
    self.homeCountryCode = homeCountryCode
  }

  var homeCountry: NewsCountry {
    NewsCountry.from(code: homeCountryCode) ?? .detected
  }
}
