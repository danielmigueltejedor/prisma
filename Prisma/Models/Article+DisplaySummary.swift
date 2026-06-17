import Foundation

extension Article {
  var displaySummary: String? {
    if let plainSummary, !plainSummary.isEmpty { return plainSummary }
    guard let summary else { return nil }
    return HTMLSanitizer.stripHTML(summary)
  }
}
