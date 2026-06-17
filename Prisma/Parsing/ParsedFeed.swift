import Foundation

struct ParsedFeed {
  var title: String?
  var siteURL: String?
  var feedURL: String?
  var articles: [ParsedArticle]
}

struct ParsedArticle {
  var title: String
  var link: String
  var guid: String?
  var author: String?
  var publishedAt: Date?
  var updatedAt: Date?
  var summary: String?
  var content: String?
  var imageURL: String?
  var videoURL: String? = nil
  var categories: [String]
  var contentAvailability: ContentAvailability

  var plainSummary: String? {
    HTMLSanitizer.stripHTML(summary)
  }
}
