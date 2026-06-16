import Foundation
import StoreKit

@MainActor
protocol SubscriptionServiceProtocol: AnyObject {
  var isPlusActive: Bool { get }
  var isInTrial: Bool { get }
  var products: [Product] { get }
  var isLoading: Bool { get }

  func loadProducts() async
  func purchase(_ product: Product) async throws
  func restorePurchases() async throws
  func updateStatus() async
}

@MainActor
final class StoreKitSubscriptionService: SubscriptionServiceProtocol, Observable {
  @Published private(set) var isPlusActive = false
  @Published private(set) var isInTrial = false
  @Published private(set) var products: [Product] = []
  @Published private(set) var isLoading = false

  private let preferenceRepository: PreferenceRepository
  private var updatesTask: Task<Void, Never>?

  init(preferenceRepository: PreferenceRepository) {
    self.preferenceRepository = preferenceRepository
    updatesTask = Task { await listenForTransactions() }
    Task { await updateStatus() }
  }

  deinit {
    updatesTask?.cancel()
  }

  func loadProducts() async {
    isLoading = true
    defer { isLoading = false }
    do {
      products = try await Product.products(for: SubscriptionProducts.all)
        .sorted { $0.price < $1.price }
    } catch {
      products = []
    }
  }

  func purchase(_ product: Product) async throws {
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
      let transaction = try checkVerified(verification)
      await transaction.finish()
      await updateStatus()
    case .userCancelled, .pending:
      break
    @unknown default:
      break
    }
  }

  func restorePurchases() async throws {
    try await AppStore.sync()
    await updateStatus()
  }

  func updateStatus() async {
    var active = false
    var trial = false
    var expiration: Date?
    var productId: String?

    for await result in Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result) else { continue }
      if SubscriptionProducts.all.contains(transaction.productID) {
        active = true
        productId = transaction.productID
        if let offer = transaction.offerType, offer == .introductory {
          trial = true
        }
        expiration = transaction.expirationDate
      }
    }

    isPlusActive = active
    isInTrial = trial

    if let status = try? preferenceRepository.getOrCreateSubscriptionStatus() {
      status.tier = active ? .plus : .free
      status.isInTrial = trial
      status.expirationDate = expiration
      status.productIdentifier = productId
      status.lastVerifiedAt = .now
      try? preferenceRepository.save()
    }
  }

  private func listenForTransactions() async {
    for await result in Transaction.updates {
      guard let transaction = try? checkVerified(result) else { continue }
      await transaction.finish()
      await updateStatus()
    }
  }

  private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
      throw StoreError.failedVerification
    case .verified(let safe):
      return safe
    }
  }
}

enum StoreError: Error {
  case failedVerification
}

@MainActor
final class MockSubscriptionService: SubscriptionServiceProtocol, Observable {
  @Published var isPlusActive = false
  @Published var isInTrial = false
  @Published private(set) var products: [Product] = []
  @Published private(set) var isLoading = false

  private let preferenceRepository: PreferenceRepository

  init(preferenceRepository: PreferenceRepository) {
    self.preferenceRepository = preferenceRepository
    if let status = try? preferenceRepository.getOrCreateSubscriptionStatus() {
      isPlusActive = status.isPlusActive
      isInTrial = status.isInTrial
    }
  }

  func loadProducts() async {}

  func purchase(_ product: Product) async throws {
    isPlusActive = true
    isInTrial = true
    persist()
  }

  func restorePurchases() async throws {
    persist()
  }

  func updateStatus() async {
    if let status = try? preferenceRepository.getOrCreateSubscriptionStatus() {
      isPlusActive = status.isPlusActive
      isInTrial = status.isInTrial
    }
  }

  func togglePlusForTesting() {
    isPlusActive.toggle()
    isInTrial = isPlusActive
    persist()
  }

  private func persist() {
    guard let status = try? preferenceRepository.getOrCreateSubscriptionStatus() else { return }
    status.tier = isPlusActive ? .plus : .free
    status.isInTrial = isInTrial
    status.expirationDate = isPlusActive ? Calendar.current.date(byAdding: .month, value: 1, to: .now) : nil
    status.lastVerifiedAt = .now
    try? preferenceRepository.save()
  }
}
