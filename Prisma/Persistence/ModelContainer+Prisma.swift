import SwiftData

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
    SubscriptionStatus.self,
    AIArticleSummary.self,
    NewsCluster.self,
  ])

  static func make(inMemory: Bool = false) throws -> ModelContainer {
    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: inMemory
    )
    return try ModelContainer(for: schema, configurations: [config])
  }
}
