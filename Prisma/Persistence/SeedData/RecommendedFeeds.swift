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

  var feedScope: FeedScope {
    FeedScope(rawValue: scope) ?? .local
  }

  var isInternational: Bool { feedScope == .international }
}

enum RecommendedFeeds {
  static func loadFromBundle() -> [RecommendedFeed] {
    guard let url = Bundle.main.url(forResource: "RecommendedFeeds", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let feeds = try? JSONDecoder().decode([RecommendedFeed].self, from: data)
    else {
      return bundled
    }
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

  static func forHomeCountry(_ code: String) -> [RecommendedFeed] {
    local(for: code) + international()
  }

  static func find(id: String) -> RecommendedFeed? {
    loadFromBundle().first { $0.id == id }
  }

  static func find(feedURL: String) -> RecommendedFeed? {
    loadFromBundle().first { $0.feedURL == feedURL }
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
