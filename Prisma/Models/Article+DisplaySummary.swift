import Foundation

extension Article {
  var displaySummary: String? {
    if let plainSummary, !plainSummary.isEmpty { return plainSummary }
    guard let summary else { return nil }
    var text = HTMLSanitizer.stripHTML(summary) ?? ""
    if FeedPlatform.detect(feedURL: originalFeedUrl) == .reddit {
      text = RedditContentNormalizer.cleanPlainText(text)
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  var displayAuthorName: String? {
    ArticleAuthorDisplay.displayName(for: self)
  }
}
