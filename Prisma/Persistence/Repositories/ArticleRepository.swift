import Foundation
import SwiftData

@MainActor
final class ArticleRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func fetchAll(limit: Int? = nil) throws -> [Article] {
    var descriptor = FetchDescriptor<Article>(
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    if let limit { descriptor.fetchLimit = limit }
    return try context.fetch(descriptor)
  }

  func fetchUnread() throws -> [Article] {
    let descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { !$0.isRead },
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    return try context.fetch(descriptor)
  }

  func fetchSaved() throws -> [Article] {
    let descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { $0.isSaved },
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    return try context.fetch(descriptor)
  }

  func fetchFavorites() throws -> [Article] {
    let descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { $0.isFavorite },
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    return try context.fetch(descriptor)
  }

  func fetch(for sourceId: UUID) throws -> [Article] {
    let descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { $0.sourceId == sourceId },
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    return try context.fetch(descriptor)
  }

  func find(by id: String) throws -> Article? {
    let descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { $0.id == id }
    )
    return try context.fetch(descriptor).first
  }

  func search(query: String) throws -> [Article] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return try fetchAll() }

    let descriptor = FetchDescriptor<Article>(
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    let all = try context.fetch(descriptor)
    let lower = trimmed.lowercased()
    return all.filter {
      $0.title.lowercased().contains(lower)
        || ($0.summary?.lowercased().contains(lower) ?? false)
        || $0.sourceName.lowercased().contains(lower)
        || ($0.authorName?.lowercased().contains(lower) ?? false)
    }
  }

  func upsert(from parsed: ParsedArticle, source: FeedSource) throws -> Article {
    let articleId = Article.stableID(guid: parsed.guid, link: parsed.link)
    if let existing = try find(by: articleId) {
      existing.title = parsed.title
      existing.summary = parsed.summary
      existing.content = parsed.content ?? existing.content
      existing.authorName = parsed.author ?? existing.authorName
      existing.publishedAt = parsed.publishedAt ?? existing.publishedAt
      existing.updatedAt = parsed.updatedAt ?? existing.updatedAt
      existing.imageUrl = parsed.imageURL ?? existing.imageUrl
      existing.categoryNames = parsed.categories
      existing.contentAvailability = parsed.contentAvailability
      existing.fetchedAt = .now
      try context.save()
      return existing
    }

    let article = Article(
      id: articleId,
      title: parsed.title,
      url: parsed.link,
      sourceName: source.name,
      sourceId: source.id,
      authorName: parsed.author,
      publishedAt: parsed.publishedAt,
      updatedAt: parsed.updatedAt,
      summary: parsed.summary,
      content: parsed.content,
      imageUrl: parsed.imageURL,
      categoryNames: parsed.categories,
      readingTimeEstimate: ReadingTimeEstimator.estimate(
        text: parsed.content ?? parsed.summary ?? parsed.title
      ),
      originalFeedUrl: source.feedURL,
      contentAvailability: parsed.contentAvailability,
      feedSource: source
    )
    context.insert(article)
    try context.save()
    return article
  }

  func markRead(_ article: Article) throws {
    article.viewCount += 1
    article.isRead = true
    if article.readingHistory == nil {
      let history = ReadingHistory(article: article)
      context.insert(history)
      article.readingHistory = history
    } else {
      article.readingHistory?.readAt = .now
    }
    try context.save()
  }

  func toggleSaved(_ article: Article) throws {
    article.isSaved.toggle()
    if article.isSaved {
      if article.savedEntry == nil {
        let saved = SavedArticle(article: article)
        context.insert(saved)
        article.savedEntry = saved
      }
    }
    try context.save()
  }

  func toggleFavorite(_ article: Article) throws {
    article.isFavorite.toggle()
    if article.isFavorite {
      article.likeCount += 1
    } else {
      article.likeCount = max(0, article.likeCount - 1)
    }
    try context.save()
  }
}
