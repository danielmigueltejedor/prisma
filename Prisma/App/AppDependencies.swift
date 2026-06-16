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
  let subscriptionService: SubscriptionServiceProtocol
  let plusGate: PrismaPlusGatekeeper

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
    aiService = MockAIService()

    if AppConfiguration.useMockSubscription {
      subscriptionService = MockSubscriptionService(preferenceRepository: preferenceRepository)
    } else {
      subscriptionService = StoreKitSubscriptionService(preferenceRepository: preferenceRepository)
    }
    plusGate = PrismaPlusGatekeeper(subscriptionService: subscriptionService)
  }

  func bootstrap() async throws {
    try feedSourceRepository.seedRecommendedIfNeeded()
    _ = try preferenceRepository.getOrCreate()
    _ = try preferenceRepository.getOrCreateSubscriptionStatus()
    try enableDefaultSourcesIfNeeded()
    await subscriptionService.updateStatus()
  }

  private func enableDefaultSourcesIfNeeded() throws {
    guard try feedSourceRepository.fetchEnabled().isEmpty else { return }
    let prefs = try preferenceRepository.getOrCreate()
    let country = prefs.homeCountryCode ?? NewsCountry.detected.code
    try feedSourceRepository.enableDefaultSources(forCountry: country)
  }
}
