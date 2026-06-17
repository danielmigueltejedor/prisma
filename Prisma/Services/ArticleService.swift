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

  func recordDwellTime(_ article: Article, seconds: TimeInterval) throws {
    try articleRepository.recordDwellTime(article, seconds: seconds)
    ArticleLibraryNotifier.publish()
  }

  func toggleSaved(_ article: Article) throws {
    try articleRepository.toggleSaved(article)
    ArticleLibraryNotifier.publish()
  }

  func toggleFavorite(_ article: Article) throws {
    try articleRepository.toggleFavorite(article)
    ArticleLibraryNotifier.publish()
  }
}
