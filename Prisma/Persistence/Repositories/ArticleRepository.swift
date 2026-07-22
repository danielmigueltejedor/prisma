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

  func fetch(for sourceId: UUID, limit: Int? = 50) throws -> [Article] {
    var descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { $0.sourceId == sourceId },
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    if let limit { descriptor.fetchLimit = limit }
    return try context.fetch(descriptor)
  }

  func fetch(byAuthor authorName: String, limit: Int = 120) throws -> [Article] {
    let needle = Self.normalizedAuthorKey(authorName)
    guard !needle.isEmpty else { return [] }

    var descriptor = FetchDescriptor<Article>(
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    return try context.fetch(descriptor).filter {
      Self.normalizedAuthorKey($0.authorName ?? "") == needle
    }
  }

  func find(byIDs ids: Set<String>) throws -> [Article] {
    guard !ids.isEmpty else { return [] }
    let idList = Array(ids)
    let descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { idList.contains($0.id) }
    )
    return try context.fetch(descriptor)
  }

  private static func normalizedAuthorKey(_ name: String) -> String {
    var key = name
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    if key.hasPrefix("/u/") {
      key = String(key.dropFirst(1))
    }
    return key
  }

  func find(by id: String) throws -> Article? {
    let descriptor = FetchDescriptor<Article>(
      predicate: #Predicate { $0.id == id }
    )
    return try context.fetch(descriptor).first
  }

  func search(query: String, limit: Int = 200) throws -> [Article] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return try fetchAll(limit: limit) }

    var descriptor = FetchDescriptor<Article>(
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit * 4
    let candidates = try context.fetch(descriptor)
    let lower = trimmed.lowercased()
    return candidates.filter {
      $0.title.lowercased().contains(lower)
        || ($0.summary?.lowercased().contains(lower) ?? false)
        || $0.sourceName.lowercased().contains(lower)
        || ($0.authorName?.lowercased().contains(lower) ?? false)
    }
    .prefix(limit)
    .map { $0 }
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
      let normalizedItem = source.effectivePlatform == .reddit
        ? RedditContentNormalizer.normalizeParsedArticle(item, link: item.link)
        : item
      let articleId = Article.stableID(guid: normalizedItem.guid, link: normalizedItem.link)
      if let existing = existingById[articleId] {
        existing.title = normalizedItem.title
        existing.summary = normalizedItem.summary
        existing.plainSummary = Self.plainSummary(
          from: normalizedItem.summary,
          isReddit: source.effectivePlatform == .reddit
        )
        existing.content = normalizedItem.content ?? existing.content
        existing.authorName = normalizedItem.author ?? existing.authorName
        existing.publishedAt = normalizedItem.publishedAt ?? existing.publishedAt
        existing.updatedAt = normalizedItem.updatedAt ?? existing.updatedAt
        existing.imageUrl = Self.resolvedImageURL(normalizedItem.imageURL) ?? existing.imageUrl
        existing.videoUrl = Self.resolvedVideoURL(normalizedItem.videoURL) ?? existing.videoUrl
        existing.categoryNames = normalizedItem.categories
        existing.contentAvailability = normalizedItem.contentAvailability
        existing.fetchedAt = .now
        results.append(existing)
      } else {
        let article = Article(
          id: articleId,
          title: normalizedItem.title,
          url: normalizedItem.link,
          sourceName: source.name,
          sourceId: source.id,
          authorName: normalizedItem.author,
          publishedAt: normalizedItem.publishedAt,
          updatedAt: normalizedItem.updatedAt,
          summary: normalizedItem.summary,
          plainSummary: Self.plainSummary(
            from: normalizedItem.summary,
            isReddit: source.effectivePlatform == .reddit
          ),
          content: normalizedItem.content,
          imageUrl: Self.resolvedImageURL(normalizedItem.imageURL),
          videoUrl: Self.resolvedVideoURL(normalizedItem.videoURL),
          categoryNames: normalizedItem.categories,
          readingTimeEstimate: ReadingTimeEstimator.estimate(
            text: normalizedItem.content ?? normalizedItem.summary ?? normalizedItem.title
          ),
          originalFeedUrl: source.feedURL,
          contentAvailability: normalizedItem.contentAvailability,
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

  private static func resolvedVideoURL(_ raw: String?) -> String? {
    guard let raw else { return nil }
    return ArticleMediaExtractor.resolvePlayableVideoURL(raw)?.absoluteString
  }

  private static func plainSummary(from html: String?, isReddit: Bool = false) -> String? {
    guard let html else { return nil }
    var text = HTMLSanitizer.stripHTML(html) ?? ""
    if isReddit {
      text = RedditContentNormalizer.cleanPlainText(text)
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  func save() throws {
    try context.save()
  }

  func delete(_ article: Article) throws {
    context.delete(article)
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

  func markReadAndRecordDwell(_ article: Article, seconds: TimeInterval) throws {
    article.viewCount += 1
    article.isRead = true
    if article.readingHistory == nil {
      let history = ReadingHistory(
        totalDwellSeconds: seconds >= 3 ? seconds : 0,
        article: article
      )
      context.insert(history)
      article.readingHistory = history
    } else {
      if seconds >= 3 {
        article.readingHistory?.totalDwellSeconds += seconds
      }
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
