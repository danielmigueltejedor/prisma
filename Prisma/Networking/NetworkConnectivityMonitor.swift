import Foundation
import Network

@MainActor
@Observable
final class NetworkConnectivityMonitor {
  static let shared = NetworkConnectivityMonitor()

  private(set) var isOnline = true

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.danielmigueltejedor.prisma.connectivity")

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      let online = path.status == .satisfied
      Task { @MainActor in
        self?.isOnline = online
      }
    }
    monitor.start(queue: queue)
    isOnline = monitor.currentPath.status == .satisfied
  }
}
