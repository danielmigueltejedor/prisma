import Foundation

struct TranslationDTO: Codable, Sendable {
  let articleId: String
  let targetLanguageCode: String
  let sourceLanguageCode: String?
  let translatedTitle: String
  let translatedBody: String
  let provider: String
  let generatedAt: Date
}
