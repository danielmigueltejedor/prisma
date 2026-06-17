import Foundation
import SwiftData

@Model
final class Article {
  @Attribute(.unique) var id: String
  var title: String
  var url: String
  var sourceName: String
  var sourceId: UUID
  var authorName: String?
  var publishedAt: Date?
  var updatedAt: Date?
  var summary: String?
  var plainSummary: String?
  var content: String?
  var imageUrl: String?
  var categoryNames: [String]
  var isRead: Bool
  var isSaved: Bool
  var isFavorite: Bool
  var viewCount: Int
  var likeCount: Int
  var readingTimeEstimate: Int
  var originalFeedUrl: String
  var contentAvailabilityRaw: String
  var fetchedAt: Date

  var feedSource: FeedSource?

  @Relationship(deleteRule: .cascade, inverse: \ReadingHistory.article)
  var readingHistory: ReadingHistory?

  @Relationship(deleteRule: .cascade, inverse: \SavedArticle.article)
  var savedEntry: SavedArticle?

  @Relationship(deleteRule: .nullify)
  var categories: [Category] = []

  var contentAvailability: ContentAvailability {
    get { ContentAvailability(rawValue: contentAvailabilityRaw) ?? .unknown }
    set { contentAvailabilityRaw = newValue.rawValue }
  }

  var resolvedImageURL: URL? {
    guard let imageUrl else { return nil }
    return URL(string: ArticleImageURLResolver.resolve(imageUrl))
  }

  init(
    id: String,
    title: String,
    url: String,
    sourceName: String,
    sourceId: UUID,
    authorName: String? = nil,
    publishedAt: Date? = nil,
    updatedAt: Date? = nil,
    summary: String? = nil,
    plainSummary: String? = nil,
    content: String? = nil,
    imageUrl: String? = nil,
    categoryNames: [String] = [],
    isRead: Bool = false,
    isSaved: Bool = false,
    isFavorite: Bool = false,
    viewCount: Int = 0,
    likeCount: Int = 0,
    readingTimeEstimate: Int = 1,
    originalFeedUrl: String,
    contentAvailability: ContentAvailability = .unknown,
    fetchedAt: Date = .now,
    feedSource: FeedSource? = nil
  ) {
    self.id = id
    self.title = title
    self.url = url
    self.sourceName = sourceName
    self.sourceId = sourceId
    self.authorName = authorName
    self.publishedAt = publishedAt
    self.updatedAt = updatedAt
    self.summary = summary
    self.plainSummary = plainSummary
    self.content = content
    self.imageUrl = imageUrl
    self.categoryNames = categoryNames
    self.isRead = isRead
    self.isSaved = isSaved
    self.isFavorite = isFavorite
    self.viewCount = viewCount
    self.likeCount = likeCount
    self.readingTimeEstimate = readingTimeEstimate
    self.originalFeedUrl = originalFeedUrl
    self.contentAvailabilityRaw = contentAvailability.rawValue
    self.fetchedAt = fetchedAt
    self.feedSource = feedSource
  }

  static func stableID(guid: String?, link: String) -> String {
    let base = (guid?.isEmpty == false ? guid! : link)
    return base.stableHash
  }
}

private extension String {
  var stableHash: String {
    var hash: UInt64 = 5381
    for byte in utf8 {
      hash = ((hash << 5) &+ hash) &+ UInt64(byte)
    }
    return String(hash, radix: 16)
  }
}
