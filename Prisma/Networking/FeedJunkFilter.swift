import Foundation

enum FeedJunkFilter {
  private static let blockedTitleFragments = [
    "not yet whitelist",
    "rss reader not yet",
  ]

  static func isBlockedPlaceholderFeed(_ feed: ParsedFeed) -> Bool {
    guard !feed.articles.isEmpty else { return false }
    return feed.articles.allSatisfy(isBlockedPlaceholderArticle)
  }

  static func isBlockedPlaceholderArticle(_ article: ParsedArticle) -> Bool {
    let blob = [
      article.title,
      article.summary ?? "",
      article.link,
    ].joined(separator: " ").lowercased()

    return blockedTitleFragments.contains { blob.contains($0) }
  }

  static func usableArticles(from feed: ParsedFeed) -> [ParsedArticle] {
    feed.articles.filter { !isBlockedPlaceholderArticle($0) }
  }

  static func looksLikeBlockedPlaceholderPayload(_ data: Data) -> Bool {
    guard let text = String(data: data, encoding: .utf8)?.lowercased() else { return false }
    return blockedTitleFragments.contains { text.contains($0) }
  }
}
