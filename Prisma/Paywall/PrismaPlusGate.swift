import Foundation

@MainActor
protocol PrismaPlusGate: AnyObject {
  var isPlusActive: Bool { get }
  func requirePlus(for feature: PlusFeature) -> Bool
}

@MainActor
final class PrismaPlusGatekeeper: PrismaPlusGate {
  private let subscriptionService: SubscriptionServiceProtocol

  init(subscriptionService: SubscriptionServiceProtocol) {
    self.subscriptionService = subscriptionService
  }

  var isPlusActive: Bool {
    subscriptionService.isPlusActive
  }

  func requirePlus(for feature: PlusFeature) -> Bool {
    subscriptionService.isPlusActive
  }
}
