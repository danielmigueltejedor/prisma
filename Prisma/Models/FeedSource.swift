import Foundation
import SwiftData

@Model
final class FeedSource {
  @Attribute(.unique) var id: UUID
  var name: String
  var feedURL: String
  var siteURL: String?
  var isEnabled: Bool
  var isFavorite: Bool
  var isBlocked: Bool
  var isRecommended: Bool
  var createdAt: Date
  var lastFetchedAt: Date?
  var sortOrder: Int
  var countryCode: String?
  var feedDescription: String?
  var platformRaw: String

  @Relationship(deleteRule: .cascade, inverse: \Article.feedSource)
  var articles: [Article] = []

  init(
    id: UUID = UUID(),
    name: String,
    feedURL: String,
    siteURL: String? = nil,
    isEnabled: Bool = true,
    isFavorite: Bool = false,
    isBlocked: Bool = false,
    isRecommended: Bool = false,
    createdAt: Date = .now,
    lastFetchedAt: Date? = nil,
    sortOrder: Int = 0,
    countryCode: String? = nil,
    feedDescription: String? = nil,
    platform: FeedPlatform = .news
  ) {
    self.id = id
    self.name = name
    self.feedURL = feedURL
    self.siteURL = siteURL
    self.isEnabled = isEnabled
    self.isFavorite = isFavorite
    self.isBlocked = isBlocked
    self.isRecommended = isRecommended
    self.createdAt = createdAt
    self.lastFetchedAt = lastFetchedAt
    self.sortOrder = sortOrder
    self.countryCode = countryCode
    self.feedDescription = feedDescription
    self.platformRaw = platform.rawValue
  }

  var platform: FeedPlatform {
    get { FeedPlatform(rawValue: platformRaw) ?? .news }
    set { platformRaw = newValue.rawValue }
  }
}
