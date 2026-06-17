import Foundation

enum FaviconURLBuilder {
  private static let brandHostAliases: [String: String] = [
    "feeds.elpais.com": "elpais.com",
    "feeds.bbci.co.uk": "bbc.com",
    "feeds.reuters.com": "reuters.com",
    "feeds.npr.org": "npr.org",
    "feeds.arstechnica.com": "arstechnica.com",
    "feeds.as.com": "as.com",
    "newsfeed.zeit.de": "zeit.de",
    "rss.sciam.com": "scientificamerican.com",
    "hnrss.org": "news.ycombinator.com",
    "e00-elmundo.uecdn.es": "elmundo.es",
    "e00-marca.uecdn.es": "marca.com",
    "xml2.corriereobjects.it": "corriere.it",
    "rss.dw.com": "dw.com",
    "rss.uol.com.br": "uol.com.br",
    "feeds.folha.uol.com.br": "folha.uol.com.br",
  ]

  static func url(siteURL: String?, feedURL: String) -> URL? {
    guard let host = preferredHost(siteURL: siteURL, feedURL: feedURL), !host.isEmpty else { return nil }
    var components = URLComponents()
    components.scheme = "https"
    components.host = "www.google.com"
    components.path = "/s2/favicons"
    components.queryItems = [
      URLQueryItem(name: "domain", value: host),
      URLQueryItem(name: "sz", value: "128"),
    ]
    return components.url
  }

  private static func preferredHost(siteURL: String?, feedURL: String) -> String? {
    if let siteHost = host(from: siteURL), !isSocialHost(siteHost) {
      return normalizeBrandHost(siteHost)
    }

    if let feedHost = host(from: feedURL) {
      if let mapped = knownBrandHost(for: feedHost, feedURL: feedURL) {
        return mapped
      }
      if !isSocialHost(feedHost), !isFeedInfrastructureHost(feedHost) {
        return normalizeBrandHost(feedHost)
      }
    }

    if let siteHost = host(from: siteURL) {
      return normalizeBrandHost(siteHost)
    }

    return host(from: feedURL)
  }

  private static func knownBrandHost(for feedHost: String, feedURL: String) -> String? {
    let normalizedFeedHost = feedHost.lowercased()
    if let mapped = brandHostAliases[normalizedFeedHost] {
      return mapped
    }
    return publisherDomain(in: feedURL)
  }

  private static func publisherDomain(in feedURL: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"/site/([A-Za-z0-9.-]+)"#) else { return nil }
    let range = NSRange(feedURL.startIndex..., in: feedURL)
    guard let match = regex.firstMatch(in: feedURL, range: range),
          match.numberOfRanges > 1,
          let domainRange = Range(match.range(at: 1), in: feedURL) else { return nil }
    return normalizeBrandHost(String(feedURL[domainRange]))
  }

  private static func normalizeBrandHost(_ host: String) -> String {
    let lowered = host.lowercased()
    if lowered.hasPrefix("www.") {
      return String(lowered.dropFirst(4))
    }
    return lowered
  }

  private static func host(from urlString: String?) -> String? {
    guard let urlString, let url = URL(string: urlString), let host = url.host else { return nil }
    return host.lowercased()
  }

  private static func isSocialHost(_ host: String) -> Bool {
    let normalized = host.lowercased()
    if normalized == "reddit.com" || normalized.hasSuffix(".reddit.com") { return true }
    if normalized == "twitter.com" || normalized == "x.com"
      || normalized.hasSuffix(".twitter.com") || normalized.hasSuffix(".x.com") {
      return true
    }
    return normalized.contains("rsshub.") || normalized.contains("xcancel.") || normalized.contains("nitter.")
  }

  private static func isFeedInfrastructureHost(_ host: String) -> Bool {
    let normalized = host.lowercased()
    let prefixes = ["feeds.", "rss.", "newsfeed.", "xml.", "api."]
    if prefixes.contains(where: { normalized.hasPrefix($0) }) { return true }
    if normalized.contains("uecdn.es") { return true }
    if normalized.hasSuffix("corriereobjects.it") { return true }
    if normalized == "news.google.com" { return true }
    return false
  }
}
