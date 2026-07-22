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
    _ operation: @escaping @Sendable @MainActor () async throws -> T
  ) async throws -> T {
    if shouldCoordinate {
      return try await AIServiceCoordinator.shared.enqueue(priority: priority, operation: operation)
    }
    return try await operation()
  }

  func summarizeArticle(_ article: Article) async throws -> SummaryDTO {
    let service = active
    let article = MainActorValue(article)
    return try await coordinated(priority: .userInitiated) { @MainActor in
      try await service.summarizeArticle(article.value)
    }
  }

  func classifyArticle(_ article: Article) async throws -> [String] {
    let service = active
    let article = MainActorValue(article)
    return try await coordinated { @MainActor in
      try await service.classifyArticle(article.value)
    }
  }

  func clusterArticles(_ articles: [Article]) async throws -> [ClusterDTO] {
    let service = active
    let articles = MainActorValue(articles)
    return try await coordinated { @MainActor in
      try await service.clusterArticles(articles.value)
    }
  }

  func compareSources(cluster: ClusterDTO, articles: [Article]) async throws -> String {
    let service = active
    let articles = MainActorValue(articles)
    return try await coordinated { @MainActor in
      try await service.compareSources(cluster: cluster, articles: articles.value)
    }
  }

  func filterSameStoryArticleIDs(anchor: Article, candidates: [Article]) async throws -> [String] {
    let service = active
    let anchor = MainActorValue(anchor)
    let candidates = MainActorValue(candidates)
    return try await coordinated { @MainActor in
      try await service.filterSameStoryArticleIDs(anchor: anchor.value, candidates: candidates.value)
    }
  }

  func compareSameStory(anchor: Article, relatedArticles: [Article]) async throws -> SameStoryComparisonDTO {
    let service = active
    let anchor = MainActorValue(anchor)
    let relatedArticles = MainActorValue(relatedArticles)
    return try await coordinated(priority: .userInitiated) { @MainActor in
      try await service.compareSameStory(anchor: anchor.value, relatedArticles: relatedArticles.value)
    }
  }

  func rankSimilarArticles(anchor: Article, candidates: [Article], limit: Int) async throws -> [String] {
    let service = active
    let anchor = MainActorValue(anchor)
    let candidates = MainActorValue(candidates)
    return try await coordinated { @MainActor in
      try await service.rankSimilarArticles(anchor: anchor.value, candidates: candidates.value, limit: limit)
    }
  }

  func generateDailyBriefing(articles: [Article], preferences: UserPreference) async throws -> DailyBriefingDTO {
    let service = active
    let articles = MainActorValue(articles)
    let preferences = MainActorValue(preferences)
    return try await coordinated { @MainActor in
      try await service.generateDailyBriefing(articles: articles.value, preferences: preferences.value)
    }
  }

  func explainContext(article: Article) async throws -> ContextExplanationDTO {
    let service = active
    let article = MainActorValue(article)
    return try await coordinated(priority: .userInitiated) { @MainActor in
      try await service.explainContext(article: article.value)
    }
  }

  func translateArticle(
    _ article: Article,
    to targetLanguageCode: String,
    sourceLanguage: String?
  ) async throws -> TranslationDTO {
    let service = active
    let article = MainActorValue(article)
    return try await coordinated(priority: .userInitiated) { @MainActor in
      try await service.translateArticle(article.value, to: targetLanguageCode, sourceLanguage: sourceLanguage)
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

/// SwiftData models are main-actor bound; this box is only used while hopping through the AI task queue.
private struct MainActorValue<Value>: @unchecked Sendable {
  let value: Value
  init(_ value: Value) { self.value = value }
}
