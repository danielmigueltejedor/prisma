import Foundation

@MainActor
final class RedditCommentsService {
  private static let mirrorBaseURL = "https://arctic-shift.photon-reddit.com/api/comments/tree"

  private let networkClient: NetworkClient
  private let oauthClient: RedditOAuthClient?
  private var cache: [String: [RedditComment]] = [:]

  init(networkClient: NetworkClient) {
    self.networkClient = networkClient
    if let clientID = AppConfiguration.redditClientID, !clientID.isEmpty {
      oauthClient = RedditOAuthClient(clientID: clientID)
    } else {
      oauthClient = nil
    }
  }

  func fetchComments(for article: Article) async throws -> [RedditComment] {
    guard let postID = Self.postID(from: article.url) else {
      throw RedditCommentsError.invalidURL
    }
    if let cached = cache[postID] {
      return cached
    }

    let comments: [RedditComment]
    if let oauthClient {
      do {
        comments = try await fetchFromRedditAPI(postID: postID, oauthClient: oauthClient)
      } catch {
        comments = try await fetchFromMirror(postID: postID)
      }
    } else {
      comments = try await fetchFromMirror(postID: postID)
    }

    cache[postID] = comments
    return comments
  }

  private func fetchFromRedditAPI(postID: String, oauthClient: RedditOAuthClient) async throws -> [RedditComment] {
    let urlString = "https://oauth.reddit.com/comments/\(postID).json?limit=40&depth=4&raw_json=1&sort=confidence"
    guard let url = URL(string: urlString) else {
      throw NetworkError.invalidURL
    }

    let request = try await oauthClient.authorizedRequest(url: url)
    let (data, response) = try await networkClient.session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw NetworkError.invalidResponse
    }
    guard (200 ... 299).contains(http.statusCode) else {
      throw NetworkError.httpStatus(http.statusCode)
    }
    return try RedditCommentsParser.parse(data)
  }

  private func fetchFromMirror(postID: String) async throws -> [RedditComment] {
    let urlString = "\(Self.mirrorBaseURL)?link_id=t3_\(postID)&limit=200&start_depth=4&start_breadth=4"
    let data = try await networkClient.fetchData(from: urlString, platform: .reddit)
    return try RedditCommentsParser.parseTree(data)
  }

  static func postID(from urlString: String) -> String? {
    let decoded = (urlString.removingPercentEncoding ?? urlString)
      .replacingOccurrences(of: "&amp;", with: "&")
    guard let regex = try? NSRegularExpression(
      pattern: #"comments/([a-z0-9]+)"#,
      options: .caseInsensitive
    ) else { return nil }

    let range = NSRange(decoded.startIndex..., in: decoded)
    guard let match = regex.firstMatch(in: decoded, range: range),
          match.numberOfRanges > 1,
          let idRange = Range(match.range(at: 1), in: decoded)
    else { return nil }

    return String(decoded[idRange])
  }
}
