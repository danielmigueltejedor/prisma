import Foundation
import SwiftData

@Model
final class UserPreference {
  @Attribute(.unique) var id: UUID
  var hasCompletedOnboarding: Bool
  var appearanceModeRaw: String
  var readerFontSizeMultiplier: Double
  var readerFontFamilyRaw: String = ReaderFontFamily.serif.rawValue
  var blockedKeywords: [String]
  var lastRefreshAt: Date?
  var homeCountryCode: String?
  var weatherLocationQuery: String?
  var cascadeViewEnabled: Bool = false
  var cascadeSeenArticleIDs: [String] = []

  var appearanceMode: AppearanceMode {
    get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
    set { appearanceModeRaw = newValue.rawValue }
  }

  var readerFontFamily: ReaderFontFamily {
    get { ReaderFontFamily(rawValue: readerFontFamilyRaw) ?? .serif }
    set { readerFontFamilyRaw = newValue.rawValue }
  }

  init(
    id: UUID = UUID(),
    hasCompletedOnboarding: Bool = false,
    appearanceMode: AppearanceMode = .system,
    readerFontSizeMultiplier: Double = 1.0,
    readerFontFamily: ReaderFontFamily = .serif,
    blockedKeywords: [String] = [],
    lastRefreshAt: Date? = nil,
    homeCountryCode: String? = nil,
    weatherLocationQuery: String? = nil,
    cascadeViewEnabled: Bool = false,
    cascadeSeenArticleIDs: [String] = []
  ) {
    self.id = id
    self.hasCompletedOnboarding = hasCompletedOnboarding
    self.appearanceModeRaw = appearanceMode.rawValue
    self.readerFontSizeMultiplier = readerFontSizeMultiplier
    self.readerFontFamilyRaw = readerFontFamily.rawValue
    self.blockedKeywords = blockedKeywords
    self.lastRefreshAt = lastRefreshAt
    self.homeCountryCode = homeCountryCode
    self.weatherLocationQuery = weatherLocationQuery
    self.cascadeViewEnabled = cascadeViewEnabled
    self.cascadeSeenArticleIDs = cascadeSeenArticleIDs
  }

  var homeCountry: NewsCountry {
    NewsCountry.from(code: homeCountryCode) ?? .detected
  }
}
