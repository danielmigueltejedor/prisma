import Foundation
import SwiftData

@MainActor
final class RedditCommentsTranslationRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func find(articleId: String, targetLanguageCode: String) throws -> RedditCommentsTranslation? {
    let key = RedditCommentsTranslation.cacheKey(
      articleId: articleId,
      targetLanguageCode: targetLanguageCode
    )
    let descriptor = FetchDescriptor<RedditCommentsTranslation>(
      predicate: #Predicate { $0.cacheKey == key }
    )
    return try context.fetch(descriptor).first
  }

  func save(
    articleId: String,
    targetLanguageCode: String,
    payload: RedditCommentTranslationPayload
  ) throws {
    let key = RedditCommentsTranslation.cacheKey(
      articleId: articleId,
      targetLanguageCode: targetLanguageCode
    )
    let data = try JSONEncoder().encode(payload)
    let json = String(decoding: data, as: UTF8.self)

    if let existing = try find(articleId: articleId, targetLanguageCode: targetLanguageCode) {
      existing.payloadJSON = json
      existing.generatedAt = .now
    } else {
      context.insert(
        RedditCommentsTranslation(
          cacheKey: key,
          articleId: articleId,
          targetLanguageCode: targetLanguageCode.lowercased(),
          payloadJSON: json
        )
      )
    }
    try context.save()
  }

  func payload(for record: RedditCommentsTranslation) -> RedditCommentTranslationPayload? {
    guard let data = record.payloadJSON.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(RedditCommentTranslationPayload.self, from: data)
  }
}
