import Foundation
import NaturalLanguage

enum ArticleLanguageDetector {
  static func detectLanguageCode(in text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 24 else { return nil }

    let recognizer = NLLanguageRecognizer()
    recognizer.processString(trimmed)
    guard let language = recognizer.dominantLanguage else { return nil }
    return language.rawValue.lowercased()
  }

  static func sampleText(from article: Article) -> String {
    [
      article.title,
      HTMLSanitizer.stripHTML(article.summary) ?? "",
      HTMLSanitizer.stripHTML(article.content) ?? "",
    ]
    .joined(separator: "\n")
  }

  static func detectLanguageCode(for article: Article) -> String? {
    detectLanguageCode(in: sampleText(from: article))
  }

  static func needsTranslation(article: Article, targetLanguageCode: String) -> Bool {
    if let source = detectLanguageCode(for: article) {
      return !languageCodesMatch(source, targetLanguageCode)
    }
    if let heuristic = heuristicEnglishLanguageCode(for: article) {
      return !languageCodesMatch(heuristic, targetLanguageCode)
    }
    return false
  }

  private static func heuristicEnglishLanguageCode(for article: Article) -> String? {
    let text = sampleText(from: article).trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.count >= 8 else { return nil }
    let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
    guard !letters.isEmpty else { return nil }
    let asciiCount = letters.filter { $0.value < 128 }.count
    guard Double(asciiCount) / Double(letters.count) > 0.9 else { return nil }
    return "en"
  }

  static func languageCodesMatch(_ lhs: String, _ rhs: String) -> Bool {
    let a = lhs.lowercased().prefix(2)
    let b = rhs.lowercased().prefix(2)
    return a == b
  }
}
