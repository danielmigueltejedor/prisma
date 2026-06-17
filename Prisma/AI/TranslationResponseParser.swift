import Foundation

enum TranslationResponseParser {
  static func parse(_ response: String, fallbackTitle: String) -> (title: String, body: String) {
    let normalized = response
      .replacingOccurrences(of: "\r\n", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let lines = normalized.components(separatedBy: .newlines)

    if let titleIndex = lines.firstIndex(where: { $0.uppercased().hasPrefix("TITLE:") }) {
      let title = String(lines[titleIndex].dropFirst(6)).trimmingCharacters(in: .whitespaces)
      let bodyStart = titleIndex + 1
      var bodyLines = Array(lines.dropFirst(bodyStart))
      if let bodyIndex = bodyLines.firstIndex(where: { $0.uppercased().hasPrefix("BODY:") }) {
        bodyLines = Array(bodyLines.dropFirst(bodyIndex + 1))
      }
      let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      if !title.isEmpty, !body.isEmpty {
        return (title, body)
      }
    }

    let paragraphs = normalized
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    if paragraphs.count >= 2 {
      return (paragraphs[0], paragraphs.dropFirst().joined(separator: "\n\n"))
    }

    return (fallbackTitle, normalized)
  }
}
