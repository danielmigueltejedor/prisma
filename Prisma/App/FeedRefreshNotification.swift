import Foundation

extension Notification.Name {
  static let feedsDidRefresh = Notification.Name("Prisma.feedsDidRefresh")
  static let articleLibraryDidChange = Notification.Name("Prisma.articleLibraryDidChange")
  static let preferencesDidChange = Notification.Name("Prisma.preferencesDidChange")
  static let articleTranslationsDidUpdate = Notification.Name("Prisma.articleTranslationsDidUpdate")
}

@MainActor
enum FeedRefreshNotifier {
  private static var debounceTask: Task<Void, Never>?

  static func publish() {
    debounceTask?.cancel()
    debounceTask = Task {
      try? await Task.sleep(nanoseconds: 450_000_000)
      guard !Task.isCancelled else { return }
      NotificationCenter.default.post(name: .feedsDidRefresh, object: nil)
    }
  }
}

@MainActor
enum ArticleLibraryNotifier {
  static func publish() {
    NotificationCenter.default.post(name: .articleLibraryDidChange, object: nil)
  }
}

@MainActor
enum PreferencesNotifier {
  static func publish() {
    NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
  }
}
