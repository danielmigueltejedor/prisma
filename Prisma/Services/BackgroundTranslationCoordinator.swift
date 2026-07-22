import Foundation

@MainActor
final class BackgroundTranslationCoordinator {
  private static let articleFetchLimit = 300
  private static let maxTranslationsPerSweep = 8
  private static let maxRedditCommentPrefetchesPerSweep = 2
  private static let sweepCooldown: TimeInterval = 90

  private let articleRepository: ArticleRepository
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let translationService: ArticleTranslationService
  private let sharedRankingService: SharedArticleRankingService
  private let previewStore: ArticlePreviewTranslationStore
  private let redditCommentsService: RedditCommentsService
  private let redditCommentsTranslationService: RedditCommentsTranslationService
  private weak var backgroundWorkGate: AppBackgroundWorkGate?

  private var sweepTask: Task<Void, Never>?
  private var lastSweepStartedAt: Date?

  init(
    articleRepository: ArticleRepository,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    translationService: ArticleTranslationService,
    sharedRankingService: SharedArticleRankingService,
    previewStore: ArticlePreviewTranslationStore,
    redditCommentsService: RedditCommentsService,
    redditCommentsTranslationService: RedditCommentsTranslationService,
    backgroundWorkGate: AppBackgroundWorkGate? = nil
  ) {
    self.articleRepository = articleRepository
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.translationService = translationService
    self.sharedRankingService = sharedRankingService
    self.previewStore = previewStore
    self.redditCommentsService = redditCommentsService
    self.redditCommentsTranslationService = redditCommentsTranslationService
    self.backgroundWorkGate = backgroundWorkGate
  }

  func scheduleSweep(priority: TaskPriority = .utility) {
    guard backgroundWorkGate?.shouldDeferHeavyWork != true else { return }
    guard AIServiceFactory.hasFreeOnDeviceAI else { return }
    guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
    if let lastSweepStartedAt,
       Date().timeIntervalSince(lastSweepStartedAt) < Self.sweepCooldown {
      return
    }

    sweepTask?.cancel()
    sweepTask = Task(priority: priority) {
      defer { sweepTask = nil }
      await performSweep()
    }
  }

  func cancelSweep() {
    sweepTask?.cancel()
    sweepTask = nil
  }

  private func performSweep() async {
    guard !Task.isCancelled else { return }
    lastSweepStartedAt = .now

    guard let candidates = try? await prioritizedUntranslatedArticles() else { return }

    var translatedArticles: [Article] = []
    var translatedCount = 0
    for article in candidates {
      guard !Task.isCancelled else { return }
      guard translatedCount < Self.maxTranslationsPerSweep else { break }
      guard translationService.cachedTranslation(for: article) == nil else { continue }

      if await translationService.ensureTranslation(for: article) != nil {
        translatedArticles.append(article)
        translatedCount += 1
        if translatedCount.isMultiple(of: 3) {
          previewStore.mergeTranslations(for: translatedArticles)
          TranslationRefreshNotifier.publish()
        }
      }
      try? await Task.sleep(nanoseconds: 250_000_000)
      await Task.yield()
    }

    if translatedCount > 0 {
      previewStore.mergeTranslations(for: translatedArticles)
      TranslationRefreshNotifier.publish()
    }

    await prefetchRedditCommentsIfNeeded(limit: Self.maxRedditCommentPrefetchesPerSweep)

    let hasArticleBacklog = candidates.count > translatedCount
    if translatedCount >= Self.maxTranslationsPerSweep, hasArticleBacklog {
      scheduleSweep(priority: .background)
    }
  }

  private func prefetchRedditCommentsIfNeeded(limit: Int) async {
    guard limit > 0 else { return }
    guard let articles = try? articleRepository.fetchAll(limit: 120) else { return }

    var count = 0
    for article in articles {
      guard !Task.isCancelled else { return }
      guard count < limit else { break }
      guard isReddit(article) else { continue }
      guard translationService.needsTranslation(for: article) else { continue }
      guard let comments = try? await redditCommentsService.fetchComments(for: article) else { continue }
      _ = await redditCommentsTranslationService.translatedComments(for: article, comments: comments)
      count += 1
      try? await Task.sleep(nanoseconds: 350_000_000)
      await Task.yield()
    }
  }

  private func isReddit(_ article: Article) -> Bool {
    if article.feedSource?.effectivePlatform == .reddit { return true }
    return FeedPlatform.detect(feedURL: article.originalFeedUrl) == .reddit
  }

  private func prioritizedUntranslatedArticles() async throws -> [Article] {
    let enabledSourceIds = Set(try feedSourceRepository.fetchEnabled().map(\.id))
    let snapshot = try await sharedRankingService.ranking(limit: Self.articleFetchLimit)
    let ranked = snapshot.ranked.filter { enabledSourceIds.contains($0.sourceId) }

    let needing = ranked.filter { article in
      translationService.needsTranslation(for: article)
        && translationService.cachedTranslation(for: article) == nil
    }
    guard !needing.isEmpty else { return [] }

    let rankByID = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($1.id, $0) })
    let favorites = snapshot.favoriteSourceIds

    return needing.sorted { lhs, rhs in
      translationPriority(lhs, rankIndex: rankByID[lhs.id], favorites: favorites)
        > translationPriority(rhs, rankIndex: rankByID[rhs.id], favorites: favorites)
    }
  }

  private func translationPriority(
    _ article: Article,
    rankIndex: Int?,
    favorites: Set<UUID>
  ) -> Int {
    var score = 0
    if let rankIndex {
      score += max(0, 10_000 - rankIndex)
    }
    if isEnglish(article) {
      score += 8_000
    }
    if isReddit(article) {
      score += 4_000
    }
    if favorites.contains(article.sourceId) {
      score += 2_000
    }
    if article.isSaved {
      score += 1_500
    }
    if article.isFavorite {
      score += 1_200
    }
    if let publishedAt = article.publishedAt {
      let hours = max(0, -publishedAt.timeIntervalSinceNow / 3_600)
      score += Int(max(0, 720 - hours))
    }
    return score
  }

  private func isEnglish(_ article: Article) -> Bool {
    if let code = ArticleLanguageDetector.detectLanguageCode(for: article) {
      return code.hasPrefix("en")
    }
    let text = ArticleLanguageDetector.sampleText(from: article)
    let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
    guard !letters.isEmpty else { return false }
    let asciiCount = letters.filter { $0.value < 128 }.count
    return Double(asciiCount) / Double(letters.count) > 0.9
  }
}

@MainActor
enum TranslationRefreshNotifier {
  private static var debounceTask: Task<Void, Never>?

  static func publish() {
    debounceTask?.cancel()
    debounceTask = Task {
      try? await Task.sleep(nanoseconds: 350_000_000)
      guard !Task.isCancelled else { return }
      NotificationCenter.default.post(name: .articleTranslationsDidUpdate, object: nil)
    }
  }
}
