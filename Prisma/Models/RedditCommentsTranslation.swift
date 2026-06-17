import Foundation
import SwiftData

@Model
final class RedditCommentsTranslation {
  @Attribute(.unique) var cacheKey: String
  var articleId: String
  var targetLanguageCode: String
  var payloadJSON: String
  var generatedAt: Date

  init(
    cacheKey: String,
    articleId: String,
    targetLanguageCode: String,
    payloadJSON: String,
    generatedAt: Date = .now
  ) {
    self.cacheKey = cacheKey
    self.articleId = articleId
    self.targetLanguageCode = targetLanguageCode
    self.payloadJSON = payloadJSON
    self.generatedAt = generatedAt
  }

  static func cacheKey(articleId: String, targetLanguageCode: String) -> String {
    "\(articleId)|reddit|\(targetLanguageCode.lowercased())|v1"
  }
}

struct RedditCommentTranslationPayload: Codable {
  var bodiesByCommentId: [String: String]
}
