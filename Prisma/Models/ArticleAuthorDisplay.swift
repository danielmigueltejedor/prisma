import Foundation

enum ArticleAuthorDisplay {
  static func displayName(
    authorName: String?,
    sourceName: String,
    feedURL: String? = nil,
    siteURL: String? = nil
  ) -> String? {
    guard var name = authorName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
      return nil
    }

    let isReddit = FeedPlatform.detect(feedURL: feedURL ?? "", siteURL: siteURL) == .reddit
    if isReddit {
      name = RedditContentNormalizer.normalizeAuthor(name) ?? name
    }

    guard isMeaningfulAuthor(name, sourceName: sourceName) else { return nil }
    return name
  }

  static func displayName(for article: Article) -> String? {
    displayName(
      authorName: article.authorName,
      sourceName: article.sourceName,
      feedURL: article.originalFeedUrl,
      siteURL: article.feedSource?.siteURL
    )
  }

  private static func isMeaningfulAuthor(_ name: String, sourceName: String) -> Bool {
    let lowered = name.lowercased()
    let source = sourceName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    if lowered == source { return false }
    if lowered == "(\(source))" { return false }

    if lowered.hasPrefix("("), lowered.hasSuffix(")"), lowered.count <= 14 {
      return false
    }

    if name.hasSuffix("-"), name.count <= 6 { return false }

    let letters = name.filter(\.isLetter)
    if letters.count < 2 { return false }

    if source.count >= 2, lowered.contains(source), letters.count <= source.count + 2 {
      return false
    }

    return true
  }
}
