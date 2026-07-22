import Foundation

@MainActor
final class ArticleSummaryService {
  private let summaryRepository: AIArticleSummaryRepository
  private let aiService: AIService
  private var inFlightTasks: [String: Task<Void, Never>] = [:]
  private var inFlightErrors: [String: Error] = [:]

  init(summaryRepository: AIArticleSummaryRepository, aiService: AIService) {
    self.summaryRepository = summaryRepository
    self.aiService = aiService
  }

  func cachedSummary(for article: Article) -> AIArticleSummary? {
    try? summaryRepository.find(articleId: article.id)
  }

  @discardableResult
  func ensureSummary(for article: Article) async -> Result<AIArticleSummary, Error> {
    guard canSummarize else {
      return .failure(AIServiceError.notAvailable)
    }
    if let cached = cachedSummary(for: article) { return .success(cached) }

    let articleId = article.id
    if let existing = inFlightTasks[articleId] {
      await existing.value
      if let cached = cachedSummary(for: article) { return .success(cached) }
      return .failure(inFlightErrors[articleId] ?? AIServiceError.notAvailable)
    }

    let task = Task { @MainActor in
      do {
        let dto = try await aiService.summarizeArticle(article)
        _ = try summaryRepository.save(dto)
        inFlightErrors[articleId] = nil
      } catch {
        inFlightErrors[articleId] = error
      }
    }

    inFlightTasks[articleId] = task
    defer { inFlightTasks[articleId] = nil }
    await task.value

    if let cached = cachedSummary(for: article) { return .success(cached) }
    return .failure(inFlightErrors[articleId] ?? AIServiceError.notAvailable)
  }

  private var canSummarize: Bool {
    AIServiceFactory.hasFreeOnDeviceAI
  }
}
