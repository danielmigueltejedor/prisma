import Foundation

struct OPMLFeedOutline {
  var title: String
  var xmlURL: String
  var htmlURL: String?
}

struct OPMLImporter {
  func parse(data: Data) throws -> [OPMLFeedOutline] {
    let delegate = OPMLParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = delegate
    guard parser.parse() else {
      throw FeedParseError.invalidXML
    }
    return delegate.outlines
  }
}

private final class OPMLParserDelegate: NSObject, XMLParserDelegate {
  var outlines: [OPMLFeedOutline] = []

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    guard elementName.lowercased() == "outline" else { return }
    guard let xmlURL = attributeDict["xmlUrl"] ?? attributeDict["xmlurl"], !xmlURL.isEmpty else { return }
    let title = attributeDict["title"] ?? attributeDict["text"] ?? xmlURL
    let htmlURL = attributeDict["htmlUrl"] ?? attributeDict["htmlurl"]
    outlines.append(OPMLFeedOutline(title: title, xmlURL: xmlURL, htmlURL: htmlURL))
  }
}
