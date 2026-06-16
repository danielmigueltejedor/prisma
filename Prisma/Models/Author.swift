import Foundation
import SwiftData

@Model
final class Author {
  @Attribute(.unique) var id: UUID
  var name: String
  var email: String?

  init(id: UUID = UUID(), name: String, email: String? = nil) {
    self.id = id
    self.name = name
    self.email = email
  }
}
