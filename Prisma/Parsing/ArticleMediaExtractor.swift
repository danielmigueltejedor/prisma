import Foundation

enum ArticleMediaExtractor {
  private static let videoSrcPattern = #"<(?:video|source)[^>]+src\s*=\s*["']([^"']+)["']"#
  private static let iframeSrcPattern = #"<iframe[^>]+src\s*=\s*["']([^"']+)["']"#
  private static let videoPosterPattern = #"<video[^>]+poster\s*=\s*["']([^"']+)["']"#

  static func mediaItems(for article: Article) -> [ArticleMediaItem] {
    var items: [ArticleMediaItem] = []
    var seen = Set<String>()

    if let videoUrl = article.videoUrl {
      appendVideo(videoUrl, thumbnail: article.resolvedImageURL, to: &items, seen: &seen)
    }

    for html in [article.content, article.summary] {
      guard let html else { continue }
      for candidate in extractVideoCandidates(from: html) {
        appendVideo(candidate.url, thumbnail: candidate.thumbnail, to: &items, seen: &seen)
      }
    }

    for url in ArticleImageExtractor.imageURLs(for: article) {
      let key = url.absoluteString
      guard !seen.contains(key) else { continue }
      seen.insert(key)
      items.append(.image(url))
    }

    return items
  }

  private struct VideoCandidate {
    var url: String
    var thumbnail: URL?
  }

  private static func extractVideoCandidates(from html: String) -> [VideoCandidate] {
    var results: [VideoCandidate] = []
    let poster = extractFirstMatch(pattern: videoPosterPattern, in: html)
      .flatMap { URL(string: ArticleImageURLResolver.resolve($0)) }

    for pattern in [videoSrcPattern, iframeSrcPattern] {
      for raw in extractMatches(pattern: pattern, in: html) {
        results.append(VideoCandidate(url: raw, thumbnail: poster))
      }
    }
    return results
  }

  private static func appendVideo(
    _ raw: String,
    thumbnail: URL?,
    to items: inout [ArticleMediaItem],
    seen: inout Set<String>
  ) {
    guard let url = resolvePlayableVideoURL(raw) else { return }
    let key = url.absoluteString
    guard !seen.contains(key) else { return }
    seen.insert(key)
    if let thumbnail {
      seen.insert(thumbnail.absoluteString)
    }
    items.append(.video(url, thumbnail: thumbnail))
  }

  static func resolvePlayableVideoURL(_ raw: String) -> URL? {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    value = value.replacingOccurrences(of: "&amp;", with: "&")
    if value.hasPrefix("//") {
      value = "https:\(value)"
    }
    guard let components = URLComponents(string: value),
          let host = components.host?.lowercased() else { return nil }

    if isEmbeddableHost(host), let embed = embedURL(from: components) {
      return embed
    }

    if isDirectVideoURL(value) {
      return URL(string: ArticleImageURLResolver.resolve(value))
    }

    return nil
  }

  static func isEmbeddableHost(_ host: String) -> Bool {
    host.contains("youtube.com")
      || host.contains("youtu.be")
      || host.contains("vimeo.com")
      || host.contains("dailymotion.com")
  }

  static func isDirectVideoURL(_ urlString: String) -> Bool {
    let lower = urlString.lowercased()
    guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return false }

    let extensions = [".mp4", ".m4v", ".mov", ".webm", ".m3u8", ".mpd"]
    if extensions.contains(where: { lower.contains($0) }) { return true }

    let videoHosts = [
      "video.twimg.com",
      "vod-progressive",
      "blob:",
      "stream",
    ]
    if videoHosts.contains(where: { lower.contains($0) }) { return true }

    if lower.contains("mime=video") || lower.contains("type=video") { return true }
    return false
  }

  static func embedURL(from components: URLComponents) -> URL? {
    guard let host = components.host?.lowercased() else { return nil }

    if host.contains("youtube.com") || host.contains("youtu.be") {
      if let id = youtubeVideoID(from: components) {
        return URL(string: "https://www.youtube.com/embed/\(id)?playsinline=1")
      }
    }

    if host.contains("vimeo.com") {
      if let id = vimeoVideoID(from: components) {
        return URL(string: "https://player.vimeo.com/video/\(id)?playsinline=1")
      }
    }

    if host.contains("dailymotion.com") {
      if let id = dailymotionVideoID(from: components) {
        return URL(string: "https://www.dailymotion.com/embed/video/\(id)")
      }
    }

    if components.path.contains("/embed/") {
      return components.url
    }

    return nil
  }

  private static func youtubeVideoID(from components: URLComponents) -> String? {
    if components.host?.contains("youtu.be") == true {
      let id = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return id.isEmpty ? nil : id
    }
    if components.path.contains("/embed/") {
      return components.path.split(separator: "/").last.map(String.init)
    }
    return components.queryItems?.first(where: { $0.name == "v" })?.value
  }

  private static func vimeoVideoID(from components: URLComponents) -> String? {
    let parts = components.path.split(separator: "/").map(String.init)
    if let videoIndex = parts.firstIndex(of: "video"), parts.indices.contains(videoIndex + 1) {
      return parts[videoIndex + 1]
    }
    return parts.last
  }

  private static func dailymotionVideoID(from components: URLComponents) -> String? {
    let parts = components.path.split(separator: "/").map(String.init)
    if let videoIndex = parts.firstIndex(of: "video"), parts.indices.contains(videoIndex + 1) {
      return parts[videoIndex + 1]
    }
    return parts.last
  }

  private static func extractMatches(pattern: String, in html: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
    let range = NSRange(html.startIndex..., in: html)
    return regex.matches(in: html, range: range).compactMap { match in
      guard match.numberOfRanges > 1,
            let srcRange = Range(match.range(at: 1), in: html) else { return nil }
      return String(html[srcRange])
    }
  }

  private static func extractFirstMatch(pattern: String, in html: String) -> String? {
    extractMatches(pattern: pattern, in: html).first
  }
}
