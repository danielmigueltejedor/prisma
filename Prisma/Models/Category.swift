import Foundation
import SwiftData

@Model
final class Category {
  @Attribute(.unique) var id: UUID
  var name: String
  var slug: String

  @Relationship(inverse: \Article.categories)
  var articles: [Article] = []

  init(id: UUID = UUID(), name: String, slug: String? = nil) {
    self.id = id
    self.name = name
    self.slug = slug ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
  }
}
