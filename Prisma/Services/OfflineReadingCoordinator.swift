import Foundation

@MainActor
final class OfflineReadingCoordinator {
  private static let staleFeedInterval: TimeInterval = 30 * 60
  private static let prefetchCooldown: TimeInterval = 5 * 60
  private static let translationPrefetchLimit = 8
  private static let imagePrefetchLimit = 15
  private static let redditPrefetchLimit = 3

  private let feedService: FeedService
  private let articleRepository: ArticleRepository
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let translationService: ArticleTranslationService
  private let recommendationEngine: RecommendationEngine
  private let previewStore: ArticlePreviewTranslationStore
  private let redditCommentsService: RedditCommentsService
  private let redditCommentsTranslationService: RedditCommentsTranslationService

  private var prefetchTask: Task<Void, Never>?
  private var lastPrefetchAt: Date?

  init(
    feedService: FeedService,
    articleRepository: ArticleRepository,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    translationService: ArticleTranslationService,
    recommendationEngine: RecommendationEngine,
    previewStore: ArticlePreviewTranslationStore,
    redditCommentsService: RedditCommentsService,
    redditCommentsTranslationService: RedditCommentsTranslationService
  ) {
    self.feedService = feedService
    self.articleRepository = articleRepository
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.translationService = translationService
    self.recommendationEngine = recommendationEngine
    self.previewStore = previewStore
    self.redditCommentsService = redditCommentsService
    self.redditCommentsTranslationService = redditCommentsTranslationService
  }

  func schedulePrefetch() {
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

  private func performPrefetch() async {
    guard !Task.isCancelled else { return }
    await refreshFeedsIfStale()
    guard !Task.isCancelled else { return }
    guard let articles = try? interestArticles() else { return }

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
    let isStale = lastRefresh.map { Date().timeIntervalSince($0) >= Self.staleFeedInterval } ?? true
    guard isStale else { return }
    _ = try? await feedService.refreshAll()
  }

  private func interestArticles() throws -> [Article] {
    let prefs = try preferenceRepository.getOrCreate()
    let blockedSources = try feedSourceRepository.fetchBlockedSourceIds()
    let all = try articleRepository.fetchAll(limit: 200)
    let sources = try feedSourceRepository.fetchAll()
    let sourcesById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
    let favorites = Set(try feedSourceRepository.fetchFavorites().map(\.id))
    let savedCategories = Set(all.filter(\.isSaved).flatMap(\.categoryNames))
    let readSourceCounts = Dictionary(
      all.filter(\.isRead).map { ($0.sourceId, 1) },
      uniquingKeysWith: +
    )
    let interest = ReadingInterestProfiler.build(
      from: all,
      favoriteSourceIds: favorites,
      sourcesById: sourcesById
    )

    let ranked = recommendationEngine.rank(
      articles: all,
      favoriteSourceIds: favorites,
      savedCategoryNames: savedCategories,
      readSourceCounts: readSourceCounts,
      blockedKeywords: prefs.blockedKeywords,
      blockedSourceIds: blockedSources,
      interest: interest
    )

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
    var count = 0
    for article in articles {
      guard !Task.isCancelled else { return }
      guard count < Self.translationPrefetchLimit else { break }
      guard translationService.needsTranslation(for: article) else { continue }
      guard translationService.cachedTranslation(for: article) == nil else { continue }
      if await translationService.ensureTranslation(for: article) != nil {
        count += 1
      }
      await Task.yield()
    }
    previewStore.refresh(for: articles)
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
