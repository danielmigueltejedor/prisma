import Foundation
import SwiftData

@Model
final class SavedArticle {
  @Attribute(.unique) var id: UUID
  var savedAt: Date

  var article: Article?

  @Relationship(inverse: \Collection.savedArticles)
  var collections: [Collection] = []

  init(id: UUID = UUID(), savedAt: Date = .now, article: Article? = nil) {
    self.id = id
    self.savedAt = savedAt
    self.article = article
  }
}
