import Foundation

enum ContentStyleFilter {
  static let allSelection = "Todas"
  static let orderedStyles = ["General", "Deportes", "Tecnología", "Economía", "Internacional"]

  static func filters(including availableStyles: Set<String>? = nil) -> [String] {
    guard let availableStyles, !availableStyles.isEmpty else {
      return [allSelection] + orderedStyles
    }
    return [allSelection] + orderedStyles.filter { availableStyles.contains($0) }
  }

  static func matches(style: String, selection: String) -> Bool {
    selection == allSelection || style == selection
  }

  static func style(for source: FeedSource) -> String {
    if let feed = RecommendedFeeds.matching(source) {
      return normalizeCategory(feed.category)
    }
    if source.platform == .reddit {
      return inferStyle(from: "\(source.name) \(source.feedDescription ?? "")")
    }
    return inferStyle(from: "\(source.name) \(source.feedURL) \(source.feedDescription ?? "")")
  }

  static func style(for feed: RecommendedFeed) -> String {
    normalizeCategory(feed.category)
  }

  static func style(for article: Article) -> String {
    inferStyle(
      from: [
        article.sourceName,
        article.categoryNames.joined(separator: " "),
      ].joined(separator: " ")
    )
  }

  static func inferStyle(from raw: String) -> String {
    let blob = normalized(raw)
    if blob.contains("deporte") || blob.contains("sport") || blob.contains("futbol")
      || blob.contains("marca") || blob.contains(" as ") || blob.contains("espn")
    {
      return "Deportes"
    }
    if blob.contains("tecnologia") || blob.contains("tech") || blob.contains("apple")
      || blob.contains("xataka") || blob.contains("genbeta") || blob.contains("applesfera")
    {
      return "Tecnología"
    }
    if blob.contains("economia") || blob.contains("econom") || blob.contains("mercado")
      || blob.contains("finanza") || blob.contains("bolsa")
    {
      return "Economía"
    }
    if blob.contains("internacional") || blob.contains("world") || blob.contains("reuters")
      || blob.contains("bbc")
    {
      return "Internacional"
    }
    return "General"
  }

  private static func normalizeCategory(_ category: String) -> String {
    let blob = normalized(category)
    if blob.contains("deporte") || blob.contains("sport") { return "Deportes" }
    if blob.contains("tecnolog") || blob.contains("tech") { return "Tecnología" }
    if blob.contains("econom") { return "Economía" }
    if blob.contains("internacional") || blob.contains("world") { return "Internacional" }
    return "General"
  }

  private static func normalized(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
  }
}
