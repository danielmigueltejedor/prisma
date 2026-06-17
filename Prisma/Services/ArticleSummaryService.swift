import Foundation

@MainActor
final class ArticleSummaryService {
  private let summaryRepository: AIArticleSummaryRepository
  private let aiService: AIService
  private var inFlightTasks: [String: Task<String?, Never>] = [:]

  init(summaryRepository: AIArticleSummaryRepository, aiService: AIService) {
    self.summaryRepository = summaryRepository
    self.aiService = aiService
  }

  func cachedSummary(for article: Article) -> AIArticleSummary? {
    try? summaryRepository.find(articleId: article.id)
  }

  @discardableResult
  func ensureSummary(for article: Article) async -> AIArticleSummary? {
    guard canSummarize else { return nil }
    if let cached = cachedSummary(for: article) { return cached }

    let articleId = article.id
    if let existing = inFlightTasks[articleId] {
      _ = await existing.value
      return cachedSummary(for: article)
    }

    let task = Task { @MainActor () -> String? in
      do {
        let dto = try await aiService.summarizeArticle(article)
        _ = try summaryRepository.save(dto)
        return articleId
      } catch {
        return nil
      }
    }

    inFlightTasks[articleId] = task
    defer { inFlightTasks[articleId] = nil }
    guard await task.value != nil else { return nil }
    return cachedSummary(for: article)
  }

  private var canSummarize: Bool {
    #if DEBUG
    return true
    #else
    return AIServiceFactory.hasFreeOnDeviceAI
    #endif
  }
}
