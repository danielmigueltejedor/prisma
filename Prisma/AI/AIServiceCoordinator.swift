import Foundation

/// Serializes on-device model work so multiple features don't contend for Apple Intelligence at once.
actor AIServiceCoordinator {
  static let shared = AIServiceCoordinator()

  private var chain: Task<Void, Never>?

  func enqueue<T: Sendable>(
    priority: TaskPriority = .utility,
    operation: @escaping @Sendable @MainActor () async throws -> T
  ) async throws -> T {
    let previous = chain

    return try await withCheckedThrowingContinuation { continuation in
      let task = Task(priority: priority) { @MainActor in
        await previous?.value
        do {
          let value = try await operation()
          continuation.resume(returning: value)
        } catch {
          continuation.resume(throwing: error)
        }
      }

      chain = Task {
        await task.value
      }
    }
  }
}
