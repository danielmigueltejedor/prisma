import Foundation
import SwiftData

@MainActor
final class AIArticleSummaryRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func find(articleId: String) throws -> AIArticleSummary? {
    let descriptor = FetchDescriptor<AIArticleSummary>(
      predicate: #Predicate { $0.articleId == articleId }
    )
    return try context.fetch(descriptor).first
  }

  func save(_ dto: SummaryDTO) throws -> AIArticleSummary {
    if let existing = try find(articleId: dto.articleId) {
      existing.summary = dto.summary
      existing.generatedAt = dto.generatedAt
      existing.provider = dto.provider
      try context.save()
      return existing
    }

    let record = AIArticleSummary(
      articleId: dto.articleId,
      summary: dto.summary,
      generatedAt: dto.generatedAt,
      provider: dto.provider
    )
    context.insert(record)
    try context.save()
    return record
  }
}
