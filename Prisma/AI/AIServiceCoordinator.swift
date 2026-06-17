import Foundation

/// Serializes on-device model work so multiple features don't contend for Apple Intelligence at once.
actor AIServiceCoordinator {
  static let shared = AIServiceCoordinator()

  private var chain: Task<Void, Never>?

  func enqueue<T: Sendable>(
    priority: TaskPriority = .utility,
    operation: @escaping @MainActor () async throws -> T
  ) async throws -> T {
    let previous = chain
    let box = ResultBox<T>()

    let task = Task(priority: priority) { @MainActor in
      await previous?.value
      do {
        let value = try await operation()
        await box.set(.success(value))
      } catch {
        await box.set(.failure(error))
      }
    }

    chain = Task {
      await task.value
    }

    return try await box.value()
  }
}

private actor ResultBox<T> {
  private var result: Result<T, Error>?

  func set(_ result: Result<T, Error>) {
    self.result = result
  }

  func value() async throws -> T {
    while result == nil {
      await Task.yield()
    }
    return try result!.get()
  }
}
