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
    guard let source = detectLanguageCode(for: article) else { return false }
    return !languageCodesMatch(source, targetLanguageCode)
  }

  static func languageCodesMatch(_ lhs: String, _ rhs: String) -> Bool {
    let a = lhs.lowercased().prefix(2)
    let b = rhs.lowercased().prefix(2)
    return a == b
  }
}
