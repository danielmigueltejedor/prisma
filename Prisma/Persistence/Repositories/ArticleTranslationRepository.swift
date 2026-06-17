import Foundation
import SwiftData

@MainActor
final class ArticleTranslationRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func find(articleId: String, targetLanguageCode: String) throws -> ArticleTranslation? {
    let key = ArticleTranslation.cacheKey(
      articleId: articleId,
      targetLanguageCode: targetLanguageCode
    )
    let descriptor = FetchDescriptor<ArticleTranslation>(
      predicate: #Predicate { $0.cacheKey == key }
    )
    return try context.fetch(descriptor).first
  }

  func findAll(articleIds: [String], targetLanguageCode: String) throws -> [ArticleTranslation] {
    guard !articleIds.isEmpty else { return [] }
    let language = targetLanguageCode.lowercased()
    let descriptor = FetchDescriptor<ArticleTranslation>(
      predicate: #Predicate { translation in
        articleIds.contains(translation.articleId) && translation.targetLanguageCode == language
      }
    )
    return try context.fetch(descriptor)
  }

  func save(_ dto: TranslationDTO) throws -> ArticleTranslation {
    let key = ArticleTranslation.cacheKey(
      articleId: dto.articleId,
      targetLanguageCode: dto.targetLanguageCode
    )
    if let existing = try find(articleId: dto.articleId, targetLanguageCode: dto.targetLanguageCode) {
      existing.translatedTitle = dto.translatedTitle
      existing.translatedBody = dto.translatedBody
      existing.sourceLanguageCode = dto.sourceLanguageCode
      existing.generatedAt = dto.generatedAt
      existing.provider = dto.provider
      try context.save()
      return existing
    }

    let record = ArticleTranslation(
      cacheKey: key,
      articleId: dto.articleId,
      targetLanguageCode: dto.targetLanguageCode.lowercased(),
      sourceLanguageCode: dto.sourceLanguageCode,
      translatedTitle: dto.translatedTitle,
      translatedBody: dto.translatedBody,
      generatedAt: dto.generatedAt,
      provider: dto.provider
    )
    context.insert(record)
    try context.save()
    return record
  }
}
