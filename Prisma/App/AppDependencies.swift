import Foundation
import SwiftData

@MainActor
final class AppDependencies {
  let modelContainer: ModelContainer
  let feedSourceRepository: FeedSourceRepository
  let articleRepository: ArticleRepository
  let preferenceRepository: PreferenceRepository
  let collectionRepository: CollectionRepository

  let networkClient: NetworkClient
  let feedDownloader: FeedDownloader
  let feedService: FeedService
  let articleService: ArticleService
  let searchService: SearchService
  let recommendationEngine: RecommendationEngine
  let sharedRankingService: SharedArticleRankingService
  let aiService: AIService
  let translationService: ArticleTranslationService
  let previewTranslationStore: ArticlePreviewTranslationStore
  let redditCommentsService: RedditCommentsService
  let redditCommentsTranslationService: RedditCommentsTranslationService
  let summaryService: ArticleSummaryService
  let insightRepository: AIArticleInsightRepository
  let weatherService: WeatherService
  let offlineReadingCoordinator: OfflineReadingCoordinator
  let backgroundTranslationCoordinator: BackgroundTranslationCoordinator
  let backgroundContentCoordinator: BackgroundContentCoordinator
  let localReadingCorpusService: LocalReadingCorpusService
  let backgroundWorkGate = AppBackgroundWorkGate()

  private var deferredFeedRefreshTask: Task<Void, Never>?

  init(modelContainer: ModelContainer) {
    self.modelContainer = modelContainer
    let context = modelContainer.mainContext

    feedSourceRepository = FeedSourceRepository(context: context)
    articleRepository = ArticleRepository(context: context)
    preferenceRepository = PreferenceRepository(context: context)
    collectionRepository = CollectionRepository(context: context)

    networkClient = NetworkClient()
    feedDownloader = FeedDownloader(networkClient: networkClient)
    feedService = FeedService(
      feedSourceRepository: feedSourceRepository,
      articleRepository: articleRepository,
      feedDownloader: feedDownloader
    )
    articleService = ArticleService(articleRepository: articleRepository)
    searchService = SearchService(articleRepository: articleRepository)
    recommendationEngine = RecommendationEngine()
    sharedRankingService = SharedArticleRankingService(
      articleRepository: articleRepository,
      feedSourceRepository: feedSourceRepository,
      preferenceRepository: preferenceRepository,
      recommendationEngine: recommendationEngine
    )
    SharedRankingCacheNotifier.register(sharedRankingService)
    let primaryAI = AIServiceFactory.makePrimary()
    aiService = LocalFirstAIService(onDevice: primaryAI, fallback: MockAIService())
    translationService = ArticleTranslationService(
      translationRepository: ArticleTranslationRepository(context: context),
      preferenceRepository: preferenceRepository,
      aiService: aiService
    )
    previewTranslationStore = ArticlePreviewTranslationStore(translationService: translationService)
    redditCommentsService = RedditCommentsService(networkClient: networkClient)
    redditCommentsTranslationService = RedditCommentsTranslationService(
      repository: RedditCommentsTranslationRepository(context: context),
      translationService: translationService,
      aiService: aiService
    )
    summaryService = ArticleSummaryService(
      summaryRepository: AIArticleSummaryRepository(context: context),
      aiService: aiService
    )
    insightRepository = AIArticleInsightRepository(context: context)
    weatherService = WeatherService(networkClient: networkClient)
    offlineReadingCoordinator = OfflineReadingCoordinator(
      feedService: feedService,
      articleRepository: articleRepository,
      feedSourceRepository: feedSourceRepository,
      preferenceRepository: preferenceRepository,
      translationService: translationService,
      sharedRankingService: sharedRankingService,
      previewStore: previewTranslationStore,
      redditCommentsService: redditCommentsService,
      redditCommentsTranslationService: redditCommentsTranslationService,
      backgroundWorkGate: backgroundWorkGate
    )
    backgroundTranslationCoordinator = BackgroundTranslationCoordinator(
      articleRepository: articleRepository,
      feedSourceRepository: feedSourceRepository,
      preferenceRepository: preferenceRepository,
      translationService: translationService,
      sharedRankingService: sharedRankingService,
      previewStore: previewTranslationStore,
      redditCommentsService: redditCommentsService,
      redditCommentsTranslationService: redditCommentsTranslationService,
      backgroundWorkGate: backgroundWorkGate
    )
    localReadingCorpusService = LocalReadingCorpusService(
      repository: LocalCorpusRepository(context: context),
      preferenceRepository: preferenceRepository
    )
    backgroundContentCoordinator = BackgroundContentCoordinator(
      feedService: feedService,
      feedSourceRepository: feedSourceRepository,
      preferenceRepository: preferenceRepository,
      articleRepository: articleRepository,
      translationService: translationService,
      summaryService: summaryService,
      insightRepository: insightRepository,
      aiService: aiService,
      sharedRankingService: sharedRankingService,
      previewStore: previewTranslationStore,
      backgroundWorkGate: backgroundWorkGate
    )
  }

  func bootstrap() async throws {
    // Keep first launch bootstrap minimal to avoid startup hitching.
    try feedSourceRepository.seedRecommendedIfNeeded()
    await Task.yield()
    _ = try preferenceRepository.getOrCreate()
    await Task.yield()
    try enableDefaultSourcesIfNeeded()
  }

  func schedulePostLaunchWarmup() {
    Task(priority: .utility) { @MainActor in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      guard !Task.isCancelled, !backgroundWorkGate.shouldDeferHeavyWork else { return }
      offlineReadingCoordinator.schedulePrefetch()
      backgroundTranslationCoordinator.scheduleSweep(priority: .utility)
      backgroundContentCoordinator.scheduleIdleWarmup()
    }
  }

  func pauseBackgroundWorkForReader() {
    backgroundWorkGate.setReaderActive(true)
    deferredFeedRefreshTask?.cancel()
    offlineReadingCoordinator.cancelPrefetch()
    backgroundTranslationCoordinator.cancelSweep()
    backgroundContentCoordinator.cancelPipeline()
  }

  func resumeBackgroundWorkAfterReader() {
    backgroundWorkGate.setReaderActive(false)
    backgroundTranslationCoordinator.scheduleSweep(priority: .utility)
    offlineReadingCoordinator.schedulePrefetch()
    backgroundContentCoordinator.scheduleDeferredTasks()
  }

  func refreshEnabledSourcesOnLaunchIfNeeded() async {
    let enabled = (try? feedSourceRepository.fetchEnabled()) ?? []
    guard !enabled.isEmpty else { return }

    let isFirstRefresh = (try? preferenceRepository.getOrCreate().lastRefreshAt) == nil
    if isFirstRefresh {
      let initial = Array(enabled.prefix(2))
      _ = await feedService.refreshSourcesLenient(initial)
      try? preferenceRepository.touchLastRefresh()
      scheduleDeferredFeedRefresh(remaining: Array(enabled.dropFirst(2)))
      return
    }

    guard !backgroundWorkGate.shouldDeferHeavyWork else { return }
    _ = await feedService.refreshEnabledWithoutFetchedData()
  }

  private func scheduleDeferredFeedRefresh(remaining: [FeedSource]) {
    guard !remaining.isEmpty else {
      try? preferenceRepository.touchLastRefresh()
      return
    }

    deferredFeedRefreshTask?.cancel()
    deferredFeedRefreshTask = Task(priority: .utility) { @MainActor in
      try? await Task.sleep(nanoseconds: 8_000_000_000)
      guard !Task.isCancelled, !backgroundWorkGate.shouldDeferHeavyWork else {
        if !Task.isCancelled {
          scheduleDeferredFeedRefresh(remaining: remaining)
        }
        return
      }
      _ = await feedService.refreshSourcesLenient(remaining)
      try? preferenceRepository.touchLastRefresh()
    }
  }

  private func enableDefaultSourcesIfNeeded() throws {
    guard try feedSourceRepository.fetchEnabled().isEmpty else { return }
    let prefs = try preferenceRepository.getOrCreate()
    let country = prefs.homeCountryCode ?? NewsCountry.detected.code
    try feedSourceRepository.enableDefaultSources(forCountry: country)
  }
}
