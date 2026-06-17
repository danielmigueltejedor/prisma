import Foundation

struct AuthorProfile: Identifiable, Hashable {
  var id: String { name }
  let name: String
}
