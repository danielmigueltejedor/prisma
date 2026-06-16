import Foundation
import SwiftData

@Model
final class NewsCluster {
  @Attribute(.unique) var id: UUID
  var title: String
  var summary: String?
  var articleIds: [String]
  var generatedAt: Date
  var comparisonNote: String?

  init(
    id: UUID = UUID(),
    title: String,
    summary: String? = nil,
    articleIds: [String] = [],
    generatedAt: Date = .now,
    comparisonNote: String? = nil
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.articleIds = articleIds
    self.generatedAt = generatedAt
    self.comparisonNote = comparisonNote
  }
}
