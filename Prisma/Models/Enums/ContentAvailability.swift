import Foundation

enum ContentAvailability: String, Codable, CaseIterable {
  case fullRSS
  case partialRSS
  case unknown
}
