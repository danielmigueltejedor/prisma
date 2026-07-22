import Foundation

@MainActor
final class OfflineReadingCoordinator {
  private static let staleFeedInterval: TimeInterval = 30 * 60
  private static let prefetchCooldown: TimeInterval = 5 * 60
  private static let translationPrefetchLimit = 5
  private static let imagePrefetchLimit = 15
  private static let redditPrefetchLimit = 4

  private let feedService: FeedService
  private let articleRepository: ArticleRepository
  private let preferenceRepository: PreferenceRepository
  private let translationService: ArticleTranslationService
  private let sharedRankingService: SharedArticleRankingService
  private let previewStore: ArticlePreviewTranslationStore
  private let redditCommentsService: RedditCommentsService
  private let redditCommentsTranslationService: RedditCommentsTranslationService
  private weak var backgroundWorkGate: AppBackgroundWorkGate?

  private var prefetchTask: Task<Void, Never>?
  private var lastPrefetchAt: Date?

  init(
    feedService: FeedService,
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
    self.feedService = feedService
    self.articleRepository = articleRepository
    self.preferenceRepository = preferenceRepository
    self.translationService = translationService
    self.sharedRankingService = sharedRankingService
    self.previewStore = previewStore
    self.redditCommentsService = redditCommentsService
    self.redditCommentsTranslationService = redditCommentsTranslationService
    self.backgroundWorkGate = backgroundWorkGate
    _ = feedSourceRepository
  }

  func schedulePrefetch() {
    guard backgroundWorkGate?.shouldDeferHeavyWork != true else { return }
    guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
    if let lastPrefetchAt, Date().timeIntervalSince(lastPrefetchAt) < Self.prefetchCooldown {
      return
    }

    prefetchTask?.cancel()
    prefetchTask = Task(priority: .utility) {
      defer { prefetchTask = nil }
      await performPrefetch()
    }
  }

  func cancelPrefetch() {
    prefetchTask?.cancel()
    prefetchTask = nil
  }

  private func performPrefetch() async {
    guard backgroundWorkGate?.shouldDeferHeavyWork != true else { return }
    guard !Task.isCancelled else { return }
    await refreshFeedsIfStale()
    guard !Task.isCancelled else { return }
    guard let articles = try? await interestArticles() else { return }

    lastPrefetchAt = .now
    previewStore.refresh(for: articles)
    await prefetchTranslations(for: articles)
    guard !Task.isCancelled else { return }
    await prefetchImages(for: articles)
    guard !Task.isCancelled else { return }
    await prefetchRedditComments(for: articles)
  }

  private func refreshFeedsIfStale() async {
    let lastRefresh = try? preferenceRepository.getOrCreate().lastRefreshAt
    guard lastRefresh != nil else { return }
    let isStale = lastRefresh.map { Date().timeIntervalSince($0) >= Self.staleFeedInterval } ?? false
    guard isStale else { return }
    _ = try? await feedService.refreshAll()
  }

  private func interestArticles() async throws -> [Article] {
    let snapshot = try await sharedRankingService.ranking(limit: 200)
    let ranked = snapshot.ranked
    let all = try articleRepository.fetchAll(limit: 200)

    var picks: [Article] = []
    var seen = Set<String>()
    for article in ranked where seen.insert(article.id).inserted {
      picks.append(article)
      if picks.count >= 80 { break }
    }
    for article in all where article.isSaved && seen.insert(article.id).inserted {
      picks.append(article)
    }
    return picks
  }

  private func prefetchTranslations(for articles: [Article]) async {
    var translated: [Article] = []
    var count = 0
    for article in articles {
      guard !Task.isCancelled else { return }
      guard count < Self.translationPrefetchLimit else { break }
      guard translationService.needsTranslation(for: article) else { continue }
      guard translationService.cachedTranslation(for: article) == nil else { continue }
      if await translationService.ensureTranslation(for: article) != nil {
        translated.append(article)
        count += 1
      }
      await Task.yield()
    }
    if !translated.isEmpty {
      previewStore.mergeTranslations(for: translated)
    }
  }

  private func prefetchImages(for articles: [Article]) async {
    var count = 0
    for article in articles {
      guard !Task.isCancelled else { return }
      guard count < Self.imagePrefetchLimit else { break }
      guard let url = article.resolvedImageURL else { continue }
      _ = await ArticleImageLoader.image(for: url, maxPixelSize: 240)
      count += 1
      await Task.yield()
    }
  }

  private func prefetchRedditComments(for articles: [Article]) async {
    var count = 0
    for article in articles {
      guard !Task.isCancelled else { return }
      guard count < Self.redditPrefetchLimit else { break }
      let platform = article.feedSource?.platform
        ?? FeedPlatform.detect(feedURL: article.originalFeedUrl)
      guard platform == .reddit else { continue }
      guard let comments = try? await redditCommentsService.fetchComments(for: article) else { continue }
      _ = await redditCommentsTranslationService.translatedComments(for: article, comments: comments)
      count += 1
      await Task.yield()
    }
  }
}
