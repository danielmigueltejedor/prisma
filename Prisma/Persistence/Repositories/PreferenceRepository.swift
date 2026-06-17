import Foundation
import SwiftData

@MainActor
final class PreferenceRepository {
  private let context: ModelContext
  private static let singletonId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  init(context: ModelContext) {
    self.context = context
  }

  func getOrCreate() throws -> UserPreference {
    let descriptor = FetchDescriptor<UserPreference>()
    if let existing = try context.fetch(descriptor).first {
      return existing
    }
    let preference = UserPreference(id: Self.singletonId)
    context.insert(preference)
    try context.save()
    return preference
  }

  func completeOnboarding(homeCountryCode: String) throws {
    let prefs = try getOrCreate()
    prefs.hasCompletedOnboarding = true
    prefs.homeCountryCode = homeCountryCode
    try save()
  }

  func setHomeCountry(_ code: String) throws {
    let prefs = try getOrCreate()
    prefs.homeCountryCode = code
    try save()
  }

  func touchLastRefresh(at date: Date = .now) throws {
    let prefs = try getOrCreate()
    prefs.lastRefreshAt = date
    try save()
  }

  func save() throws {
    try context.save()
  }
}
