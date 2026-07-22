import Foundation

extension Notification.Name {
  static let feedsDidRefresh = Notification.Name("Prisma.feedsDidRefresh")
  static let articleLibraryDidChange = Notification.Name("Prisma.articleLibraryDidChange")
  static let preferencesDidChange = Notification.Name("Prisma.preferencesDidChange")
  static let articleTranslationsDidUpdate = Notification.Name("Prisma.articleTranslationsDidUpdate")
  static let articleTrainingLike = Notification.Name("Prisma.articleTrainingLike")
  static let articleTrainingSave = Notification.Name("Prisma.articleTrainingSave")
}

enum ArticleTrainingNotificationKey {
  static let articleID = "articleID"
}

@MainActor
enum FeedRefreshNotifier {
  private static var debounceTask: Task<Void, Never>?

  static func publish() {
    debounceTask?.cancel()
    debounceTask = Task {
      try? await Task.sleep(nanoseconds: 450_000_000)
      guard !Task.isCancelled else { return }
      SharedRankingCacheNotifier.invalidate()
      NotificationCenter.default.post(name: .feedsDidRefresh, object: nil)
    }
  }
}

@MainActor
enum SharedRankingCacheNotifier {
  private static weak var service: SharedArticleRankingService?

  static func register(_ service: SharedArticleRankingService) {
    self.service = service
  }

  static func invalidate() {
    service?.invalidate()
  }
}

@MainActor
enum ArticleLibraryNotifier {
  private static var debounceTask: Task<Void, Never>?

  static func publish() {
    debounceTask?.cancel()
    debounceTask = Task {
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled else { return }
      SharedRankingCacheNotifier.invalidate()
      NotificationCenter.default.post(name: .articleLibraryDidChange, object: nil)
    }
  }
}

@MainActor
enum PreferencesNotifier {
  static func publish() {
    NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
  }
}

@MainActor
enum ArticleTrainingNotifier {
  static func publishLike(articleID: String) {
    NotificationCenter.default.post(
      name: .articleTrainingLike,
      object: nil,
      userInfo: [ArticleTrainingNotificationKey.articleID: articleID]
    )
  }

  static func publishSave(articleID: String) {
    NotificationCenter.default.post(
      name: .articleTrainingSave,
      object: nil,
      userInfo: [ArticleTrainingNotificationKey.articleID: articleID]
    )
  }
}
