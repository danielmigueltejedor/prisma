import Foundation

enum AITextFormatter {
  static func clean(_ text: String) -> String {
    var cleaned = text
    cleaned = cleaned.replacingOccurrences(of: "\\*\\*", with: "", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "(?m)^\\s*[-*]\\s+", with: "• ", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Removes a repeated headline from the start of body/summary text.
  static func bodyWithoutRepeatedHeadline(headline: String, body: String) -> String {
    let title = clean(headline)
    var output = clean(body)
    guard !title.isEmpty, !output.isEmpty else { return output }

    var lines = output.components(separatedBy: .newlines).map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }.filter { !$0.isEmpty }

    while let first = lines.first, normalized(first) == normalized(title) {
      lines.removeFirst()
    }

    output = lines.joined(separator: "\n")
    if normalized(output).hasPrefix(normalized(title)) {
      let dropped = String(output.dropFirst(title.count)).trimmingCharacters(in: .whitespacesAndNewlines)
      if !dropped.isEmpty { output = dropped }
    }

    return output.isEmpty ? clean(body) : output
  }

  private static func normalized(_ text: String) -> String {
    text
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
