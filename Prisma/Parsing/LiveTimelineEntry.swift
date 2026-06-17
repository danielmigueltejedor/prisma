import Foundation

struct LiveTimelineEntry: Identifiable, Codable, Equatable, Sendable {
  let id: String
  let timestamp: Date?
  let timeLabel: String?
  let title: String?
  let body: String
  let imageURL: String?
  let isHighlight: Bool

  init(
    id: String = UUID().uuidString,
    timestamp: Date? = nil,
    timeLabel: String? = nil,
    title: String? = nil,
    body: String,
    imageURL: String? = nil,
    isHighlight: Bool = false
  ) {
    self.id = id
    self.timestamp = timestamp
    self.timeLabel = timeLabel
    self.title = title
    self.body = body
    self.imageURL = imageURL
    self.isHighlight = isHighlight
  }
}

enum LiveCoverageDetector {
  private static let liveUpdateTitlePatterns: [String] = [
    #"^\s*\d{1,2}[:.h]\d{2}\b"#,
    #"^\s*\d{1,3}['′]\s"#,
    #"^\s*\[\s*\d{1,2}[:.h]\d{2}\s*\]"#,
    #"(?i)^\s*minuto\s+\d+"#,
    #"(?i)^\s*actualización\b"#,
    #"(?i)^\s*update\b"#,
    #"(?i)^\s*breaking\b"#,
    #"(?i)^\s*última hora\b"#,
  ]

  private static let liveURLPatterns: [String] = [
    #"(?i)/live[-/]"#,
    #"(?i)/directo[-/]"#,
    #"(?i)/minuto-a-minuto"#,
    #"(?i)/liveblog"#,
    #"(?i)/live-blog"#,
    #"(?i)/en-directo"#,
    #"(?i)/en-vivo"#,
    #"(?i)/al-minuto"#,
  ]

  static func isLiveArticle(_ article: Article) -> Bool {
    hasActiveLiveTimeline(article)
  }

  /// Solo directo real: línea de tiempo con al menos 2 entradas horarias.
  static func hasActiveLiveTimeline(_ article: Article) -> Bool {
    LiveTimelineService.entries(for: article).count >= 2
  }

  static func isLiveFeedItem(_ item: ParsedArticle) -> Bool {
    if isLiveUpdateTitle(item.title) { return true }
    if matchesLiveURL(item.link), hasTimelineStructure(in: item) { return true }
    return false
  }

  static func isLiveUpdateTitle(_ title: String) -> Bool {
    liveUpdateTitlePatterns.contains { title.range(of: $0, options: .regularExpression) != nil }
  }

  static func eventKey(from urlString: String) -> String? {
    guard var components = URLComponents(string: urlString) else { return nil }
    components.fragment = nil
    components.query = nil
    guard let normalized = components.url?.absoluteString, !normalized.isEmpty else { return nil }
    return normalized.lowercased()
  }

  static func canonicalLiveURL(_ urlString: String) -> String {
    eventKey(from: urlString) ?? urlString
  }

  static func eventTitle(from title: String) -> String {
    var cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
    for pattern in liveUpdateTitlePatterns {
      if let range = cleaned.range(of: pattern, options: .regularExpression) {
        cleaned.removeSubrange(range)
        break
      }
    }
    cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ·|-—:"))
    return cleaned.isEmpty ? title : cleaned
  }

  private static func matchesLiveURL(_ url: String) -> Bool {
    liveURLPatterns.contains { url.range(of: $0, options: .regularExpression) != nil }
  }

  private static func hasTimelineStructure(in item: ParsedArticle) -> Bool {
    let html = item.content ?? item.summary
    return LiveTimelineParser.parse(html: html, fallbackDate: item.publishedAt).count >= 2
  }
}

enum LiveTimelineCodec {
  private static let markerPrefix = "<!--PRISMA-LIVE:"
  private static let markerSuffix = "-->"

  static func decode(from html: String?) -> ([LiveTimelineEntry], String?) {
    guard let html, html.hasPrefix(markerPrefix) else { return ([], html) }
    guard let end = html.range(of: markerSuffix) else { return ([], html) }

    let payload = String(html[html.index(html.startIndex, offsetBy: markerPrefix.count) ..< end.lowerBound])
    let remainder = String(html[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = Data(base64Encoded: payload),
          let entries = try? JSONDecoder().decode([LiveTimelineEntry].self, from: data) else {
      return ([], html)
    }
    return (entries, remainder.isEmpty ? nil : remainder)
  }

  static func encode(entries: [LiveTimelineEntry], html: String?) -> String {
    guard !entries.isEmpty,
          let data = try? JSONEncoder().encode(entries) else {
      return html ?? ""
    }
    let payload = data.base64EncodedString()
    let body = html?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if body.isEmpty {
      return "\(markerPrefix)\(payload)\(markerSuffix)"
    }
    return "\(markerPrefix)\(payload)\(markerSuffix)\n\(body)"
  }
}

enum LiveTimelineParser {
  static func parse(html: String?, fallbackDate: Date? = nil) -> [LiveTimelineEntry] {
    guard let html, !html.isEmpty else { return [] }

    let decoded = LiveTimelineCodec.decode(from: html)
    if decoded.0.count >= 2 { return sort(decoded.0) }

    let source = decoded.1 ?? html
    var entries: [LiveTimelineEntry] = []
    entries.append(contentsOf: parseTimeBlocks(from: source))
    entries.append(contentsOf: parseLiveBlogContainers(from: source))
    entries.append(contentsOf: parseListItems(from: source))
    entries.append(contentsOf: parseHeadingBlocks(from: source))

    let deduped = deduplicate(entries)
    if deduped.count >= 2 { return sort(deduped) }

    if deduped.isEmpty, let plain = HTMLSanitizer.stripHTML(source), plain.count > 120 {
      return splitPlainTextTimeline(plain, fallbackDate: fallbackDate)
    }

    return sort(deduped)
  }

  static func parseFeedItem(_ item: ParsedArticle) -> LiveTimelineEntry {
    let bodyHTML = item.content ?? item.summary ?? item.title
    let body = HTMLSanitizer.stripHTML(bodyHTML) ?? item.title
    let timeLabel = extractTimeLabel(from: item.title)
    return LiveTimelineEntry(
      id: Article.stableID(guid: item.guid, link: item.link),
      timestamp: item.publishedAt ?? item.updatedAt,
      timeLabel: timeLabel,
      title: LiveCoverageDetector.isLiveUpdateTitle(item.title)
        ? LiveCoverageDetector.eventTitle(from: item.title)
        : nil,
      body: body.trimmingCharacters(in: .whitespacesAndNewlines),
      imageURL: item.imageURL,
      isHighlight: item.title.lowercased().contains("gol")
        || item.title.lowercased().contains("breaking")
        || item.title.lowercased().contains("última hora")
    )
  }

  private static func parseTimeBlocks(from html: String) -> [LiveTimelineEntry] {
    let pattern = #"(?is)<time[^>]*datetime="([^"]+)"[^>]*>(.*?)</time>(.*?)(?=<time\b|$)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

    let range = NSRange(html.startIndex..., in: html)
    return regex.matches(in: html, range: range).compactMap { match in
      guard match.numberOfRanges >= 4,
            let dateRange = Range(match.range(at: 1), in: html),
            let labelRange = Range(match.range(at: 2), in: html),
            let bodyRange = Range(match.range(at: 3), in: html) else { return nil }

      let datetime = String(html[dateRange])
      let label = HTMLSanitizer.stripHTML(String(html[labelRange]))
      let body = HTMLSanitizer.stripHTML(String(html[bodyRange])) ?? ""
      guard body.count > 12 else { return nil }

      return LiveTimelineEntry(
        timestamp: FeedDateParser.parse(datetime),
        timeLabel: label?.trimmingCharacters(in: .whitespacesAndNewlines),
        body: body.trimmingCharacters(in: .whitespacesAndNewlines),
        imageURL: extractImageURL(from: String(html[bodyRange]))
      )
    }
  }

  private static func parseLiveBlogContainers(from html: String) -> [LiveTimelineEntry] {
    let pattern = #"(?is)<(?:article|div)[^>]*class="[^"]*(?:live[- ]?blog|liveblog|timeline|directo|minute-by-minute)[^"]*"[^>]*>(.*?)</(?:article|div)>"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

    let range = NSRange(html.startIndex..., in: html)
    return regex.matches(in: html, range: range).flatMap { match -> [LiveTimelineEntry] in
      guard let bodyRange = Range(match.range(at: 1), in: html) else { return [] }
      let chunk = String(html[bodyRange])
      let inner = parseTimeBlocks(from: chunk)
      if inner.count >= 1 { return inner }
      let plain = HTMLSanitizer.stripHTML(chunk) ?? ""
      guard plain.count > 20 else { return [] }
      return [LiveTimelineEntry(body: plain, imageURL: extractImageURL(from: chunk))]
    }
  }

  private static func parseListItems(from html: String) -> [LiveTimelineEntry] {
    let pattern = #"(?is)<li[^>]*>(.*?)</li>"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

    let range = NSRange(html.startIndex..., in: html)
    return regex.matches(in: html, range: range).compactMap { match in
      guard let bodyRange = Range(match.range(at: 1), in: html) else { return nil }
      let chunk = String(html[bodyRange])
      let plain = HTMLSanitizer.stripHTML(chunk) ?? ""
      guard plain.count > 16 else { return nil }
      guard let timeLabel = extractTimeLabel(from: plain) else { return nil }
      let body = plain.replacingOccurrences(
        of: #"^\s*\d{1,2}[:.h]\d{2}\s*[-–—]?\s*"#,
        with: "",
        options: .regularExpression
      )
      guard body.count > 10 else { return nil }
      return LiveTimelineEntry(timeLabel: timeLabel, body: body, imageURL: extractImageURL(from: chunk))
    }
  }

  private static func parseHeadingBlocks(from html: String) -> [LiveTimelineEntry] {
    let pattern = #"(?is)<h[2-4][^>]*>(.*?)</h[2-4]>(.*?)(?=<h[2-4]\b|$)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

    let range = NSRange(html.startIndex..., in: html)
    return regex.matches(in: html, range: range).compactMap { match in
      guard match.numberOfRanges >= 3,
            let titleRange = Range(match.range(at: 1), in: html),
            let bodyRange = Range(match.range(at: 2), in: html) else { return nil }

      let title = HTMLSanitizer.stripHTML(String(html[titleRange])) ?? ""
      let body = HTMLSanitizer.stripHTML(String(html[bodyRange])) ?? ""
      guard let timeLabel = extractTimeLabel(from: title), body.count > 12 else { return nil }

      return LiveTimelineEntry(
        timeLabel: timeLabel,
        title: title.replacingOccurrences(of: timeLabel, with: "").trimmingCharacters(in: .whitespacesAndNewlines),
        body: body.trimmingCharacters(in: .whitespacesAndNewlines),
        imageURL: extractImageURL(from: String(html[bodyRange]))
      )
    }
  }

  private static func splitPlainTextTimeline(_ plain: String, fallbackDate: Date?) -> [LiveTimelineEntry] {
    let lines = plain
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    var entries: [LiveTimelineEntry] = []
    var currentLabel: String?
    var currentBody: [String] = []

    func flush() {
      guard let label = currentLabel else { return }
      let body = currentBody.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
      guard body.count > 10 else {
        currentLabel = nil
        currentBody = []
        return
      }
      entries.append(LiveTimelineEntry(timestamp: fallbackDate, timeLabel: label, body: body))
      currentLabel = nil
      currentBody = []
    }

    for line in lines {
      if extractTimeLabel(from: line) != nil {
        flush()
        currentLabel = extractTimeLabel(from: line)
        let remainder = line.replacingOccurrences(
          of: #"^\s*(\d{1,2}[:.h]\d{2}|\d{1,3}['′])\s*[-–—]?\s*"#,
          with: "",
          options: .regularExpression
        )
        if !remainder.isEmpty { currentBody.append(remainder) }
      } else if currentLabel != nil {
        currentBody.append(line)
      }
    }
    flush()
    return entries
  }

  private static func extractTimeLabel(from text: String) -> String? {
    let patterns = [
      #"^\s*(\d{1,2}[:.h]\d{2})"#,
      #"^\s*(\d{1,3}['′])"#,
      #"\[\s*(\d{1,2}[:.h]\d{2})\s*\]"#,
    ]
    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern),
         let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
         let range = Range(match.range(at: 1), in: text) {
        return String(text[range])
      }
    }
    return nil
  }

  private static func extractImageURL(from html: String) -> String? {
    let pattern = #"(?i)<img[^>]+src="([^"]+)""#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
          let range = Range(match.range(at: 1), in: html) else { return nil }
    return ArticleImageURLResolver.resolve(String(html[range]))
  }

  private static func deduplicate(_ entries: [LiveTimelineEntry]) -> [LiveTimelineEntry] {
    var seen = Set<String>()
    var result: [LiveTimelineEntry] = []
    for entry in entries {
      let key = [
        entry.timeLabel ?? "",
        entry.title ?? "",
        String(entry.body.prefix(120)),
      ].joined(separator: "|")
      guard seen.insert(key).inserted else { continue }
      result.append(entry)
    }
    return result
  }

  private static func sort(_ entries: [LiveTimelineEntry]) -> [LiveTimelineEntry] {
    entries.sorted { lhs, rhs in
      switch (lhs.timestamp, rhs.timestamp) {
      case let (l?, r?): return l > r
      case (_?, nil): return true
      case (nil, _?): return false
      default: return (lhs.timeLabel ?? "") > (rhs.timeLabel ?? "")
      }
    }
  }
}

enum LiveFeedIntegrator {
  static func integrate(_ items: [ParsedArticle], source: FeedSource) -> [ParsedArticle] {
    var regular: [ParsedArticle] = []
    var masters: [String: MasterAccumulator] = [:]

    for item in items {
      guard LiveCoverageDetector.isLiveFeedItem(item) else {
        regular.append(item)
        continue
      }
      let key = LiveCoverageDetector.eventKey(from: item.link) ?? item.link.lowercased()
      masters[key, default: MasterAccumulator(key: key, canonicalURL: LiveCoverageDetector.canonicalLiveURL(item.link))]
        .add(item)
    }

    let merged = masters.values.map { $0.build(source: source) }
    return regular + merged
  }

  static func masterArticleID(sourceId: UUID, eventKey: String) -> String {
    Article.stableID(guid: "live:\(sourceId.uuidString):\(eventKey)", link: eventKey)
  }

  private struct MasterAccumulator {
    let key: String
    let canonicalURL: String
    private(set) var entries: [LiveTimelineEntry] = []
    private(set) var eventTitle: String?
    private(set) var latestHTML: String?
    private(set) var latestImageURL: String?
    private(set) var categories: [String] = []
    private(set) var latestDate: Date?

    mutating func add(_ item: ParsedArticle) {
      entries.append(LiveTimelineParser.parseFeedItem(item))
      categories.append(contentsOf: item.categories)

      let candidateTitle = LiveCoverageDetector.eventTitle(from: item.title)
      if eventTitle == nil || (!LiveCoverageDetector.isLiveUpdateTitle(item.title) && candidateTitle.count > (eventTitle?.count ?? 0)) {
        eventTitle = candidateTitle
      }

      if let html = item.content ?? item.summary, html.count > (latestHTML?.count ?? 0) {
        latestHTML = html
      }
      latestImageURL = item.imageURL ?? latestImageURL
      let itemDate = item.publishedAt ?? item.updatedAt
      if let itemDate, itemDate > (latestDate ?? .distantPast) {
        latestDate = itemDate
      }
    }

    func build(source: FeedSource) -> ParsedArticle {
      let sortedEntries = entries.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
      let encoded = LiveTimelineCodec.encode(entries: sortedEntries, html: latestHTML)
      let title = eventTitle ?? sortedEntries.first?.title ?? "En directo"
      let summary = sortedEntries.first?.body

      return ParsedArticle(
        title: title,
        link: canonicalURL,
        guid: "live:\(source.id.uuidString):\(key)",
        author: nil,
        publishedAt: latestDate ?? .now,
        updatedAt: latestDate,
        summary: summary,
        content: encoded,
        imageURL: latestImageURL,
        categories: Array(Set(categories + ["En directo"])),
        contentAvailability: .fullRSS
      )
    }
  }
}

enum LiveTimelineService {
  static func entries(for article: Article) -> [LiveTimelineEntry] {
    var collected: [LiveTimelineEntry] = []

    if let content = article.content {
      let decoded = LiveTimelineCodec.decode(from: content)
      collected.append(contentsOf: decoded.0)
      if collected.count < 2, let remainder = decoded.1 {
        collected.append(contentsOf: LiveTimelineParser.parse(html: remainder, fallbackDate: article.publishedAt))
      }
    }

    if collected.count < 2 {
      collected.append(contentsOf: LiveTimelineParser.parse(html: article.summary, fallbackDate: article.publishedAt))
    }

    return deduplicate(collected)
  }

  static func merge(entries: [LiveTimelineEntry], into article: Article) {
    guard !entries.isEmpty else { return }
    let existing = LiveTimelineService.entries(for: article)
    let merged = deduplicate(existing + entries)
    let decoded = LiveTimelineCodec.decode(from: article.content)
    article.content = LiveTimelineCodec.encode(entries: merged, html: decoded.1)
    if let latest = merged.compactMap(\.timestamp).max() {
      article.publishedAt = latest
      article.updatedAt = latest
    }
  }

  private static func deduplicate(_ entries: [LiveTimelineEntry]) -> [LiveTimelineEntry] {
    var seen = Set<String>()
    return entries.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
      .filter { entry in
        let key = entry.id.isEmpty
          ? [entry.timeLabel, entry.title, String(entry.body.prefix(100))].compactMap { $0 }.joined(separator: "|")
          : entry.id
        return seen.insert(key).inserted
      }
  }
}
