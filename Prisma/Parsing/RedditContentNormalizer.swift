import Foundation

enum RedditContentNormalizer {
  static func isRedditURL(_ url: String?) -> Bool {
    guard let url else { return false }
    return url.lowercased().contains("reddit.com")
  }

  static func normalizeAuthor(_ raw: String?) -> String? {
    guard var name = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
    if name.hasPrefix("/u/") {
      name = "u/" + name.dropFirst(3)
    } else if !name.hasPrefix("u/"), !name.contains("/") {
      name = "u/\(name)"
    }
    return name
  }

  static func extractAuthorFromFooter(_ html: String) -> String? {
    let pattern = #"(?:submitted by|enviado por)\s+/?u/([\w-]+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
          let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
          let range = Range(match.range(at: 1), in: html)
    else { return nil }
    return normalizeAuthor(String(html[range]))
  }

  static func cleanHTML(_ html: String?) -> String? {
    guard var html, !html.isEmpty else { return nil }
    html = html.replacingOccurrences(of: "<!-- SC_OFF -->", with: "")
    html = html.replacingOccurrences(of: "<!-- SC_ON -->", with: "")

    if let range = html.range(
      of: #"(submitted by|enviado por)\s+"#,
      options: [.regularExpression, .caseInsensitive]
    ) {
      html = String(html[..<range.lowerBound])
    }

    html = html.replacingOccurrences(
      of: #"<span[^>]*>\s*<a[^>]*>\s*\[(?:link|comments?|comentarios|commentaires)\]\s*</a>\s*</span>"#,
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    html = html.replacingOccurrences(
      of: #"\[(?:link|comments?|comentarios|commentaires)\]"#,
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )

    let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func cleanPlainText(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(
      of: #"\s*\[(?:link|comments?|comentarios|commentaires)\](?:\s*\[(?:link|comments?|comentarios|commentaires)\])?\s*$"#,
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    result = result.replacingOccurrences(
      of: #"\s*(?:submitted by|enviado por)\s+/?u/[\w-]+(?:\s+(?:to|en)\s+r/[\w-]+)?\s*$"#,
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func normalizeParsedArticle(_ item: ParsedArticle, link: String) -> ParsedArticle {
    guard isRedditURL(link) else { return item }
    var copy = item
    let rawHTML = item.content ?? item.summary
    if let cleaned = cleanHTML(rawHTML) {
      if item.content != nil {
        copy.content = cleaned
      } else {
        copy.summary = cleaned
      }
    }
    if let author = copy.author {
      copy.author = normalizeAuthor(author)
    } else if let rawHTML, let extracted = extractAuthorFromFooter(rawHTML) {
      copy.author = extracted
    }
    return copy
  }
}
