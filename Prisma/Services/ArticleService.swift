import Foundation
import SwiftData

@MainActor
final class ArticleService {
  private let articleRepository: ArticleRepository
  private let blocklist = BlocklistService()

  init(articleRepository: ArticleRepository) {
    self.articleRepository = articleRepository
  }

  func chronologicalFeed(
    blockedKeywords: [String] = [],
    blockedSourceIds: Set<UUID> = [],
    limit: Int? = nil
  ) throws -> [Article] {
    let all = try articleRepository.fetchAll(limit: limit)
    return all.filter {
      !blocklist.isBlocked(article: $0, blockedKeywords: blockedKeywords, blockedSourceIds: blockedSourceIds)
    }
  }

  func markRead(_ article: Article) throws {
    try articleRepository.markRead(article)
  }

  func toggleSaved(_ article: Article) throws {
    try articleRepository.toggleSaved(article)
  }

  func toggleFavorite(_ article: Article) throws {
    try articleRepository.toggleFavorite(article)
  }
}
