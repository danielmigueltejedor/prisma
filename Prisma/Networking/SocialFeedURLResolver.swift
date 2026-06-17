import Foundation

enum SocialFeedURLResolver {
  private static let rsshubBases = [
    "https://rsshub.rssforever.com",
    "https://rsshub.pseudoyu.com",
    "https://rsshub.app",
  ]

  private static let xCancelBases: [String] = []

  static func candidateURLs(for feedURL: String, platform: FeedPlatform) -> [URL] {
    guard platform == .x else {
      return [URL(string: feedURL)].compactMap { $0 }
    }

    var urls: [URL] = []

    if let username = twitterUsername(from: feedURL) {
      for base in rsshubBases {
        if let url = URL(string: "\(base)/twitter/user/\(username)") { urls.append(url) }
      }
      for base in xCancelBases {
        if let url = URL(string: "\(base)/\(username)/rss") { urls.append(url) }
      }
    }

    if let woeid = twitterTrendsWOEID(from: feedURL) {
      for base in rsshubBases {
        if let url = URL(string: "\(base)/twitter/trends/\(woeid)") { urls.append(url) }
      }
    }

    if let feed = RecommendedFeeds.find(feedURL: feedURL) {
      urls.append(contentsOf: FeedURLCatalog.alternateURLs(for: feed))
    }

    if let original = URL(string: feedURL) {
      urls.append(original)
    }

    var seen = Set<String>()
    return urls.compactMap { url in
      guard seen.insert(url.absoluteString).inserted else { return nil }
      return url
    }
  }

  static func canonicalFeedURL(from catalogURL: String, platform: FeedPlatform) -> String {
    guard platform == .x else { return catalogURL }

    if let feed = RecommendedFeeds.loadFromBundle().first(where: { $0.feedURL == catalogURL }) {
      if let fallback = feed.fallbackFeedURL { return fallback }
      if let alternate = FeedURLCatalog.alternateURLs(for: feed).first {
        return alternate.absoluteString
      }
    }

    if let username = twitterUsername(from: catalogURL) {
      return "https://rsshub.rssforever.com/twitter/user/\(username)"
    }
    if twitterTrendsWOEID(from: catalogURL) != nil {
      return "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en"
    }
    return catalogURL
  }

  private static func twitterUsername(from feedURL: String) -> String? {
    let lower = feedURL.lowercased()
    if lower.contains("/twitter/user/") {
      return lower
        .components(separatedBy: "/twitter/user/")
        .last?
        .components(separatedBy: "/").first?
        .components(separatedBy: "?").first
    }

    if let components = URL(string: feedURL)?.pathComponents {
      let parts = components.filter { $0 != "/" }
      if parts.count >= 2, parts.last?.lowercased() == "rss" {
        return parts[parts.count - 2]
      }
    }
    return nil
  }

  private static func twitterTrendsWOEID(from feedURL: String) -> String? {
    guard feedURL.lowercased().contains("/twitter/trends/") else { return nil }
    return feedURL
      .components(separatedBy: "/twitter/trends/")
      .last?
      .components(separatedBy: "/").first?
      .components(separatedBy: "?").first
  }
}
