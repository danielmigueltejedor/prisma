import Foundation
import SwiftData

@MainActor
final class LocalCorpusRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func find(articleId: String) throws -> LocalCorpusEntry? {
    let descriptor = FetchDescriptor<LocalCorpusEntry>(
      predicate: #Predicate { $0.articleId == articleId }
    )
    return try context.fetch(descriptor).first
  }

  func fetchByAuthor(_ authorKey: String, limit: Int = 40) throws -> [LocalCorpusEntry] {
    let needle = authorKey.lowercased()
    let descriptor = FetchDescriptor<LocalCorpusEntry>(
      sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
    )
    return try context.fetch(descriptor)
      .filter { ($0.authorKey ?? "").lowercased() == needle }
      .prefix(limit)
      .map { $0 }
  }

  func totalByteSize() throws -> Int {
    try context.fetch(FetchDescriptor<LocalCorpusEntry>()).reduce(0) { $0 + $1.byteSize }
  }

  func save(_ entry: LocalCorpusEntry) throws {
    context.insert(entry)
    try context.save()
  }

  func update(_ entry: LocalCorpusEntry) throws {
    try context.save()
  }

  func delete(_ entry: LocalCorpusEntry) throws {
    context.delete(entry)
    try context.save()
  }

  func fetchRecent(limit: Int = 80) throws -> [LocalCorpusEntry] {
    var descriptor = FetchDescriptor<LocalCorpusEntry>(
      sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    return try context.fetch(descriptor)
  }

  func fetchOldestEntries(limit: Int) throws -> [LocalCorpusEntry] {
    var descriptor = FetchDescriptor<LocalCorpusEntry>(
      sortBy: [SortDescriptor(\.lastAccessedAt, order: .forward)]
    )
    descriptor.fetchLimit = limit
    return try context.fetch(descriptor)
  }
}
