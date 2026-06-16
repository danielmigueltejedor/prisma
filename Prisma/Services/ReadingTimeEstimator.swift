import Foundation

enum ReadingTimeEstimator {
  private static let wordsPerMinute = 200

  static func estimate(text: String?) -> Int {
    guard let text, !text.isEmpty else { return 1 }
    let plain = HTMLSanitizer.stripHTML(text) ?? text
    let words = plain.split { $0.isWhitespace || $0.isNewline }.count
    return max(1, Int(ceil(Double(words) / Double(wordsPerMinute))))
  }
}
