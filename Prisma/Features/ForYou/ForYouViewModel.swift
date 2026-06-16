import Foundation

@MainActor
@Observable
final class ForYouViewModel {
  var articles: [Article] = []
  var clusters: [ClusterDTO] = []
  var briefing: DailyBriefingDTO?
  var isLoadingAI = false
  var errorMessage: String?

  private let articleRepository: ArticleRepository
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let recommendationEngine: RecommendationEngine
  private let aiService: AIService
  private let plusGate: PrismaPlusGatekeeper

  init(
    articleRepository: ArticleRepository,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    recommendationEngine: RecommendationEngine,
    aiService: AIService,
    plusGate: PrismaPlusGatekeeper
  ) {
    self.articleRepository = articleRepository
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.recommendationEngine = recommendationEngine
    self.aiService = aiService
    self.plusGate = plusGate
  }

  var isPlusActive: Bool { plusGate.isPlusActive }

  func load() {
    do {
      let prefs = try preferenceRepository.getOrCreate()
      let all = try articleRepository.fetchAll()
      let favorites = Set(try feedSourceRepository.fetchFavorites().map(\.id))
      let savedCategories = Set(all.filter(\.isSaved).flatMap(\.categoryNames))
      let blockedSources = Set(try feedSourceRepository.fetchAll().filter(\.isBlocked).map(\.id))
      let readCounts = Dictionary(grouping: all.filter(\.isRead), by: \.sourceId)
        .mapValues(\.count)

      articles = recommendationEngine.rank(
        articles: all,
        favoriteSourceIds: favorites,
        savedCategoryNames: savedCategories,
        readSourceCounts: readCounts,
        blockedKeywords: prefs.blockedKeywords,
        blockedSourceIds: blockedSources
      )

      if isPlusActive {
        Task { await loadPlusContent(preferences: prefs) }
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadPlusContent(preferences: UserPreference) async {
    isLoadingAI = true
    defer { isLoadingAI = false }
    do {
      let clusterInput = Array(articles.prefix(20))
      let briefingInput = Array(articles.prefix(15))
      clusters = try await aiService.clusterArticles(clusterInput)
      briefing = try await aiService.generateDailyBriefing(
        articles: briefingInput,
        preferences: preferences
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func articles(for cluster: ClusterDTO) -> [Article] {
    let ids = Set(cluster.articleIds)
    return (try? articleRepository.fetchAll())?
      .filter { ids.contains($0.id) } ?? []
  }
}
