import Foundation
import SwiftData

@MainActor
final class CollectionRepository {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func fetchAll() throws -> [Collection] {
    let descriptor = FetchDescriptor<Collection>(
      sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
    )
    return try context.fetch(descriptor)
  }

  @discardableResult
  func create(name: String) throws -> Collection {
    let collection = Collection(name: name, sortOrder: try fetchAll().count)
    context.insert(collection)
    try context.save()
    return collection
  }

  func add(article: Article, to collection: Collection) throws {
    if !article.isSaved {
      article.isSaved = true
      if article.savedEntry == nil {
        let saved = SavedArticle(article: article)
        context.insert(saved)
        article.savedEntry = saved
      }
    }
    if let saved = article.savedEntry, !collection.savedArticles.contains(where: { $0.id == saved.id }) {
      collection.savedArticles.append(saved)
    }
    try context.save()
  }

  func delete(_ collection: Collection) throws {
    context.delete(collection)
    try context.save()
  }
}
