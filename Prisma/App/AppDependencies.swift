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
  let aiService: AIService
  let translationService: ArticleTranslationService
  let previewTranslationStore: ArticlePreviewTranslationStore
  let redditCommentsService: RedditCommentsService
  let redditCommentsTranslationService: RedditCommentsTranslationService
  let summaryService: ArticleSummaryService
  let insightRepository: AIArticleInsightRepository
  let weatherService: WeatherService
  let offlineReadingCoordinator: OfflineReadingCoordinator

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
      recommendationEngine: recommendationEngine,
      previewStore: previewTranslationStore,
      redditCommentsService: redditCommentsService,
      redditCommentsTranslationService: redditCommentsTranslationService
    )
  }

  func bootstrap() async throws {
    try feedSourceRepository.seedRecommendedIfNeeded()
    _ = try preferenceRepository.getOrCreate()
    try enableDefaultSourcesIfNeeded()
    offlineReadingCoordinator.schedulePrefetch()
  }

  func refreshEnabledSourcesOnLaunchIfNeeded() async {
    let enabled = (try? feedSourceRepository.fetchEnabled()) ?? []
    guard !enabled.isEmpty else { return }

    let isFirstRefresh = (try? preferenceRepository.getOrCreate().lastRefreshAt) == nil
    if isFirstRefresh {
      _ = await feedService.refreshAllLenient()
      try? preferenceRepository.touchLastRefresh()
      return
    }

    _ = await feedService.refreshEnabledWithoutFetchedData()
  }

  private func enableDefaultSourcesIfNeeded() throws {
    guard try feedSourceRepository.fetchEnabled().isEmpty else { return }
    let prefs = try preferenceRepository.getOrCreate()
    let country = prefs.homeCountryCode ?? NewsCountry.detected.code
    try feedSourceRepository.enableDefaultSources(forCountry: country)
  }
}
