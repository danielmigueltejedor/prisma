import Foundation

@MainActor
@Observable
final class TodayViewModel {
  var articles: [Article] = []
  var favoriteSourceArticles: [Article] = []
  var recentlySaved: [Article] = []
  var searchResults: [Article] = []
  var searchText = ""
  var showUnreadOnly = false
  var isLoading = false
  var errorMessage: String?

  private let articleService: ArticleService
  private let feedService: FeedService
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let searchService: SearchService

  init(
    articleService: ArticleService,
    feedService: FeedService,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    searchService: SearchService
  ) {
    self.articleService = articleService
    self.feedService = feedService
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.searchService = searchService
  }

  var displayedArticles: [Article] {
    let base = searchText.isEmpty ? articles : searchResults
    if showUnreadOnly {
      return base.filter { !$0.isRead }
    }
    return base
  }

  func load() {
    do {
      let prefs = try preferenceRepository.getOrCreate()
      let blockedSources = Set(try feedSourceRepository.fetchAll().filter(\.isBlocked).map(\.id))
      articles = try articleService.chronologicalFeed(
        blockedKeywords: prefs.blockedKeywords,
        blockedSourceIds: blockedSources,
        limit: 50
      )

      let favoriteIds = Set(try feedSourceRepository.fetchFavorites().map(\.id))
      favoriteSourceArticles = articles.filter { favoriteIds.contains($0.sourceId) }.prefix(10).map { $0 }
      recentlySaved = try articleService.chronologicalFeed(
        blockedKeywords: prefs.blockedKeywords,
        blockedSourceIds: blockedSources
      ).filter(\.isSaved).prefix(5).map { $0 }
      performSearch()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func performSearch() {
    guard !searchText.isEmpty else {
      searchResults = []
      return
    }
    searchResults = (try? searchService.search(query: searchText, unreadOnly: showUnreadOnly)) ?? []
  }

  func refresh() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      _ = try await feedService.refreshAll()
      load()
    } catch {
      errorMessage = error.localizedDescription
      load()
    }
  }
}
