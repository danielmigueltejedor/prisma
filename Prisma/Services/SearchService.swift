import Foundation
import SwiftData

@MainActor
struct SearchService {
  let articleRepository: ArticleRepository

  func search(
    query: String,
    sourceId: UUID? = nil,
    unreadOnly: Bool = false
  ) throws -> [Article] {
    var results = try articleRepository.search(query: query)
    if let sourceId {
      results = results.filter { $0.sourceId == sourceId }
    }
    if unreadOnly {
      results = results.filter { !$0.isRead }
    }
    return results
  }
}
