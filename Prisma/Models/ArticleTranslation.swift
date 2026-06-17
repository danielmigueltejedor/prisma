import Foundation
import SwiftData

@Model
final class ArticleTranslation {
  @Attribute(.unique) var cacheKey: String
  var articleId: String
  var targetLanguageCode: String
  var sourceLanguageCode: String?
  var translatedTitle: String
  var translatedBody: String
  var generatedAt: Date
  var provider: String

  init(
    cacheKey: String,
    articleId: String,
    targetLanguageCode: String,
    sourceLanguageCode: String?,
    translatedTitle: String,
    translatedBody: String,
    generatedAt: Date = .now,
    provider: String
  ) {
    self.cacheKey = cacheKey
    self.articleId = articleId
    self.targetLanguageCode = targetLanguageCode
    self.sourceLanguageCode = sourceLanguageCode
    self.translatedTitle = translatedTitle
    self.translatedBody = translatedBody
    self.generatedAt = generatedAt
    self.provider = provider
  }

  static func cacheKey(articleId: String, targetLanguageCode: String) -> String {
    "\(articleId)|\(targetLanguageCode.lowercased())|v2"
  }
}
