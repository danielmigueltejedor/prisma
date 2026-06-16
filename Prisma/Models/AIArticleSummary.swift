import Foundation
import SwiftData

@Model
final class AIArticleSummary {
  @Attribute(.unique) var id: UUID
  var articleId: String
  var summary: String
  var generatedAt: Date
  var provider: String

  init(
    id: UUID = UUID(),
    articleId: String,
    summary: String,
    generatedAt: Date = .now,
    provider: String = "mock"
  ) {
    self.id = id
    self.articleId = articleId
    self.summary = summary
    self.generatedAt = generatedAt
    self.provider = provider
  }
}
