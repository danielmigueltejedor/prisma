import Foundation
import SwiftUI

enum HTMLSanitizer {
  private static let allowedTags: Set<String> = [
    "p", "br", "b", "strong", "i", "em", "u", "a", "ul", "ol", "li",
    "h1", "h2", "h3", "h4", "blockquote", "code", "pre", "span", "div",
  ]

  /// Strips all HTML tags and decodes common entities for display in plain text contexts.
  static func stripHTML(_ html: String?) -> String? {
    guard let html, !html.isEmpty else { return nil }
    var result = html
    result = result.replacingOccurrences(
      of: "<[^>]+>",
      with: " ",
      options: .regularExpression
    )
    result = decodeEntities(result)
    result = cleanArtifacts(in: result)
    result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Produces safe simplified HTML for SwiftUI Text(AttributedString) rendering.
  static func sanitizeForDisplay(_ html: String?) -> String? {
    guard let html, !html.isEmpty else { return nil }

    var output = html
    // Remove script, style, iframe and other dangerous blocks
    let dangerousPatterns = [
      "<script[^>]*>[\\s\\S]*?</script>",
      "<style[^>]*>[\\s\\S]*?</style>",
      "<iframe[^>]*>[\\s\\S]*?</iframe>",
      "<object[^>]*>[\\s\\S]*?</object>",
      "<embed[^>]*/?>",
      "on\\w+=\"[^\"]*\"",
      "on\\w+='[^']*'",
    ]
    for pattern in dangerousPatterns {
      output = output.replacingOccurrences(
        of: pattern,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
    }

    // Strip disallowed tags but keep content
    output = output.replacingOccurrences(
      of: "<(?!/?(?:\(allowedTags.joined(separator: "|")))\\b)[^>]+>",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )

    // Force links to open externally — href preserved for AttributedString
    output = output.replacingOccurrences(
      of: "<a\\s+([^>]*?)href=\"([^\"]+)\"([^>]*)>",
      with: "<a href=\"$2\">",
      options: [.regularExpression, .caseInsensitive]
    )

    output = decodeEntities(output)
    output = cleanArtifacts(in: output)
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func attributedString(from html: String?) -> AttributedString? {
    guard let sanitized = sanitizeForDisplay(html) else { return nil }

    let wrapped: String
    let lower = sanitized.lowercased()
    if lower.contains("<html") {
      wrapped = sanitized
    } else {
      wrapped = "<html><body>\(sanitized)</body></html>"
    }

    guard let data = wrapped.data(using: .utf8) else {
      return stripHTML(html).map { AttributedString($0) }
    }

    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
      .documentType: NSAttributedString.DocumentType.html,
      .characterEncoding: String.Encoding.utf8.rawValue,
    ]
    guard let nsAttr = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
    else {
      if let plain = stripHTML(html) {
        return AttributedString(plain)
      }
      return nil
    }
    return AttributedString(nsAttr)
  }

  /// Full HTML document for in-app WebView reader.
  static func readerDocument(
    from html: String?,
    colorScheme: ColorScheme,
    fontFamily: ReaderFontFamily = .serif,
    fontSizeMultiplier: Double = 1.0,
    suppressInlineImages: Bool = false
  ) -> String {
    let sanitized = suppressInlineImages
      ? (stripInlineMedia(from: stripImageTags(from: sanitizeForReader(html)) ?? "") ?? "")
      : (sanitizeForReader(html) ?? "")

    let textColor = colorScheme == .dark ? "#F2F2F7" : "#1C1C1E"
    let secondary = colorScheme == .dark ? "#AEAEB2" : "#636366"
    let link = colorScheme == .dark ? "#64D2FF" : "#007AFF"
    let fontSize = 18.0 * fontSizeMultiplier
    let lineHeight = 1.7
    let maxWidth = "42rem"

    let css = """
    html, body {
      background: transparent;
      overflow: visible;
      min-height: auto;
    }
    body {
      font-family: \(fontFamily.cssStack);
      font-size: \(fontSize)px;
      line-height: \(lineHeight);
      color: \(textColor);
      margin: 0 auto;
      padding: 0;
      max-width: \(maxWidth);
      word-wrap: break-word;
      -webkit-text-size-adjust: 100%;
    }
    p, li, blockquote { margin: 0 0 1.1em 0; }
    h1, h2, h3, h4 {
      font-family: -apple-system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
      line-height: 1.2;
      margin: 1.4em 0 0.6em;
      font-weight: 600;
    }
    h1 { font-size: 1.35em; }
    h2 { font-size: 1.2em; }
    img, figure {
      max-width: 100%;
      height: auto;
      border-radius: 12px;
      margin: 1em 0;
      display: \(suppressInlineImages ? "none" : "block");
    }
    figcaption { font-size: 0.85em; color: \(secondary); margin-top: 0.4em; }
    video, iframe, embed, object {
      max-width: 100%;
      margin: 1em 0;
      display: \(suppressInlineImages ? "none" : "block");
    }
    a { color: \(link); text-decoration: none; }
    blockquote {
      border-left: 3px solid \(secondary);
      padding-left: 16px;
      margin-left: 0;
      color: \(secondary);
      font-style: italic;
    }
    ul, ol { padding-left: 1.4em; }
    pre, code {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 0.9em;
      background: \(colorScheme == .dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)");
      border-radius: 6px;
    }
    pre { padding: 12px; overflow-x: auto; }
    [hidden], .hidden, .prisma-hidden, [style*="display:none"], [style*="display: none"] {
      display: none !important;
      max-height: 0 !important;
      overflow: hidden !important;
      margin: 0 !important;
      padding: 0 !important;
    }
    """
    return """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <style>\(css)</style>
    </head>
    <body>\(sanitized)</body>
    </html>
    """
  }

  private static let readerTags: Set<String> = [
    "p", "br", "b", "strong", "i", "em", "u", "a", "ul", "ol", "li",
    "h1", "h2", "h3", "h4", "blockquote", "code", "pre", "span", "div", "img", "figure", "figcaption",
  ]

  static func sanitizeForReader(_ html: String?) -> String? {
    guard let html, !html.isEmpty else { return nil }

    var output = html
    let dangerousPatterns = [
      "<script[^>]*>[\\s\\S]*?</script>",
      "<style[^>]*>[\\s\\S]*?</style>",
      "<iframe[^>]*>[\\s\\S]*?</iframe>",
      "<object[^>]*>[\\s\\S]*?</object>",
      "<embed[^>]*/?>",
      "on\\w+=\"[^\"]*\"",
      "on\\w+='[^']*'",
    ]
    for pattern in dangerousPatterns {
      output = output.replacingOccurrences(
        of: pattern,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
    }

    output = output.replacingOccurrences(
      of: "<(?!/?(?:\(readerTags.joined(separator: "|")))\\b)[^>]+>",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )

    // Drop media tags with empty or unsafe sources to avoid broken placeholders.
    output = output.replacingOccurrences(
      of: "<img\\b(?:(?!\\bsrc\\s*=)[^>])*?>",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    output = output.replacingOccurrences(
      of: "<img[^>]*src\\s*=\\s*\"\\s*(?:javascript:|data:|about:blank)[^\"]*\"[^>]*>",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    output = cleanArtifacts(in: output)

    output = decodeEntities(output)
    output = cleanArtifacts(in: output)
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Aggressive cleanup for distraction-free reading (Safari Reader–style).
  static func sanitizeForReaderMode(_ html: String?) -> String? {
    guard var output = sanitizeForReader(html) else { return nil }

    let junkBlockPatterns = [
      "<(aside|nav|footer|header|form|button|input|select|textarea|noscript)[^>]*>[\\s\\S]*?</\\1>",
      "<div[^>]*class=\"[^\"]*(?:ad|ads|advert|banner|promo|newsletter|subscribe|social|share|related|sidebar|comments|comment|cookie|popup|modal|tracking)[^\"]*\"[^>]*>[\\s\\S]*?</div>",
      "<div[^>]*id=\"[^\"]*(?:ad|ads|advert|banner|promo|newsletter|subscribe|social|share|related|sidebar|comments|comment|cookie|popup|modal)[^\"]*\"[^>]*>[\\s\\S]*?</div>",
    ]
    for pattern in junkBlockPatterns {
      output = output.replacingOccurrences(
        of: pattern,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
    }

    // Reader mode prioritizes clean text flow over media rendering.
    output = output.replacingOccurrences(
      of: "<(img|figure|figcaption)[^>]*>[\\s\\S]*?</\\1>",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    output = output.replacingOccurrences(
      of: "<(img|figure|figcaption)\\b[^>]*>",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )

    output = stripAttributes(from: output, keeping: ["href", "src", "alt"])
    output = collapseEmptyTags(output)
    output = output.replacingOccurrences(
      of: "<div>([\\s\\S]*?)</div>",
      with: "$1",
      options: [.regularExpression, .caseInsensitive]
    )

    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func stripAttributes(from html: String, keeping allowed: [String]) -> String {
    var result = html
    let removablePatterns = [
      " class=\"[^\"]*\"",
      " id=\"[^\"]*\"",
      " style=\"[^\"]*\"",
      " data-[a-z0-9-]+=\"[^\"]*\"",
      " aria-[a-z-]+=\"[^\"]*\"",
      " role=\"[^\"]*\"",
      " target=\"[^\"]*\"",
      " rel=\"[^\"]*\"",
    ]
    for pattern in removablePatterns {
      result = result.replacingOccurrences(
        of: pattern,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
    }
    if !allowed.contains("href") {
      result = result.replacingOccurrences(
        of: " href=\"[^\"]*\"",
        with: "",
        options: .regularExpression
      )
    }
    return result
  }

  private static func stripImageTags(from html: String?) -> String? {
    guard let html else { return nil }
    var output = html
    output = output.replacingOccurrences(
      of: "<figure[^>]*>[\\s\\S]*?</figure>",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    output = output.replacingOccurrences(
      of: "<img\\b[^>]*>",
      with: "",
      options: [.regularExpression, .caseInsensitive]
    )
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func stripInlineMedia(from html: String?) -> String? {
    guard let html else { return nil }
    var output = html
    let patterns = [
      "<video\\b[\\s\\S]*?</video>",
      "<iframe\\b[^>]*>[\\s\\S]*?</iframe>",
      "<iframe\\b[^>]*/>",
      "<embed\\b[^>]*>",
      "<object\\b[\\s\\S]*?</object>",
    ]
    for pattern in patterns {
      output = output.replacingOccurrences(
        of: pattern,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func collapseEmptyTags(_ html: String) -> String {
    var result = html
    let emptyPatterns = [
      "<p>\\s*</p>",
      "<div>\\s*</div>",
      "<span>\\s*</span>",
      "<figure>\\s*</figure>",
    ]
    for pattern in emptyPatterns {
      result = result.replacingOccurrences(
        of: pattern,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
    }
    return result
  }

  private static func decodeEntities(_ string: String) -> String {
    var result = string
    let entities: [(String, String)] = [
      ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
      ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " "),
    ]
    for (entity, char) in entities {
      result = result.replacingOccurrences(of: entity, with: char)
    }
    return result
  }

  private static func cleanArtifacts(in text: String) -> String {
    var result = text
    // Unicode placeholders commonly seen in malformed RSS content.
    result = result.replacingOccurrences(of: "\u{FFFD}", with: "")
    result = result.replacingOccurrences(of: "\u{FFFC}", with: "")
    result = result.replacingOccurrences(of: "❓", with: "")
    return result
  }
}
