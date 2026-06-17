import Foundation

enum FeedPlatform: String, Codable, CaseIterable, Identifiable {
  case news
  case reddit
  case x

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .news: String(localized: "platform.news")
    case .reddit: String(localized: "platform.reddit")
    case .x: String(localized: "platform.x")
    }
  }

  var systemImage: String {
    switch self {
    case .news: "newspaper.fill"
    case .reddit: "bubble.left.and.bubble.right.fill"
    case .x: "at"
    }
  }

  static func detect(feedURL: String, siteURL: String? = nil) -> FeedPlatform {
    if let fromFeed = platform(fromFeedURL: feedURL) { return fromFeed }
    // Un feed HTTP de un medio editorial es noticia aunque el siteURL sea un perfil social.
    if URL(string: feedURL)?.host != nil { return .news }
    if let siteURL, let fromSite = platform(fromSiteURL: siteURL) { return fromSite }
    return .news
  }

  /// Plataforma efectiva de una fuente: respeta X/Reddit del catálogo aunque el feed activo
  /// sea un fallback editorial (p. ej. Google News cuando xcancel falla).
  static func resolve(for source: FeedSource) -> FeedPlatform {
    if let catalog = RecommendedFeeds.matching(source) {
      return catalog.feedPlatform
    }
    let detected = detect(feedURL: source.feedURL, siteURL: source.siteURL)
    if (source.platform == .x || source.platform == .reddit), detected == .news {
      return source.platform
    }
    return detected
  }

  private static func platform(fromFeedURL feedURL: String) -> FeedPlatform? {
    let lower = feedURL.lowercased()
    if lower.contains("reddit.com") { return .reddit }
    if lower.contains("/twitter/user/")
      || lower.contains("/twitter/trends/")
      || lower.contains("nitter.")
      || lower.contains("xcancel.")
      || lower.contains("rsshub.") {
      return .x
    }
    guard let host = URL(string: feedURL)?.host?.lowercased() else { return nil }
    if host == "reddit.com" || host.hasSuffix(".reddit.com") { return .reddit }
    if host == "twitter.com" || host == "x.com"
      || host.hasSuffix(".twitter.com") || host.hasSuffix(".x.com") {
      return .x
    }
    return nil
  }

  private static func platform(fromSiteURL siteURL: String) -> FeedPlatform? {
    guard let host = URL(string: siteURL)?.host?.lowercased() else { return nil }
    if host == "reddit.com" || host.hasSuffix(".reddit.com") { return .reddit }
    if host == "twitter.com" || host == "x.com"
      || host.hasSuffix(".twitter.com") || host.hasSuffix(".x.com") {
      return .x
    }
    return nil
  }
}
