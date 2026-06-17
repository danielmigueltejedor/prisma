import Foundation
import SwiftData

@Model
final class AIArticleInsight {
  @Attribute(.unique) var cacheKey: String
  var articleId: String
  var kindRaw: String
  var text: String
  var generatedAt: Date
  var provider: String
  var relatedArticleIds: [String]
  var unifiedStoryText: String?

  init(
    cacheKey: String,
    articleId: String,
    kind: AIInsightKind,
    text: String,
    generatedAt: Date = .now,
    provider: String = "apple-intelligence-on-device",
    relatedArticleIds: [String] = [],
    unifiedStoryText: String? = nil
  ) {
    self.cacheKey = cacheKey
    self.articleId = articleId
    self.kindRaw = kind.rawValue
    self.text = text
    self.generatedAt = generatedAt
    self.provider = provider
    self.relatedArticleIds = relatedArticleIds
    self.unifiedStoryText = unifiedStoryText
  }

  var kind: AIInsightKind {
    get { AIInsightKind(rawValue: kindRaw) ?? .context }
    set { kindRaw = newValue.rawValue }
  }

  static func cacheKey(articleId: String, kind: AIInsightKind) -> String {
    let version = kind == .comparison ? "v2" : "v1"
    return "\(articleId)|\(kind.rawValue)|\(version)"
  }
}

enum AIInsightKind: String, Codable {
  case comparison
  case context
}
