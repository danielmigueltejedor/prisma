import Foundation
import SwiftData

@MainActor
final class AIArticleInsightRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func find(articleId: String, kind: AIInsightKind) throws -> AIArticleInsight? {
    let key = AIArticleInsight.cacheKey(articleId: articleId, kind: kind)
    let descriptor = FetchDescriptor<AIArticleInsight>(
      predicate: #Predicate { $0.cacheKey == key }
    )
    return try context.fetch(descriptor).first
  }

  @discardableResult
  func save(
    articleId: String,
    kind: AIInsightKind,
    text: String,
    provider: String = "apple-intelligence-on-device",
    relatedArticleIds: [String] = [],
    unifiedStory: String? = nil
  ) throws -> AIArticleInsight {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let key = AIArticleInsight.cacheKey(articleId: articleId, kind: kind)
    if let existing = try find(articleId: articleId, kind: kind) {
      existing.text = cleaned
      existing.generatedAt = .now
      existing.provider = provider
      existing.relatedArticleIds = relatedArticleIds
      existing.unifiedStoryText = unifiedStory?.trimmingCharacters(in: .whitespacesAndNewlines)
      try context.save()
      return existing
    }

    let record = AIArticleInsight(
      cacheKey: key,
      articleId: articleId,
      kind: kind,
      text: cleaned,
      generatedAt: .now,
      provider: provider,
      relatedArticleIds: relatedArticleIds,
      unifiedStoryText: unifiedStory
    )
    context.insert(record)
    try context.save()
    return record
  }
}
