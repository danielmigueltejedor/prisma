import Foundation

@MainActor
final class LocalReadingCorpusService {
  private static let maxBodyCharacters = 6_000

  private let repository: LocalCorpusRepository
  private let preferenceRepository: PreferenceRepository

  init(repository: LocalCorpusRepository, preferenceRepository: PreferenceRepository) {
    self.repository = repository
    self.preferenceRepository = preferenceRepository
  }

  var limitBytes: Int {
    let mb = (try? preferenceRepository.getOrCreate().localCorpusLimitMB) ?? UserPreference.defaultLocalCorpusLimitMB
    guard mb > 0 else { return 0 }
    return mb * 1_024 * 1_024
  }

  func indexArticleIfNeeded(_ article: Article) {
    guard limitBytes > 0 else { return }
    Task(priority: .utility) { @MainActor in
      await indexArticle(article)
    }
  }

  func indexArticle(_ article: Article) async {
    guard limitBytes > 0 else { return }

    let body = Self.plainBody(for: article)
    guard !body.isEmpty else { return }

    let authorKey = ArticleAuthorDisplay.displayName(for: article)
      .map(Self.normalizedAuthorKey)
    let byteSize = body.utf8.count + article.title.utf8.count

    do {
      if let existing = try repository.find(articleId: article.id) {
        existing.title = article.title
        existing.bodyText = body
        existing.byteSize = byteSize
        existing.authorKey = authorKey
        existing.sourceName = article.sourceName
        existing.lastAccessedAt = .now
        try repository.update(existing)
      } else {
        let entry = LocalCorpusEntry(
          articleId: article.id,
          authorKey: authorKey,
          sourceId: article.sourceId,
          sourceName: article.sourceName,
          title: article.title,
          bodyText: body,
          byteSize: byteSize
        )
        try repository.save(entry)
      }
      try enforceStorageLimit()
    } catch {
      return
    }
  }

  func articlesForAuthor(_ authorName: String, limit: Int = 40) -> [LocalCorpusEntry] {
    let key = Self.normalizedAuthorKey(authorName)
    return (try? repository.fetchByAuthor(key, limit: limit)) ?? []
  }

  func contextSnapshotForAI(maxBytes: Int = 48_000) -> String {
    guard limitBytes > 0 else { return "" }
    guard let sorted = try? repository.fetchRecent(limit: 120) else { return "" }
    var used = 0
    var chunks: [String] = []
    for entry in sorted {
      let snippet = "\(entry.title)\n\(entry.bodyText.prefix(900))"
      let size = snippet.utf8.count
      guard used + size <= maxBytes else { break }
      used += size
      chunks.append(snippet)
    }
    return chunks.joined(separator: "\n\n---\n\n")
  }

  private func enforceStorageLimit() throws {
    var total = try repository.totalByteSize()
    guard total > limitBytes else { return }

    var batch = try repository.fetchOldestEntries(limit: 12)
    while total > limitBytes, !batch.isEmpty {
      for entry in batch {
        try repository.delete(entry)
        total -= entry.byteSize
        guard total > limitBytes else { break }
      }
      batch = try repository.fetchOldestEntries(limit: 12)
    }
  }

  private static func plainBody(for article: Article) -> String {
    let html = article.content ?? article.summary
    guard let html else { return "" }
    var plain = HTMLSanitizer.stripHTML(html) ?? ""
    if FeedPlatform.detect(feedURL: article.originalFeedUrl) == .reddit {
      plain = RedditContentNormalizer.cleanPlainText(plain)
    }
    let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(trimmed.prefix(maxBodyCharacters))
  }

  private static func normalizedAuthorKey(_ name: String) -> String {
    name
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .replacingOccurrences(of: "/u/", with: "u/")
  }
}
