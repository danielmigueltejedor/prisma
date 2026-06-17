import Foundation

struct RecommendedFeed: Codable, Identifiable {
  let id: String
  let name: String
  let feedURL: String
  let siteURL: String?
  let category: String
  let language: String
  let countryCode: String
  let scope: String
  let description: String?
  let platform: String?
  let fallbackFeedURL: String?

  enum CodingKeys: String, CodingKey {
    case id, name, feedURL, siteURL, category, language, countryCode, scope, description, platform, fallbackFeedURL
  }

  init(
    id: String,
    name: String,
    feedURL: String,
    siteURL: String?,
    category: String,
    language: String,
    countryCode: String,
    scope: String,
    description: String? = nil,
    platform: String? = nil,
    fallbackFeedURL: String? = nil
  ) {
    self.id = id
    self.name = name
    self.feedURL = feedURL
    self.siteURL = siteURL
    self.category = category
    self.language = language
    self.countryCode = countryCode
    self.scope = scope
    self.description = description
    self.platform = platform
    self.fallbackFeedURL = fallbackFeedURL
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    feedURL = try container.decode(String.self, forKey: .feedURL)
    siteURL = try container.decodeIfPresent(String.self, forKey: .siteURL)
    category = try container.decode(String.self, forKey: .category)
    language = try container.decode(String.self, forKey: .language)
    countryCode = try container.decode(String.self, forKey: .countryCode)
    scope = try container.decode(String.self, forKey: .scope)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    platform = try container.decodeIfPresent(String.self, forKey: .platform)
    fallbackFeedURL = try container.decodeIfPresent(String.self, forKey: .fallbackFeedURL)
  }

  var feedScope: FeedScope {
    FeedScope(rawValue: scope) ?? .local
  }

  var feedPlatform: FeedPlatform {
    if let platform, let parsed = FeedPlatform(rawValue: platform) { return parsed }
    return .news
  }

  var isInternational: Bool { feedScope == .international }
}

enum RecommendedFeeds {
  private static var cachedFeeds: [RecommendedFeed]?

  static func loadFromBundle() -> [RecommendedFeed] {
    if let cachedFeeds { return cachedFeeds }
    guard let url = Bundle.main.url(forResource: "RecommendedFeeds", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let feeds = try? JSONDecoder().decode([RecommendedFeed].self, from: data)
    else {
      cachedFeeds = bundled
      return bundled
    }
    cachedFeeds = feeds
    return feeds
  }

  static func local(for countryCode: String) -> [RecommendedFeed] {
    loadFromBundle().filter {
      $0.countryCode.uppercased() == countryCode.uppercased() && !$0.isInternational
    }
  }

  static func international() -> [RecommendedFeed] {
    loadFromBundle().filter(\.isInternational)
  }

  static func other(excluding homeCountryCode: String) -> [RecommendedFeed] {
    loadFromBundle().filter {
      !$0.isInternational && $0.countryCode.uppercased() != homeCountryCode.uppercased()
    }
  }

  static func social() -> [RecommendedFeed] {
    loadFromBundle().filter { $0.feedPlatform == .x }
  }

  static func reddit() -> [RecommendedFeed] {
    loadFromBundle().filter { $0.feedPlatform == .reddit }
  }

  static func forHomeCountry(_ code: String) -> [RecommendedFeed] {
    local(for: code) + international()
  }

  static func find(id: String) -> RecommendedFeed? {
    loadFromBundle().first { $0.id == id }
  }

  static func find(feedURL: String) -> RecommendedFeed? {
    loadFromBundle().first { feed in
      feed.feedURL == feedURL
        || SocialFeedURLResolver.canonicalFeedURL(from: feed.feedURL, platform: feed.feedPlatform) == feedURL
    }
  }

  static func matching(_ source: FeedSource) -> RecommendedFeed? {
    let catalog = loadFromBundle()

    if let exact = catalog.first(where: { $0.feedURL == source.feedURL }) {
      return exact
    }

    let resolvedMatches = catalog.filter { feed in
      source.feedURL == SocialFeedURLResolver.canonicalFeedURL(from: feed.feedURL, platform: feed.feedPlatform)
        || source.feedURL == feed.fallbackFeedURL
    }
    if resolvedMatches.count == 1 { return resolvedMatches.first }
    if resolvedMatches.count > 1 {
      if let siteURL = source.siteURL,
         let bySite = resolvedMatches.first(where: { $0.siteURL == siteURL }) {
        return bySite
      }
      return resolvedMatches.first { $0.feedPlatform == .x || $0.feedPlatform == .reddit }
        ?? resolvedMatches.first
    }

    if let siteURL = source.siteURL {
      return catalog.first { $0.siteURL == siteURL && $0.feedPlatform == .news }
    }
    return nil
  }

  // Fallback mínimo si falta el JSON
  static let bundled: [RecommendedFeed] = [
    RecommendedFeed(
      id: "el-pais", name: "El País",
      feedURL: "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada",
      siteURL: "https://elpais.com", category: "General", language: "es",
      countryCode: "ES", scope: "local"
    ),
    RecommendedFeed(
      id: "bbc-world", name: "BBC World",
      feedURL: "https://feeds.bbci.co.uk/news/world/rss.xml",
      siteURL: "https://www.bbc.com/news/world", category: "Internacional", language: "en",
      countryCode: "INT", scope: "international"
    ),
  ]
}
