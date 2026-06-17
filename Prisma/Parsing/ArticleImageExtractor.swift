import Foundation

enum ArticleImageExtractor {
  private static let imageSrcPattern = #"<img[^>]+src\s*=\s*["']([^"']+)["']"#

  static func imageURLs(for article: Article) -> [URL] {
    var candidates: [String] = []
    if let imageUrl = article.imageUrl {
      candidates.append(imageUrl)
    }
    for html in [article.content, article.summary] {
      guard let html else { continue }
      candidates.append(contentsOf: extractImageSources(from: html))
    }
    return deduplicatedURLs(from: candidates)
  }

  static func extractImageSources(from html: String) -> [String] {
    guard let regex = try? NSRegularExpression(
      pattern: imageSrcPattern,
      options: [.caseInsensitive]
    ) else { return [] }

    let range = NSRange(html.startIndex..., in: html)
    return regex.matches(in: html, range: range).compactMap { match in
      guard match.numberOfRanges > 1,
            let srcRange = Range(match.range(at: 1), in: html) else { return nil }
      return String(html[srcRange])
    }
  }

  private static func deduplicatedURLs(from candidates: [String]) -> [URL] {
    var seen = Set<String>()
    var urls: [URL] = []

    for candidate in candidates {
      let normalized = normalize(candidate)
      guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
      guard isDisplayableImageURL(normalized) else { continue }
      let resolved = ArticleImageURLResolver.resolve(normalized)
      guard let url = URL(string: resolved) else { continue }
      seen.insert(normalized)
      seen.insert(resolved)
      urls.append(url)
    }
    return urls
  }

  private static func normalize(_ raw: String) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    value = value.replacingOccurrences(of: "&amp;", with: "&")
    if value.hasPrefix("//") {
      value = "https:\(value)"
    }
    return value
  }

  private static func isDisplayableImageURL(_ urlString: String) -> Bool {
    let lower = urlString.lowercased()
    guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return false }

    let blockedFragments = [
      "redditstatic.com",
      "emoji.redditmedia.com",
      "styles.redditmedia.com",
      "snoovatar",
      "avatar_default",
      "pixel.",
      "spacer.gif",
      "1x1",
      "tracking",
    ]
    if blockedFragments.contains(where: { lower.contains($0) }) { return false }

    let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]
    if imageExtensions.contains(where: { lower.contains($0) }) { return true }

    let imageHosts = [
      "i.redd.it",
      "preview.redd.it",
      "external-preview.redd.it",
      "i.imgur.com",
      "imgur.com",
      "pbs.twimg.com",
    ]
    return imageHosts.contains(where: { lower.contains($0) })
  }
}

enum ArticleImageURLResolver {
  static func resolve(_ raw: String) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return raw }
    value = value.replacingOccurrences(of: "&amp;", with: "&")
    if value.hasPrefix("//") {
      value = "https:\(value)"
    }

    value = upgradeReddit(value)
    value = upgradeTwitter(value)
    value = upgradeWordPressSizedPath(value)
    value = stripDownscalingQueryParameters(from: value)
    return value
  }

  static func resolve(_ url: URL) -> URL {
    URL(string: resolve(url.absoluteString)) ?? url
  }

  private static func upgradeReddit(_ url: String) -> String {
    var value = url
    let lower = value.lowercased()
    if lower.contains("preview.redd.it") || lower.contains("external-preview.redd.it") {
      value = value
        .replacingOccurrences(of: "https://preview.redd.it/", with: "https://i.redd.it/", options: .caseInsensitive)
        .replacingOccurrences(of: "http://preview.redd.it/", with: "https://i.redd.it/", options: .caseInsensitive)
        .replacingOccurrences(of: "https://external-preview.redd.it/", with: "https://i.redd.it/", options: .caseInsensitive)
        .replacingOccurrences(of: "http://external-preview.redd.it/", with: "https://i.redd.it/", options: .caseInsensitive)
    }
    if lower.contains("i.redd.it"), var components = URLComponents(string: value) {
      components.query = nil
      components.fragment = nil
      if let cleaned = components.url?.absoluteString {
        value = cleaned
      }
    }
    return value
  }

  private static func upgradeTwitter(_ url: String) -> String {
    guard url.lowercased().contains("pbs.twimg.com") else { return url }
    guard var components = URLComponents(string: url) else { return url }

    var items = components.queryItems ?? []
    if let index = items.firstIndex(where: { $0.name == "name" }) {
      let current = items[index].value?.lowercased() ?? ""
      if ["small", "thumb", "medium", "240x240", "360x360", "480x480", "680x680"].contains(current) {
        items[index] = URLQueryItem(name: "name", value: "large")
      }
    } else {
      items.append(URLQueryItem(name: "name", value: "large"))
    }
    components.queryItems = items
    return components.url?.absoluteString ?? url
  }

  private static func upgradeWordPressSizedPath(_ url: String) -> String {
    guard let regex = try? NSRegularExpression(
      pattern: #"-\d+x\d+(?=\.(?:jpe?g|png|gif|webp|avif)(?:\?|$))"#,
      options: .caseInsensitive
    ) else { return url }

    let range = NSRange(url.startIndex..., in: url)
    return regex.stringByReplacingMatches(in: url, range: range, withTemplate: "")
  }

  private static func stripDownscalingQueryParameters(from url: String) -> String {
    guard var components = URLComponents(string: url) else { return url }
    guard var items = components.queryItems, !items.isEmpty else { return url }

    let blockedKeys: Set<String> = [
      "w", "h", "width", "height", "resize", "crop", "fit", "quality", "auto", "format",
      "ixlib", "ixid", "s", "sz", "maxwidth", "maxheight"
    ]

    items.removeAll { item in
      let key = item.name.lowercased()
      if blockedKeys.contains(key) { return true }
      if key == "w" || key == "width", let value = item.value, let width = Int(value), width < 1200 {
        return true
      }
      return false
    }

    if url.lowercased().contains("wp.com") || url.lowercased().contains("wordpress") {
      items.append(URLQueryItem(name: "w", value: "2000"))
    }

    components.queryItems = items.isEmpty ? nil : items
    return components.url?.absoluteString ?? url
  }
}
