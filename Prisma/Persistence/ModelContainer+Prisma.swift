import SwiftData
import Foundation

enum PrismaModelContainer {
  static let schema = Schema([
    FeedSource.self,
    Article.self,
    Author.self,
    Category.self,
    ReadingHistory.self,
    UserPreference.self,
    SavedArticle.self,
    Collection.self,
    AIArticleSummary.self,
    AIArticleInsight.self,
    ArticleTranslation.self,
    RedditCommentsTranslation.self,
    NewsCluster.self,
  ])

  static func make(inMemory: Bool = false) throws -> ModelContainer {
    let config: ModelConfiguration
    if inMemory {
      config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    } else {
      config = ModelConfiguration(schema: schema, url: persistentStoreURL)
    }
    return try ModelContainer(for: schema, configurations: [config])
  }

  static func resetPersistentStore() {
    let fm = FileManager.default
    let base = persistentStoreURL.deletingPathExtension()
    var candidates = [
      persistentStoreURL,
      base.appendingPathExtension("store-shm"),
      base.appendingPathExtension("store-wal"),
    ]
    candidates.append(contentsOf: legacyStoreCandidates())
    for fileURL in candidates where fm.fileExists(atPath: fileURL.path) {
      try? fm.removeItem(at: fileURL)
    }
  }

  private static var persistentStoreURL: URL {
    let fm = FileManager.default
    let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let directory = appSupport.appendingPathComponent("Prisma", isDirectory: true)
    if !fm.fileExists(atPath: directory.path) {
      try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    return directory.appendingPathComponent("prisma.store")
  }

  private static func legacyStoreCandidates() -> [URL] {
    let fm = FileManager.default
    let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let legacyBase = appSupport.appendingPathComponent("default.store")
    let explicit = [
      legacyBase,
      legacyBase.deletingPathExtension().appendingPathExtension("store-wal"),
      legacyBase.deletingPathExtension().appendingPathExtension("store-shm"),
      appSupport.appendingPathComponent("default.sqlite"),
      appSupport.appendingPathComponent("default.sqlite-wal"),
      appSupport.appendingPathComponent("default.sqlite-shm"),
    ]
    return explicit
  }
}
