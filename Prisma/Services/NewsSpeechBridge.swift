import Foundation

@MainActor
enum NewsSpeechBridge {
  private static weak var dependenciesStorage: AppDependencies?

  static var dependencies: AppDependencies? {
    get { dependenciesStorage }
    set { dependenciesStorage = newValue }
  }

  static func speakRecommendedArticles(limit: Int = 5) {
    guard let deps = dependenciesStorage else { return }
    let articles = rankedArticles(using: deps, limit: limit)
    guard !articles.isEmpty else { return }
    ArticleSpeechReader.shared.speakQueue(articles.map(ArticleSpeechContent.init(article:)))
  }

  static func speakArticle(id: String) {
    guard let deps = dependenciesStorage,
          let article = try? deps.articleRepository.find(by: id) else { return }
    ArticleSpeechReader.shared.speak(ArticleSpeechContent(article: article))
  }

  private static func rankedArticles(using deps: AppDependencies, limit: Int) -> [Article] {
    guard let all = try? deps.articleRepository.fetchAll(limit: 300) else { return [] }
    let favorites = Set((try? deps.feedSourceRepository.fetchFavorites().map(\.id)) ?? [])
    let savedCategories = Set(all.filter(\.isSaved).flatMap(\.categoryNames))
    let blockedSources = Set((try? deps.feedSourceRepository.fetchBlockedSourceIds()) ?? [])
    let readCounts = Dictionary(grouping: all.filter(\.isRead), by: \.sourceId).mapValues(\.count)
    let prefs = try? deps.preferenceRepository.getOrCreate()
    let sources = (try? deps.feedSourceRepository.fetchAll()) ?? []
    let sourcesById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
    let interest = ReadingInterestProfiler.build(
      from: all,
      favoriteSourceIds: favorites,
      sourcesById: sourcesById
    )

    return Array(
      deps.recommendationEngine.rank(
        articles: all,
        favoriteSourceIds: favorites,
        savedCategoryNames: savedCategories,
        readSourceCounts: readCounts,
        blockedKeywords: prefs?.blockedKeywords ?? [],
        blockedSourceIds: blockedSources,
        interest: interest
      )
      .prefix(limit)
    )
  }
}
