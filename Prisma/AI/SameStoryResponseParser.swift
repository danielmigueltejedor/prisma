import Foundation

enum SameStoryResponseParser {
  private static let unifiedMarkers = [
    "NOTICIA UNIFICADA:",
    "NOTICIA_UNIFICADA:",
    "NOTICIA UNIFICADA",
    "NOTICIA_UNIFICADA",
  ]

  private static let comparisonEndMarkers = [
    "LECTURA RÁPIDA:",
    "LECTURA RAPIDA:",
    "LECTURA_RÁPIDA:",
    "LECTURA_RAPIDA:",
  ]

  static func parse(_ raw: String) -> SameStoryComparisonDTO {
    let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let unifiedStory = extractUnifiedStory(from: cleaned)
    let comparisonText = comparisonBody(from: cleaned, unifiedStory: unifiedStory)
    return SameStoryComparisonDTO(
      comparisonText: comparisonText.isEmpty ? cleaned : comparisonText,
      unifiedStory: unifiedStory.isEmpty ? cleaned : unifiedStory
    )
  }

  static func parseVerifiedIDs(_ response: String, validIDs: Set<String>) -> [String] {
    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.uppercased().contains("NONE") || trimmed.uppercased().contains("NINGUN") {
      return []
    }

    return trimmed
      .components(separatedBy: .newlines)
      .flatMap { line -> [String] in
        let token = line
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .replacingOccurrences(of: "ID:", with: "", options: .caseInsensitive)
          .trimmingCharacters(in: .whitespacesAndNewlines)
        if validIDs.contains(token) { return [token] }
        return token
          .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "_" })
          .map(String.init)
          .filter { validIDs.contains($0) }
      }
      .reduce(into: [String]()) { result, id in
        if !result.contains(id) { result.append(id) }
      }
  }

  private static func extractUnifiedStory(from raw: String) -> String {
    guard let range = markerRange(in: raw, markers: unifiedMarkers) else { return "" }
    let bodyStart = raw.index(range.upperBound, offsetBy: 0)
    let tail = String(raw[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
    if let end = markerRange(in: tail, markers: comparisonEndMarkers) {
      return String(tail[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return tail
  }

  private static func comparisonBody(from raw: String, unifiedStory: String) -> String {
    guard !unifiedStory.isEmpty,
          let range = markerRange(in: raw, markers: unifiedMarkers) else {
      return raw
    }
    let before = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    let bodyStart = raw.index(range.upperBound, offsetBy: 0)
    let tail = String(raw[bodyStart...])
    let afterUnified: String
    if let end = markerRange(in: tail, markers: comparisonEndMarkers) {
      afterUnified = String(tail[end.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      afterUnified = ""
    }
    return [before, afterUnified]
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func markerRange(in text: String, markers: [String]) -> Range<String.Index>? {
    var found: Range<String.Index>?
    for marker in markers {
      if let range = text.range(of: marker, options: [.caseInsensitive, .diacriticInsensitive]) {
        if let existing = found, range.lowerBound >= existing.lowerBound { continue }
        found = range
      }
    }
    return found
  }
}
