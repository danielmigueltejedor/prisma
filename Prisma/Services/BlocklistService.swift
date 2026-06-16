import Foundation

struct BlocklistService {
  func isBlocked(article: Article, blockedKeywords: [String], blockedSourceIds: Set<UUID>) -> Bool {
    if blockedSourceIds.contains(article.sourceId) { return true }

    let haystack = [
      article.title,
      article.summary ?? "",
      article.authorName ?? "",
    ].joined(separator: " ").lowercased()

    return blockedKeywords.contains { keyword in
      !keyword.isEmpty && haystack.contains(keyword.lowercased())
    }
  }
}
