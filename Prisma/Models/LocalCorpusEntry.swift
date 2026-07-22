import Foundation
import SwiftData

/// Fragmento de artículo indexado localmente para búsqueda rápida y contexto de IA.
@Model
final class LocalCorpusEntry {
  @Attribute(.unique) var articleId: String
  var authorKey: String?
  var sourceId: UUID
  var sourceName: String
  var title: String
  var bodyText: String
  var byteSize: Int
  var indexedAt: Date
  var lastAccessedAt: Date

  init(
    articleId: String,
    authorKey: String?,
    sourceId: UUID,
    sourceName: String,
    title: String,
    bodyText: String,
    byteSize: Int,
    indexedAt: Date = .now,
    lastAccessedAt: Date = .now
  ) {
    self.articleId = articleId
    self.authorKey = authorKey
    self.sourceId = sourceId
    self.sourceName = sourceName
    self.title = title
    self.bodyText = bodyText
    self.byteSize = byteSize
    self.indexedAt = indexedAt
    self.lastAccessedAt = lastAccessedAt
  }
}
