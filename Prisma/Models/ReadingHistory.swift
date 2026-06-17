import Foundation
import SwiftData

@Model
final class ReadingHistory {
  @Attribute(.unique) var id: UUID
  var readAt: Date
  var progress: Double
  var totalDwellSeconds: Double

  var article: Article?

  init(
    id: UUID = UUID(),
    readAt: Date = .now,
    progress: Double = 1.0,
    totalDwellSeconds: Double = 0,
    article: Article? = nil
  ) {
    self.id = id
    self.readAt = readAt
    self.progress = progress
    self.totalDwellSeconds = totalDwellSeconds
    self.article = article
  }
}
