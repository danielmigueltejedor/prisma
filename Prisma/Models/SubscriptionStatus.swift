import Foundation
import SwiftData

@Model
final class SubscriptionStatus {
  @Attribute(.unique) var id: UUID
  var tierRaw: String
  var expirationDate: Date?
  var isInTrial: Bool
  var productIdentifier: String?
  var lastVerifiedAt: Date?

  var tier: SubscriptionTier {
    get { SubscriptionTier(rawValue: tierRaw) ?? .free }
    set { tierRaw = newValue.rawValue }
  }

  var isPlusActive: Bool {
    guard tier == .plus else { return false }
    if let expirationDate, expirationDate < .now { return false }
    return true
  }

  init(
    id: UUID = UUID(),
    tier: SubscriptionTier = .free,
    expirationDate: Date? = nil,
    isInTrial: Bool = false,
    productIdentifier: String? = nil,
    lastVerifiedAt: Date? = nil
  ) {
    self.id = id
    self.tierRaw = tier.rawValue
    self.expirationDate = expirationDate
    self.isInTrial = isInTrial
    self.productIdentifier = productIdentifier
    self.lastVerifiedAt = lastVerifiedAt
  }
}
