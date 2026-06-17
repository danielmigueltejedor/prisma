import Foundation

enum PlainTextBatchTranslationParser {
  static func parse(_ response: String, expectedCount: Int) -> [String] {
    guard expectedCount > 0 else { return [] }

    var results = Array(repeating: "", count: expectedCount)
    let lines = response.components(separatedBy: .newlines)
    var currentIndex: Int?
    var buffer: [String] = []

    func flush() {
      guard let index = currentIndex, index < expectedCount else { return }
      let joined = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      if !joined.isEmpty {
        results[index] = joined
      }
      buffer.removeAll(keepingCapacity: true)
    }

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if let match = trimmed.firstMatch(of: /^(\d+)[.)]\s*(.*)$/) {
        flush()
        if let number = Int(match.1), number >= 1, number <= expectedCount {
          currentIndex = number - 1
          let remainder = String(match.2)
          if !remainder.isEmpty {
            buffer.append(remainder)
          }
        }
        continue
      }
      if currentIndex != nil {
        buffer.append(line)
      }
    }
    flush()

    if results.allSatisfy(\.isEmpty) {
      return fallbackSplit(response, expectedCount: expectedCount)
    }
    return results
  }

  private static func fallbackSplit(_ response: String, expectedCount: Int) -> [String] {
    let chunks = response
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard chunks.count == expectedCount else { return [] }
    return chunks
  }
}
