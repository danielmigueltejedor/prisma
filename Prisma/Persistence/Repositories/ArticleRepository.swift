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

  func fetch(byAuthor authorName: String) throws -> [Article] {
    let needle = Self.normalizedAuthorKey(authorName)
    guard !needle.isEmpty else { return [] }

    let descriptor = FetchDescriptor<Article>(
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    return try context.fetch(descriptor).filter {
      Self.normalizedAuthorKey($0.authorName ?? "") == needle
    }
  }

  private static func normalizedAuthorKey(_ name: String) -> String {
    name
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
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

  func upsert(from parsed: ParsedArticle, source: FeedSource, save: Bool = true) throws -> Article {
    try upsertBatch(from: [parsed], source: source, save: save).first!
  }

  @discardableResult
  func upsertBatch(
    from parsedArticles: [ParsedArticle],
    source: FeedSource,
    save: Bool = true
  ) throws -> [Article] {
    guard !parsedArticles.isEmpty else { return [] }

    let integrated = LiveFeedIntegrator.integrate(parsedArticles, source: source)
    let targetIds = integrated.map { Article.stableID(guid: $0.guid, link: $0.link) }
    let existingForSource = try fetchExisting(sourceId: source.id, articleIds: targetIds)
    var existingById = Dictionary(uniqueKeysWithValues: existingForSource.map { ($0.id, $0) })
    var results: [Article] = []
    results.reserveCapacity(parsedArticles.count)

    for item in integrated {
      let articleId = Article.stableID(guid: item.guid, link: item.link)
      if let existing = existingById[articleId] {
        existing.title = item.title
        existing.summary = item.summary
        existing.plainSummary = Self.plainSummary(from: item.summary)
        existing.content = item.content ?? existing.content
        existing.authorName = item.author ?? existing.authorName
        existing.publishedAt = item.publishedAt ?? existing.publishedAt
        existing.updatedAt = item.updatedAt ?? existing.updatedAt
        existing.imageUrl = Self.resolvedImageURL(item.imageURL) ?? existing.imageUrl
        existing.categoryNames = item.categories
        existing.contentAvailability = item.contentAvailability
        existing.fetchedAt = .now
        results.append(existing)
      } else {
        let article = Article(
          id: articleId,
          title: item.title,
          url: item.link,
          sourceName: source.name,
          sourceId: source.id,
          authorName: item.author,
          publishedAt: item.publishedAt,
          updatedAt: item.updatedAt,
          summary: item.summary,
          plainSummary: Self.plainSummary(from: item.summary),
          content: item.content,
          imageUrl: Self.resolvedImageURL(item.imageURL),
          categoryNames: item.categories,
          readingTimeEstimate: ReadingTimeEstimator.estimate(
            text: item.content ?? item.summary ?? item.title
          ),
          originalFeedUrl: source.feedURL,
          contentAvailability: item.contentAvailability,
          feedSource: source
        )
        context.insert(article)
        existingById[articleId] = article
        results.append(article)
      }
    }

    if save { try context.save() }
    return results
  }

  private func fetchExisting(sourceId: UUID, articleIds: [String]) throws -> [Article] {
    guard !articleIds.isEmpty else { return [] }
    let descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { article in
        article.sourceId == sourceId && articleIds.contains(article.id)
      }
    )
    return try context.fetch(descriptor)
  }

  private static func resolvedImageURL(_ raw: String?) -> String? {
    guard let raw else { return nil }
    return ArticleImageURLResolver.resolve(raw)
  }

  private static func plainSummary(from html: String?) -> String? {
    guard let html else { return nil }
    let text = HTMLSanitizer.stripHTML(html) ?? ""
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  func save() throws {
    try context.save()
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

  func recordDwellTime(_ article: Article, seconds: TimeInterval) throws {
    guard seconds >= 3 else { return }
    if article.readingHistory == nil {
      let history = ReadingHistory(totalDwellSeconds: seconds, article: article)
      context.insert(history)
      article.readingHistory = history
    } else {
      article.readingHistory?.totalDwellSeconds += seconds
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
    } else if let savedEntry = article.savedEntry {
      context.delete(savedEntry)
      article.savedEntry = nil
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
