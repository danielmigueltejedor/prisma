import Foundation

enum SubscriptionTier: String, Codable {
  case free
  case plus
}

enum PlusFeature: String, CaseIterable, Identifiable {
  case aiSummary
  case compareSources
  case smartFeed
  case dailyBriefing
  case clustering
  case translation
  case smartNotifications

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .aiSummary: String(localized: "plus.feature.summary")
    case .compareSources: String(localized: "plus.feature.compare")
    case .smartFeed: String(localized: "plus.feature.smartFeed")
    case .dailyBriefing: String(localized: "plus.feature.briefing")
    case .clustering: String(localized: "plus.feature.clustering")
    case .translation: String(localized: "plus.feature.translation")
    case .smartNotifications: String(localized: "plus.feature.notifications")
    }
  }
}
