import Foundation

struct RedditComment: Identifiable, Equatable {
  let id: String
  let author: String
  let body: String
  let score: Int
  let createdAt: Date?
  let depth: Int
  let replies: [RedditComment]
  var translatedBody: String?

  var displayBody: String {
    translatedBody ?? body
  }

  init(
    id: String,
    author: String,
    body: String,
    score: Int,
    createdAt: Date?,
    depth: Int,
    replies: [RedditComment],
    translatedBody: String? = nil
  ) {
    self.id = id
    self.author = author
    self.body = body
    self.score = score
    self.createdAt = createdAt
    self.depth = depth
    self.replies = replies
    self.translatedBody = translatedBody
  }
}

enum RedditCommentsError: LocalizedError {
  case invalidURL
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .invalidURL: String(localized: "reader.reddit.invalidURL")
    case .invalidResponse: String(localized: "reader.reddit.invalidResponse")
    }
  }
}

enum RedditCommentsParser {
  static func parse(_ data: Data) throws -> [RedditComment] {
    guard let listings = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
          listings.count >= 2,
          let commentListing = listings[1]["data"] as? [String: Any],
          let children = commentListing["children"] as? [[String: Any]]
    else {
      throw RedditCommentsError.invalidResponse
    }

    return children.compactMap { parseCommentNode($0, depth: 0) }
  }

  static func parseTree(_ data: Data) throws -> [RedditComment] {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let children = root["data"] as? [[String: Any]]
    else {
      throw RedditCommentsError.invalidResponse
    }

    return children.compactMap { parseCommentNode($0, depth: 0) }
  }

  private static func parseCommentNode(_ node: [String: Any], depth: Int) -> RedditComment? {
    guard let kind = node["kind"] as? String, kind == "t1",
          let data = node["data"] as? [String: Any],
          let id = data["id"] as? String,
          let author = data["author"] as? String,
          let body = data["body"] as? String
    else { return nil }

    let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard author != "[deleted]", !trimmedBody.isEmpty, trimmedBody != "[removed]" else { return nil }

    let score = data["score"] as? Int ?? 0
    let created = (data["created_utc"] as? Double).map { Date(timeIntervalSince1970: $0) }
    let replies = parseReplies(data["replies"], depth: depth + 1)

    return RedditComment(
      id: id,
      author: author,
      body: trimmedBody,
      score: score,
      createdAt: created,
      depth: depth,
      replies: replies
    )
  }

  private static func parseReplies(_ value: Any?, depth: Int) -> [RedditComment] {
    guard depth < 6 else { return [] }
    if value is String { return [] }
    guard let listing = value as? [String: Any],
          let data = listing["data"] as? [String: Any],
          let children = data["children"] as? [[String: Any]]
    else { return [] }

    return children.compactMap { parseCommentNode($0, depth: depth) }
  }
}
