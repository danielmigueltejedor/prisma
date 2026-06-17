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
    if AIServiceFactory.hasFreeOnDeviceAI { return onDevice }
    #if DEBUG
    return fallback
    #else
    return onDevice
    #endif
  }

  private var shouldCoordinate: Bool {
    AIServiceFactory.hasFreeOnDeviceAI
  }

  private func coordinated<T: Sendable>(
    priority: TaskPriority = .utility,
    _ operation: @escaping @MainActor () async throws -> T
  ) async throws -> T {
    if shouldCoordinate {
      return try await AIServiceCoordinator.shared.enqueue(priority: priority, operation: operation)
    }
    return try await operation()
  }

  func summarizeArticle(_ article: Article) async throws -> SummaryDTO {
    let service = active
    return try await coordinated { try await service.summarizeArticle(article) }
  }

  func classifyArticle(_ article: Article) async throws -> [String] {
    let service = active
    return try await coordinated { try await service.classifyArticle(article) }
  }

  func clusterArticles(_ articles: [Article]) async throws -> [ClusterDTO] {
    let service = active
    return try await coordinated { try await service.clusterArticles(articles) }
  }

  func compareSources(cluster: ClusterDTO, articles: [Article]) async throws -> String {
    let service = active
    return try await coordinated { try await service.compareSources(cluster: cluster, articles: articles) }
  }

  func filterSameStoryArticleIDs(anchor: Article, candidates: [Article]) async throws -> [String] {
    let service = active
    return try await coordinated {
      try await service.filterSameStoryArticleIDs(anchor: anchor, candidates: candidates)
    }
  }

  func compareSameStory(anchor: Article, relatedArticles: [Article]) async throws -> SameStoryComparisonDTO {
    let service = active
    return try await coordinated { try await service.compareSameStory(anchor: anchor, relatedArticles: relatedArticles) }
  }

  func rankSimilarArticles(anchor: Article, candidates: [Article], limit: Int) async throws -> [String] {
    let service = active
    return try await coordinated { try await service.rankSimilarArticles(anchor: anchor, candidates: candidates, limit: limit) }
  }

  func generateDailyBriefing(articles: [Article], preferences: UserPreference) async throws -> DailyBriefingDTO {
    let service = active
    return try await coordinated { try await service.generateDailyBriefing(articles: articles, preferences: preferences) }
  }

  func explainContext(article: Article) async throws -> ContextExplanationDTO {
    let service = active
    return try await coordinated(priority: .utility) { try await service.explainContext(article: article) }
  }

  func translateArticle(
    _ article: Article,
    to targetLanguageCode: String,
    sourceLanguage: String?
  ) async throws -> TranslationDTO {
    let service = active
    return try await coordinated(priority: .userInitiated) {
      try await service.translateArticle(article, to: targetLanguageCode, sourceLanguage: sourceLanguage)
    }
  }

  func translatePlainTexts(
    _ texts: [String],
    to targetLanguageCode: String,
    sourceLanguage: String?
  ) async throws -> [String] {
    let service = active
    return try await coordinated(priority: .utility) {
      try await service.translatePlainTexts(texts, to: targetLanguageCode, sourceLanguage: sourceLanguage)
    }
  }
}
