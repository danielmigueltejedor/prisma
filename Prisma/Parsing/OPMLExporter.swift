import Foundation

struct OPMLExporter {
  func export(sources: [FeedSource]) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    let dateString = dateFormatter.string(from: .now)

    var lines = [
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      "<opml version=\"2.0\">",
      "  <head>",
      "    <title>Prisma Feeds</title>",
      "    <dateCreated>\(dateString)</dateCreated>",
      "  </head>",
      "  <body>",
    ]

    for source in sources {
      let title = escape(source.name)
      let xmlURL = escape(source.feedURL)
      let htmlURL = escape(source.siteURL ?? "")
      lines.append(
        "    <outline type=\"rss\" text=\"\(title)\" title=\"\(title)\" xmlUrl=\"\(xmlURL)\" htmlUrl=\"\(htmlURL)\"/>"
      )
    }

    lines.append("  </body>")
    lines.append("</opml>")
    return lines.joined(separator: "\n")
  }

  private func escape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}
