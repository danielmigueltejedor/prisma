import Foundation

enum FeedParseError: LocalizedError {
  case invalidXML
  case unsupportedFormat

  var errorDescription: String? {
    switch self {
    case .invalidXML: String(localized: "error.feed.invalidXML")
    case .unsupportedFormat: String(localized: "error.feed.unsupported")
    }
  }
}

final class RSSAtomParser: NSObject, FeedParserProtocol {
  private var feedTitle: String?
  private var feedLink: String?
  private var isAtom = false

  private var articles: [ParsedArticle] = []
  private var currentArticle: ArticleBuilder?
  private var currentElement = ""
  private var currentText = ""
  private var elementStack: [String] = []

  func parse(data: Data) throws -> ParsedFeed {
    reset()
    let parser = XMLParser(data: data)
    parser.delegate = self
    parser.shouldResolveExternalEntities = false
    guard parser.parse() else {
      throw FeedParseError.invalidXML
    }
    return ParsedFeed(
      title: feedTitle,
      siteURL: feedLink,
      feedURL: nil,
      articles: articles
    )
  }

  private func reset() {
    feedTitle = nil
    feedLink = nil
    isAtom = false
    articles = []
    currentArticle = nil
    currentElement = ""
    currentText = ""
    elementStack = []
  }

  private func flushText() {
    let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      currentText = ""
      return
    }

    let element = currentElement.lowercased()

    if currentArticle == nil {
      switch element {
      case "title" where elementStack.last == "channel" || elementStack.last == "feed":
        feedTitle = text
      case "link" where elementStack.last == "channel":
        feedLink = text
      default:
        break
      }
    }

    if var builder = currentArticle {
      switch element {
      case "title": builder.title = text
      case "link": builder.link = text
      case "guid", "id": builder.guid = text
      case "author", "dc:creator", "creator":
        builder.author = HTMLSanitizer.stripHTML(text) ?? text
      case "pubdate", "published", "updated", "dc:date":
        let date = FeedDateParser.parse(text)
        if element.contains("pub") || element == "published" || element == "dc:date" {
          builder.publishedAt = builder.publishedAt ?? date
        } else {
          builder.updatedAt = date
        }
      case "description", "summary":
        builder.summary = text
      case "content:encoded", "content":
        builder.content = text
      case "category", "dc:subject":
        builder.categories.append(text)
      case "enclosure":
        break
      default:
        break
      }
      currentArticle = builder
    }

    currentText = ""
  }

  private func finalizeCurrentArticle() {
    guard var builder = currentArticle else { return }
    if builder.link.isEmpty, let guid = builder.guid, guid.hasPrefix("http") {
      builder.link = guid
    }
    guard !builder.title.isEmpty, !builder.link.isEmpty else {
      currentArticle = nil
      return
    }

    let availability = Self.contentAvailability(summary: builder.summary, content: builder.content)
    let article = ParsedArticle(
      title: HTMLSanitizer.stripHTML(builder.title) ?? builder.title,
      link: builder.link,
      guid: builder.guid,
      author: builder.author,
      publishedAt: builder.publishedAt,
      updatedAt: builder.updatedAt,
      summary: builder.summary,
      content: builder.content,
      imageURL: builder.imageURL,
      categories: builder.categories,
      contentAvailability: availability
    )
    articles.append(article)
    currentArticle = nil
  }

  private static func contentAvailability(summary: String?, content: String?) -> ContentAvailability {
    let contentPlain = HTMLSanitizer.stripHTML(content) ?? ""
    let summaryPlain = HTMLSanitizer.stripHTML(summary) ?? ""
    if contentPlain.count > 200 { return .fullRSS }
    if !contentPlain.isEmpty, contentPlain.count > summaryPlain.count + 40 { return .fullRSS }
    if summaryPlain.count > 280 { return .fullRSS }
    if !summaryPlain.isEmpty { return .partialRSS }
    return .unknown
  }

  private struct ArticleBuilder {
    var title: String = ""
    var link: String = ""
    var guid: String?
    var author: String?
    var publishedAt: Date?
    var updatedAt: Date?
    var summary: String?
    var content: String?
    var imageURL: String?
    var categories: [String] = []
  }
}

extension RSSAtomParser: XMLParserDelegate {
  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    flushText()
    let name = (qName ?? elementName).lowercased()
    currentElement = name
    elementStack.append(name)

    if name == "feed" { isAtom = true }
    if name == "entry" || name == "item" {
      currentArticle = ArticleBuilder()
    }

  if let builder = currentArticle {
      var updated = builder
      if name == "link", let href = attributeDict["href"], !href.isEmpty {
        updated.link = href
      }
      if name == "enclosure", let url = attributeDict["url"],
         attributeDict["type"]?.contains("image") == true || updated.imageURL == nil {
        updated.imageURL = url
      }
      if name == "media:content" || name == "media:thumbnail",
         let url = attributeDict["url"] {
        updated.imageURL = url
      }
      currentArticle = updated
    }

    if name == "channel", feedLink == nil, let link = attributeDict["href"] {
      feedLink = link
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    currentText += string
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    flushText()
    let name = (qName ?? elementName).lowercased()
    if name == "entry" || name == "item" {
      finalizeCurrentArticle()
    }
    elementStack.removeLast()
    currentElement = elementStack.last ?? ""
  }
}

enum FeedDateParser {
  private static let formatters: [DateFormatter] = {
    let formats = [
      "EEE, dd MMM yyyy HH:mm:ss Z",
      "EEE, dd MMM yyyy HH:mm:ss zzz",
      "yyyy-MM-dd'T'HH:mm:ssZ",
      "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
      "yyyy-MM-dd'T'HH:mm:ssXXXXX",
      "yyyy-MM-dd HH:mm:ss",
    ]
    return formats.map { format in
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX")
      f.dateFormat = format
      return f
    }
  }()

  static func parse(_ string: String) -> Date? {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    for formatter in formatters {
      if let date = formatter.date(from: trimmed) { return date }
    }
    if #available(iOS 15.0, *) {
      let iso = ISO8601DateFormatter()
      iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = iso.date(from: trimmed) { return date }
      iso.formatOptions = [.withInternetDateTime]
      return iso.date(from: trimmed)
    }
    return nil
  }
}
