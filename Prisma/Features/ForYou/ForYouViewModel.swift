import Foundation

@MainActor
@Observable
final class ForYouViewModel {
  private static let articleFetchLimit = 300
  private static let rankingDebounceNanoseconds: UInt64 = 350_000_000
  private static let cascadeFeedLimit = 40
  private static let cascadeReaderCacheLimit = 6
  private static let cascadePreloadAhead = 2

  var articles: [Article] = []
  var clusters: [ClusterDTO] = []
  var isLoadingAI = false
  var errorMessage: String?
  var isRefreshingAIInBackground = false
  var isTabActive = false
  var cascadeViewEnabled = false
  var cascadeFeedRefreshToken = 0
  var listFeedRefreshToken = 0

  var cascadeArticles: [Article] {
    cascadeViewEnabled && !cascadeFeed.isEmpty ? cascadeFeed : articles
  }

  private let articleRepository: ArticleRepository
  private let articleService: ArticleService
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let recommendationEngine: RecommendationEngine
  private let aiService: AIService
  private static var memoryCache: PersistedAICache?
  private var hasLoadedData = false
  private var rankingTask: Task<Void, Never>?
  private var cascadeFeed: [Article] = []
  private var cascadeSeenIDs: Set<String> = []
  private var cascadeReaderCache: [String: ArticleReaderViewModel] = [:]
  private var cascadePageStartedAt: Date?
  private var pendingCascadeSimilarAnchorID: String?
  private var pendingCascadeRebuildIndex: Int?
  private var lastRankedAt: Date?
  private var lastRankedArticleCount = 0
  private var cachedSourcesById: [UUID: FeedSource]?
  private var cachedFavoriteSourceIds: Set<UUID>?
  private var cachedBlockedSourceIds: Set<UUID>?
  private var rankingInputsTask: Task<Void, Never>?

  init(
    articleRepository: ArticleRepository,
    articleService: ArticleService,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    recommendationEngine: RecommendationEngine,
    aiService: AIService
  ) {
    self.articleRepository = articleRepository
    self.articleService = articleService
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.recommendationEngine = recommendationEngine
    self.aiService = aiService

    if let diskCache = AIContentCacheStore.load() {
      Self.memoryCache = diskCache
      clusters = diskCache.clusters
    }
    reloadPreferences()
  }

  var hasOnDeviceAI: Bool { AIServiceFactory.hasFreeOnDeviceAI }

  var shouldShowAIContent: Bool {
    !clusters.isEmpty
  }

  func loadIfNeeded() {
    guard !hasLoadedData else { return }
    reload()
  }

  func tabDidBecomeActive() {
    isTabActive = true
    if !hasLoadedData {
      reload()
    } else if shouldReloadRanking {
      reloadRankingOnly()
      refreshAIIfNeeded(forceWhenEmpty: false)
    }
    if cascadeViewEnabled, cascadeFeed.isEmpty, !articles.isEmpty {
      resetCascadeFeed()
    }
  }

  private var shouldReloadRanking: Bool {
    guard let lastRankedAt else { return true }
    if articles.count != lastRankedArticleCount { return true }
    return Date().timeIntervalSince(lastRankedAt) > 120
  }

  func handleFeedsRefreshed() {
    invalidateRankingMetadataCache()
    reloadRankingOnly(force: true)
    refreshAIIfNeeded(forceWhenEmpty: false)
  }

  /// Pulsa de nuevo la pestaña Para ti: nuevo ranking y feed fresco (sin volver a lo ya visto en cascada).
  func refreshFromTabReTap() {
    isTabActive = true
    rankingInputsTask?.cancel()
    do {
      try performRanking()
    } catch {
      errorMessage = error.localizedDescription
      return
    }
    if cascadeViewEnabled {
      pruneCascadeSeenKeepingReadArticles()
      resetCascadeFeed()
      cascadeFeedRefreshToken += 1
    } else {
      listFeedRefreshToken += 1
      refreshAIIfNeeded(forceWhenEmpty: false)
    }
  }

  private func invalidateRankingMetadataCache() {
    cachedSourcesById = nil
    cachedFavoriteSourceIds = nil
    cachedBlockedSourceIds = nil
  }

  private func pruneCascadeSeenKeepingReadArticles() {
    cascadeSeenIDs = Set(
      cascadeSeenIDs.filter { id in
        guard let article = try? articleRepository.find(by: id) else { return false }
        return article.isRead
      }
    )
    guard let prefs = try? preferenceRepository.getOrCreate() else { return }
    prefs.cascadeSeenArticleIDs = prefs.cascadeSeenArticleIDs.filter { id in
      guard let article = try? articleRepository.find(by: id) else { return false }
      return article.isRead
    }
    try? preferenceRepository.save()
  }

  func handleLibraryChanged() {
    if cascadeViewEnabled, isTabActive {
      syncCascadeReaderLibraryState()
      return
    }
    scheduleRankingRefresh()
  }

  private func syncCascadeReaderLibraryState() {
    for reader in cascadeReaderCache.values {
      reader.syncLibraryState()
    }
  }

  func handlePreferencesChanged() {
    reloadPreferences()
    if cascadeViewEnabled {
      reloadRankingOnly()
    } else {
      scheduleRankingRefresh()
    }
  }

  func reload() {
    reloadRankingOnly()
    refreshAIIfNeeded(forceWhenEmpty: true)
  }

  private func scheduleRankingRefresh() {
    rankingTask?.cancel()
    rankingTask = Task {
      try? await Task.sleep(nanoseconds: Self.rankingDebounceNanoseconds)
      guard !Task.isCancelled else { return }
      reloadRankingOnly()
      if !cascadeViewEnabled {
        refreshAIIfNeeded(forceWhenEmpty: false)
      }
    }
  }

  private func reloadRankingOnly(force: Bool = false) {
    if !force, !shouldReloadRanking, hasLoadedData { return }
    rankingInputsTask?.cancel()
    rankingInputsTask = Task(priority: .userInitiated) {
      await Task.yield()
      guard !Task.isCancelled else { return }
      do {
        try performRanking()
        if cascadeViewEnabled {
          syncCascadeFeedAfterRanking()
        }
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func performRanking() throws {
    let prefs = try preferenceRepository.getOrCreate()
    let all = try articleRepository.fetchAll(limit: Self.articleFetchLimit)
    let sourcesById = try sourcesByIdCached()
    let favorites = try favoriteSourceIdsCached()
    let savedCategories = Set(all.filter(\.isSaved).flatMap(\.categoryNames))
    let blockedSources = try blockedSourceIdsCached()
    let readCounts = Dictionary(grouping: all.filter(\.isRead), by: \.sourceId)
      .mapValues(\.count)
    let interest = ReadingInterestProfiler.build(
      from: all,
      favoriteSourceIds: favorites,
      sourcesById: sourcesById
    )

    articles = recommendationEngine.rank(
      articles: all,
      favoriteSourceIds: favorites,
      savedCategoryNames: savedCategories,
      readSourceCounts: readCounts,
      blockedKeywords: prefs.blockedKeywords,
      blockedSourceIds: blockedSources,
      interest: interest
    )
    lastRankedAt = .now
    lastRankedArticleCount = articles.count
    hasLoadedData = true
  }

  private func sourcesByIdCached() throws -> [UUID: FeedSource] {
    if let cachedSourcesById { return cachedSourcesById }
    let sources = try feedSourceRepository.fetchAll()
    let dict = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
    cachedSourcesById = dict
    return dict
  }

  private func favoriteSourceIdsCached() throws -> Set<UUID> {
    if let cachedFavoriteSourceIds { return cachedFavoriteSourceIds }
    let ids = Set(try feedSourceRepository.fetchFavorites().map(\.id))
    cachedFavoriteSourceIds = ids
    return ids
  }

  private func blockedSourceIdsCached() throws -> Set<UUID> {
    if let cachedBlockedSourceIds { return cachedBlockedSourceIds }
    let ids = try feedSourceRepository.fetchBlockedSourceIds()
    cachedBlockedSourceIds = ids
    return ids
  }

  private func refreshAIIfNeeded(forceWhenEmpty: Bool) {
    guard shouldLoadAI else { return }

    let signature = aiSignature(from: articles)
    let cache = Self.memoryCache ?? AIContentCacheStore.load()

    if let cache, cache.signature == signature {
      applyCache(cache)
      Self.memoryCache = cache
      guard isTabActive, AIContentCacheStore.shouldRefresh(cache: cache, signature: signature) else { return }
      Task(priority: .utility) { await loadAIContent(signature: signature, showLoading: false) }
      return
    }

    guard isTabActive || forceWhenEmpty else { return }
    let shouldShowLoading = forceWhenEmpty && clusters.isEmpty
    Task(priority: .utility) { await loadAIContent(signature: signature, showLoading: shouldShowLoading) }
  }

  private var shouldLoadAI: Bool {
    #if DEBUG
    return true
    #else
    return hasOnDeviceAI
    #endif
  }

  private func applyCache(_ cache: PersistedAICache) {
    clusters = cache.clusters
  }

  private func loadAIContent(signature: String, showLoading: Bool) async {
    if showLoading {
      isLoadingAI = true
    } else {
      isRefreshingAIInBackground = true
    }
    defer {
      isLoadingAI = false
      isRefreshingAIInBackground = false
    }

    do {
      let clusterInput = Array(articles.prefix(20))
      let rawClusters = try await aiService.clusterArticles(clusterInput)
      let sanitizedClusters = rawClusters.map(sanitize(cluster:))

      clusters = sanitizedClusters

      let persisted = PersistedAICache(
        signature: signature,
        clusters: sanitizedClusters,
        briefing: nil,
        generatedAt: .now
      )
      Self.memoryCache = persisted
      AIContentCacheStore.save(persisted)
    } catch {
      if clusters.isEmpty {
        errorMessage = error.localizedDescription
      }
    }
  }

  func articles(for cluster: ClusterDTO) -> [Article] {
    let ids = Set(cluster.articleIds)
    return articles.filter { ids.contains($0.id) }
  }

  private func sanitize(cluster: ClusterDTO) -> ClusterDTO {
    let title = AITextFormatter.clean(cluster.title)
    return ClusterDTO(
      id: cluster.id,
      title: title,
      summary: cluster.summary.map {
        AITextFormatter.bodyWithoutRepeatedHeadline(headline: title, body: AITextFormatter.clean($0))
      },
      articleIds: cluster.articleIds,
      comparisonNote: cluster.comparisonNote.map { AITextFormatter.clean($0) },
      synthesizedStory: cluster.synthesizedStory.map {
        AITextFormatter.bodyWithoutRepeatedHeadline(headline: title, body: AITextFormatter.clean($0))
      },
      sourceNames: cluster.sourceNames
    )
  }

  private func aiSignature(from rankedArticles: [Article]) -> String {
    rankedArticles
      .prefix(20)
      .map(\.id)
      .joined(separator: "|")
  }

  private func reloadPreferences() {
    let wasEnabled = cascadeViewEnabled
    cascadeViewEnabled = (try? preferenceRepository.getOrCreate())?.cascadeViewEnabled ?? false
    loadCascadeSeenIDs()
    if cascadeViewEnabled, !wasEnabled {
      resetCascadeFeed()
    }
    if !cascadeViewEnabled {
      cascadeFeed = []
      cascadeReaderCache = [:]
      cascadePageStartedAt = nil
      pendingCascadeSimilarAnchorID = nil
      pendingCascadeRebuildIndex = nil
    }
  }

  private func loadCascadeSeenIDs() {
    cascadeSeenIDs = Set((try? preferenceRepository.getOrCreate())?.cascadeSeenArticleIDs ?? [])
  }

  private func persistCascadeSeen(articleID: String) {
    cascadeSeenIDs.insert(articleID)
    guard let prefs = try? preferenceRepository.getOrCreate() else { return }
    if !prefs.cascadeSeenArticleIDs.contains(articleID) {
      prefs.cascadeSeenArticleIDs.append(articleID)
      try? preferenceRepository.save()
    }
  }

  private func isExcludedFromCascade(_ article: Article) -> Bool {
    article.isRead || cascadeSeenIDs.contains(article.id)
  }

  private func cascadeCandidatePool() -> [Article] {
    articles.filter { !isExcludedFromCascade($0) }
  }

  func cascadeReader(
    for article: Article,
    factory: (Article) -> ArticleReaderViewModel
  ) -> ArticleReaderViewModel {
    if let cached = cascadeReaderCache[article.id] {
      cached.syncLibraryState()
      return cached
    }
    let reader = factory(article)
    reader.prepareForCascadeDisplay()
    cascadeReaderCache[article.id] = reader
    return reader
  }

  func preloadCascadeReaders(
    around articleID: String?,
    factory: ((Article) -> ArticleReaderViewModel)?
  ) {
    guard cascadeViewEnabled, let factory else { return }
    guard let articleID,
          let centerIndex = cascadeFeed.firstIndex(where: { $0.id == articleID }) else {
      let head = cascadeFeed.prefix(Self.cascadePreloadAhead + 1)
      for article in head {
        warmCascadeReader(for: article, factory: factory)
      }
      trimCascadeReaderCache(keeping: head.map(\.id))
      return
    }

    let end = min(centerIndex + Self.cascadePreloadAhead, cascadeFeed.count - 1)
    let slice = cascadeFeed[centerIndex ... end]
    for article in slice {
      warmCascadeReader(for: article, factory: factory)
    }
    trimCascadeReaderCache(keeping: cascadeFeed[max(centerIndex - 1, 0) ... end].map(\.id))
  }

  private func warmCascadeReader(
    for article: Article,
    factory: (Article) -> ArticleReaderViewModel
  ) {
    guard cascadeReaderCache[article.id] == nil else { return }
    let reader = factory(article)
    reader.prepareForCascadeDisplay()
    cascadeReaderCache[article.id] = reader
  }

  private func trimCascadeReaderCache(keeping ids: [String]) {
    let keep = Set(ids)
    cascadeReaderCache = cascadeReaderCache.filter { keep.contains($0.key) }
    if cascadeReaderCache.count > Self.cascadeReaderCacheLimit {
      let allowed = Set(ids.suffix(Self.cascadeReaderCacheLimit))
      cascadeReaderCache = cascadeReaderCache.filter { allowed.contains($0.key) }
    }
  }

  // MARK: - Cascade training loop

  func beginCascadePage(articleID: String) {
    cascadePageStartedAt = Date()
  }

  func completeCascadePage(articleID: String) {
    guard cascadeViewEnabled else { return }

    let dwell = cascadePageStartedAt.map { Date().timeIntervalSince($0) } ?? 0
    cascadePageStartedAt = nil
    persistCascadeSeen(articleID: articleID)
    let index = cascadeFeed.firstIndex { $0.id == articleID } ?? 0
    pendingCascadeRebuildIndex = index

    if dwell >= 2, let article = try? articleRepository.find(by: articleID) {
      try? articleService.markRead(article)
      try? articleService.recordDwellTime(article, seconds: dwell)
    }

    let similarAnchor = pendingCascadeSimilarAnchorID
    rebuildCascadeTail(from: index, injectSimilarTo: similarAnchor)
    pendingCascadeRebuildIndex = nil
    pendingCascadeSimilarAnchorID = nil
  }

  func handleCascadeLike(articleID: String) {
    guard cascadeViewEnabled else { return }
    pendingCascadeSimilarAnchorID = articleID
  }

  func handleCascadeSave(articleID: String) {
    guard cascadeViewEnabled else { return }
  }

  private func resetCascadeFeed() {
    loadCascadeSeenIDs()
    cascadeFeed = Array(cascadeCandidatePool().prefix(Self.cascadeFeedLimit))
    cascadePageStartedAt = nil
    pendingCascadeSimilarAnchorID = nil
    pendingCascadeRebuildIndex = nil
    cascadeReaderCache = [:]
  }

  private func syncCascadeFeedAfterRanking() {
    if cascadeFeed.isEmpty {
      resetCascadeFeed()
      return
    }

    let index = pendingCascadeRebuildIndex
      ?? cascadeFeed.firstIndex(where: { !cascadeSeenIDs.contains($0.id) })
      ?? max(cascadeFeed.count - 1, 0)
    let anchorID = pendingCascadeSimilarAnchorID
    pendingCascadeRebuildIndex = nil
    pendingCascadeSimilarAnchorID = nil
    rebuildCascadeTail(from: index, injectSimilarTo: anchorID)
  }

  private func rebuildCascadeTail(from index: Int, injectSimilarTo anchorID: String?) {
    guard cascadeViewEnabled, !cascadeFeed.isEmpty else { return }

    let safeIndex = min(max(index, 0), max(cascadeFeed.count - 1, 0))
    var head = Array(cascadeFeed.prefix(safeIndex + 1))
    let headIDs = Set(head.map(\.id))

    var pool = cascadeCandidatePool().filter {
      !headIDs.contains($0.id)
    }

    if let anchorID,
       let anchor = head.first(where: { $0.id == anchorID }) ?? (try? articleRepository.find(by: anchorID)) {
      let similar = ArticleTopicMatcher.related(to: anchor, from: pool, limit: 4)
      for item in similar.reversed() {
        pool.removeAll { $0.id == item.id }
        pool.insert(item, at: 0)
      }
    }

    let remaining = max(Self.cascadeFeedLimit - head.count, 0)
    head.append(contentsOf: pool.prefix(remaining))
    cascadeFeed = head
  }
}
