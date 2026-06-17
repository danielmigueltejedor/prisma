import Foundation

@MainActor
@Observable
final class TodayViewModel {
  private static let minRefreshInterval: TimeInterval = 15 * 60
  private static let searchDebounceNanoseconds: UInt64 = 280_000_000

  var articles: [Article] = []
  var favoriteSourceArticles: [Article] = []
  var recentlySaved: [Article] = []
  var searchResults: [Article] = []
  var searchText = ""
  var selectedStyle = "Todas"
  var showUnreadOnly = false
  var isLoading = false
  var errorMessage: String?
  var weather: WeatherSnapshot?
  var scrollToTopToken = 0

  private let articleService: ArticleService
  private let feedService: FeedService
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let searchService: SearchService
  private let weatherService: WeatherService
  private var searchableTextByArticleId: [String: String] = [:]
  private var hasLoadedData = false
  private var searchTask: Task<Void, Never>?
  private(set) var dailyBriefing: DailyBriefingDTO? = AIContentCacheStore.load()?.briefing

  init(
    articleService: ArticleService,
    feedService: FeedService,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    searchService: SearchService,
    weatherService: WeatherService
  ) {
    self.articleService = articleService
    self.feedService = feedService
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.searchService = searchService
    self.weatherService = weatherService
  }

  func refreshBriefingCache() {
    dailyBriefing = AIContentCacheStore.load()?.briefing
  }

  var displayedArticles: [Article] {
    cachedDisplayedArticles
  }

  var styleFilters: [String] {
    cachedStyleFilters
  }

  var latestArticles: [Article] {
    cachedLatestArticles
  }

  private var cachedDisplayedArticles: [Article] = []
  private var cachedStyleFilters: [String] = ["Todas"]
  private var cachedLatestArticles: [Article] = []

  var isSearching: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func loadIfNeeded() {
    guard !hasLoadedData else { return }
    reload()
    Task { await loadWeather() }
  }

  func handleFeedsRefreshed() {
    reload()
    refreshBriefingCache()
  }

  /// Pulsa de nuevo la pestaña Hoy: vuelve arriba y recarga feeds.
  func refreshFromTabReTap() {
    HapticFeedback.medium()
    scrollToTopToken += 1
    Task { await refresh() }
  }

  func reload() {
    do {
      let prefs = try preferenceRepository.getOrCreate()
      let blockedSources = try feedSourceRepository.fetchBlockedSourceIds()
      articles = try articleService.chronologicalFeed(
        blockedKeywords: prefs.blockedKeywords,
        blockedSourceIds: blockedSources,
        limit: 50
      )
      searchableTextByArticleId = Dictionary(uniqueKeysWithValues: articles.map { article in
        let blob = [
          article.title,
          article.sourceName,
          article.authorName ?? "",
          article.displaySummary ?? "",
          article.categoryNames.joined(separator: " "),
        ].joined(separator: " ")
        return (article.id, normalized(blob))
      })

      let favoriteIds = Set(try feedSourceRepository.fetchFavorites().map(\.id))
      favoriteSourceArticles = articles.filter { favoriteIds.contains($0.sourceId) }.prefix(10).map { $0 }
      recentlySaved = articles.filter(\.isSaved).prefix(5).map { $0 }
      hasLoadedData = true
      performSearch()
      rebuildDisplayedCaches()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func scheduleSearch() {
    searchTask?.cancel()
    searchTask = Task {
      try? await Task.sleep(nanoseconds: Self.searchDebounceNanoseconds)
      guard !Task.isCancelled else { return }
      performSearch()
    }
  }

  func performSearch() {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      searchResults = []
      rebuildDisplayedCaches()
      return
    }
    do {
      var results = try searchService.search(query: trimmed, unreadOnly: showUnreadOnly)
      if selectedStyle != "Todas" {
        results = results.filter { ContentStyleFilter.style(for: $0) == selectedStyle }
      }
      searchResults = results
    } catch {
      searchResults = []
      errorMessage = error.localizedDescription
    }
    rebuildDisplayedCaches()
  }

  private func rebuildDisplayedCaches() {
    let base = searchText.isEmpty ? articles : searchResults
    cachedDisplayedArticles = base.filter { article in
      let matchesUnread = !showUnreadOnly || !article.isRead
      let matchesStyle = selectedStyle == "Todas" || ContentStyleFilter.style(for: article) == selectedStyle
      return matchesUnread && matchesStyle
    }

    let styles = Set(articles.map { ContentStyleFilter.style(for: $0) })
    let ordered = ContentStyleFilter.orderedStyles
    cachedStyleFilters = ["Todas"] + ordered.filter { styles.contains($0) }

    cachedLatestArticles = cachedDisplayedArticles
      .prefix(20)
      .map { $0 }
  }

  private func normalized(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
  }

  func refreshIfStale() async {
    guard shouldRefreshFeeds else { return }
    await refresh()
  }

  func refresh() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      _ = try await feedService.refreshAll()
      try? preferenceRepository.touchLastRefresh()
      reload()
      await loadWeather()
    } catch {
      errorMessage = error.localizedDescription
      reload()
    }
  }

  func loadWeather() async {
    let prefs = try? preferenceRepository.getOrCreate()
    let country = prefs?.homeCountry ?? NewsCountry.detected
    weather = try? await weatherService.currentWeather(
      for: country,
      locationQuery: prefs?.weatherLocationQuery
    )
  }

  private var shouldRefreshFeeds: Bool {
    guard let last = try? preferenceRepository.getOrCreate().lastRefreshAt else { return true }
    return Date().timeIntervalSince(last) >= Self.minRefreshInterval
  }
}
