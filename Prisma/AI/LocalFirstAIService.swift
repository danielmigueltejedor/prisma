import Foundation

/// Enruta peticiones: Apple Intelligence local (gratis) con fallback a mock.
struct LocalFirstAIService: AIService {
  private let onDevice: AIService
  private let fallback: AIService

  init(onDevice: AIService, fallback: AIService = MockAIService()) {
    self.onDevice = onDevice
    self.fallback = fallback
  }

  private var active: AIService {
    AIServiceFactory.hasFreeOnDeviceAI ? onDevice : fallback
  }

  func summarizeArticle(_ article: Article) async throws -> SummaryDTO {
    try await active.summarizeArticle(article)
  }

  func classifyArticle(_ article: Article) async throws -> [String] {
    try await active.classifyArticle(article)
  }

  func clusterArticles(_ articles: [Article]) async throws -> [ClusterDTO] {
    try await active.clusterArticles(articles)
  }

  func compareSources(cluster: ClusterDTO, articles: [Article]) async throws -> String {
    try await active.compareSources(cluster: cluster, articles: articles)
  }

  func generateDailyBriefing(articles: [Article], preferences: UserPreference) async throws -> DailyBriefingDTO {
    try await active.generateDailyBriefing(articles: articles, preferences: preferences)
  }

  func explainContext(article: Article) async throws -> ContextExplanationDTO {
    try await active.explainContext(article: article)
  }
}
