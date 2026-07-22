import Foundation

@MainActor
@Observable
final class ForYouViewModel {
  private static let articleFetchLimit = 200
  private static let rankingDebounceNanoseconds: UInt64 = 350_000_000
  private static let cascadeFeedLimit = 40
  private static let cascadeReaderCacheLimit = 2
  private static let cascadePreloadAhead = 1
  private static let rankingRefreshInterval: TimeInterval = 300

  var articles: [Article] = []
  var clusters: [ClusterDTO] = []
  var isLoadingRanking = false
  var dailyBriefing: DailyBriefingDTO?
  var errorMessage: String?
  var isRefreshingAIInBackground = false
  var isTabActive = false
  var cascadeFeedRefreshToken = 0

  var cascadeArticles: [Article] {
    !cascadePages.isEmpty ? cascadePages : articles
  }

  private(set) var cascadePages: [Article] = []

  private let articleRepository: ArticleRepository
  private let articleService: ArticleService
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let sharedRankingService: SharedArticleRankingService
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
  private var rankingInputsTask: Task<Void, Never>?
  private var cascadePreloadTask: Task<Void, Never>?
  private var cascadePrepareTask: Task<Void, Never>?
  private var cascadeScrollCommitTask: Task<Void, Never>?
  private var cascadeCompleteTask: Task<Void, Never>?
  private var cascadeOuterScrollActive = false
  private var pendingRankingCascadeSync = false
  private var aiLoadTask: Task<Void, Never>?
  private var tabActiveRankingTask: Task<Void, Never>?
  private var pendingTabReTapFollowUp = false
  private(set) var recommendationReasons: [String: RecommendationReason] = [:]

  init(
    articleRepository: ArticleRepository,
    articleService: ArticleService,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    sharedRankingService: SharedArticleRankingService,
    aiService: AIService
  ) {
    self.articleRepository = articleRepository
    self.articleService = articleService
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.sharedRankingService = sharedRankingService
    self.aiService = aiService

    if let diskCache = AIContentCacheStore.load() {
      Self.memoryCache = diskCache
      clusters = diskCache.clusters
      dailyBriefing = diskCache.briefing
    }
    reloadPreferences()
  }

  var hasOnDeviceAI: Bool { AIServiceFactory.hasFreeOnDeviceAI }

  var shouldShowAIContent: Bool {
    !clusters.isEmpty
  }

  func loadIfNeeded() {
    guard !hasLoadedData, isTabActive else { return }
    bootstrapFeed()
  }

  func tabDidBecomeActive() {
    isTabActive = true
    if !hasLoadedData {
      bootstrapFeed()
    } else {
      scheduleRankingRefreshIfStale()
    }
    if cascadeFeed.isEmpty, !articles.isEmpty {
      resetCascadeFeed()
    }
  }

  func tabDidBecomeInactive() {
    isTabActive = false
    cascadeOuterScrollActive = false
    tabActiveRankingTask?.cancel()
    aiLoadTask?.cancel()
    rankingTask?.cancel()
    rankingInputsTask?.cancel()
    cascadePreloadTask?.cancel()
    cascadePrepareTask?.cancel()
    cascadeScrollCommitTask?.cancel()
    cascadeCompleteTask?.cancel()
    isLoadingRanking = false
    cancelCascadeReaderWork(keeping: nil)
    flushDeferredCascadeWork()
  }

  func setCascadeOuterScrollActive(_ active: Bool) {
    cascadeOuterScrollActive = active
    if active {
      cascadeCompleteTask?.cancel()
      cascadeScrollCommitTask?.cancel()
    }
  }

  func cancelCascadeReaderWork(keeping articleID: String?) {
    for (id, reader) in cascadeReaderCache where id != articleID {
      reader.cancelBackgroundWork()
    }
  }

  private var shouldReloadRanking: Bool {
    guard let lastRankedAt else { return true }
    if articles.count != lastRankedArticleCount { return true }
    return Date().timeIntervalSince(lastRankedAt) > Self.rankingRefreshInterval
  }

  func handleFeedsRefreshed() {
    sharedRankingService.invalidate()
    guard !isTabActive else {
      pendingRankingCascadeSync = true
      return
    }
    invalidateRankingMetadataCache()
    reloadRankingOnly(force: true)
  }

  /// Pulsa de nuevo la pestaña Para ti: nuevo ranking y feed fresco (sin volver a lo ya visto en cascada).
  func refreshFromTabReTap() {
    isTabActive = true
    rankingInputsTask?.cancel()
    tabActiveRankingTask?.cancel()
    HapticFeedback.medium()
    pendingTabReTapFollowUp = true
    reloadRankingOnly(force: true)
  }

  private func applyTabReTapFollowUp() {
    guard pendingTabReTapFollowUp else { return }
    pendingTabReTapFollowUp = false
    pruneCascadeSeenKeepingReadArticles()
    resetCascadeFeed()
    cascadeFeedRefreshToken += 1
  }

  private func invalidateRankingMetadataCache() {
    sharedRankingService.invalidate()
  }

  private func pruneCascadeSeenKeepingReadArticles() {
    let knownArticles = Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
    var missingIDs = Set<String>()
    cascadeSeenIDs = Set(
      cascadeSeenIDs.filter { id in
        if let article = knownArticles[id] {
          return article.isRead
        }
        missingIDs.insert(id)
        return false
      }
    )
    if !missingIDs.isEmpty, let fetched = try? articleRepository.find(byIDs: missingIDs) {
      let readIDs = Set(fetched.filter(\.isRead).map(\.id))
      cascadeSeenIDs.formUnion(readIDs)
    }
    guard let prefs = try? preferenceRepository.getOrCreate() else { return }
    prefs.cascadeSeenArticleIDs = prefs.cascadeSeenArticleIDs.filter { cascadeSeenIDs.contains($0) }
    try? preferenceRepository.save()
  }

  func handleLibraryChanged() {
    sharedRankingService.invalidate()
    guard !isTabActive else { return }
    scheduleRankingRefresh()
  }

  func handlePreferencesChanged() {
    loadCascadeSeenIDs()
    if isTabActive {
      pendingRankingCascadeSync = true
      return
    }
    reloadRankingOnly()
  }

  func reload() {
    if !hasLoadedData {
      reloadRankingOnly(force: true)
      return
    }
    reloadRankingOnly(force: true)
  }

  private func bootstrapFeed() {
    reloadRankingOnly(force: true)
  }

  private func scheduleRankingRefreshIfStale() {
    tabActiveRankingTask?.cancel()
    guard shouldReloadRanking, !cascadeFeed.isEmpty else { return }
    tabActiveRankingTask = Task(priority: .utility) {
      try? await Task.sleep(nanoseconds: 3_000_000_000)
      guard !Task.isCancelled, isTabActive else { return }
      reloadRankingOnly()
    }
  }

  private func scheduleRankingRefresh() {
    guard !isTabActive else { return }
    rankingTask?.cancel()
    rankingTask = Task {
      try? await Task.sleep(nanoseconds: Self.rankingDebounceNanoseconds)
      guard !Task.isCancelled else { return }
      reloadRankingOnly()
    }
  }

  private func reloadRankingOnly(force: Bool = false) {
    if !force, !shouldReloadRanking, hasLoadedData { return }
    if !force, isTabActive, hasLoadedData { return }

    rankingInputsTask?.cancel()
    isLoadingRanking = true
    rankingInputsTask = Task(priority: .utility) {
      await Task.yield()
      defer { isLoadingRanking = false }
      guard !Task.isCancelled else { return }
      do {
        try await performRanking(force: force || !hasLoadedData)
        syncCascadeFeedAfterRanking()
        applyTabReTapFollowUp()
      } catch is CancellationError {
        return
      } catch {
        errorMessage = error.localizedDescription
        pendingTabReTapFollowUp = false
      }
    }
  }

  private func performRanking(force: Bool = false) async throws {
    try Task.checkCancellation()
    let snapshot = try await sharedRankingService.ranking(
      limit: Self.articleFetchLimit,
      force: force
    )
    try Task.checkCancellation()

    articles = snapshot.ranked
    var reasons: [String: RecommendationReason] = [:]
    for (index, article) in snapshot.ranked.prefix(30).enumerated() {
      guard let reason = RecommendationReasonBuilder.reason(
        for: article,
        rankIndex: index,
        favoriteSourceIds: snapshot.favoriteSourceIds,
        savedCategoryNames: snapshot.savedCategoryNames,
        interest: snapshot.interest
      ) else { continue }
      reasons[article.id] = reason
    }
    recommendationReasons = reasons
    lastRankedAt = .now
    lastRankedArticleCount = articles.count
    hasLoadedData = true
  }

  private func refreshAIIfNeeded() {
    guard shouldLoadAI, isTabActive, !articles.isEmpty else { return }

    let signature = aiSignature(from: articles)
    let cache = Self.memoryCache ?? AIContentCacheStore.load()

    if let cache, cache.signature == signature {
      applyCache(cache)
      Self.memoryCache = cache
      return
    }

    aiLoadTask?.cancel()
    aiLoadTask = Task(priority: .utility) { await loadAIContent(signature: signature) }
  }

  private var shouldLoadAI: Bool {
    hasOnDeviceAI
  }

  private func applyCache(_ cache: PersistedAICache) {
    clusters = cache.clusters
    dailyBriefing = cache.briefing
  }

  private func loadAIContent(signature: String) async {
    isRefreshingAIInBackground = true
    defer { isRefreshingAIInBackground = false }

    guard !articles.isEmpty else { return }

    do {
      let clusterInput = Array(articles.prefix(20))
      let rawClusters: [ClusterDTO] = try await withTimeout(seconds: 45) {
        try await self.aiService.clusterArticles(clusterInput)
      }
      guard !Task.isCancelled else { return }
      let sanitizedClusters = rawClusters.map { sanitize(cluster: $0) }

      let briefing = DailyBriefingDTO.from(clusters: sanitizedClusters)

      clusters = sanitizedClusters
      dailyBriefing = briefing

      let persisted = PersistedAICache(
        signature: signature,
        clusters: sanitizedClusters,
        briefing: briefing,
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

  func recommendationReason(for article: Article) -> String? {
    recommendationReasons[article.id]?.localized
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
    loadCascadeSeenIDs()
  }

  private func loadCascadeSeenIDs() {
    cascadeSeenIDs = Set((try? preferenceRepository.getOrCreate())?.cascadeSeenArticleIDs ?? [])
  }

  private func persistCascadeSeen(articleID: String, save: Bool = true) {
    cascadeSeenIDs.insert(articleID)
    guard let prefs = try? preferenceRepository.getOrCreate() else { return }
    if !prefs.cascadeSeenArticleIDs.contains(articleID) {
      prefs.cascadeSeenArticleIDs.append(articleID)
      if save {
        try? preferenceRepository.save()
      }
    }
  }

  private func isExcludedFromCascade(_ article: Article) -> Bool {
    article.isRead || cascadeSeenIDs.contains(article.id)
  }

  private func cascadeCandidatePool() -> [Article] {
    articles.filter { !isExcludedFromCascade($0) }
  }

  func activateCascadeReader(
    for article: Article,
    factory: (Article) -> ArticleReaderViewModel
  ) -> ArticleReaderViewModel {
    let reader: ArticleReaderViewModel
    if let cached = cascadeReaderCache[article.id] {
      reader = cached
    } else {
      reader = factory(article)
      cascadeReaderCache[article.id] = reader
      trimCascadeReaderCache(keeping: [article.id])
    }

    cascadePrepareTask?.cancel()
    cascadePrepareTask = Task(priority: .utility) { @MainActor in
      await Task.yield()
      guard !Task.isCancelled else { return }
      await reader.prepareForCascadeDisplayIfNeeded()
    }
    return reader
  }

  /// Legacy entry point — do not call from SwiftUI `body`.
  func cascadeReader(
    for article: Article,
    factory: (Article) -> ArticleReaderViewModel
  ) -> ArticleReaderViewModel {
    activateCascadeReader(for: article, factory: factory)
  }

  func preloadCascadeReaders(
    around articleID: String?,
    factory: ((Article) -> ArticleReaderViewModel)?
  ) {
    // Intentionally no-op: preparing readers during scroll caused main-thread stalls.
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

  func handleCascadeScrollChange(from oldID: String?, to newID: String?) {
    if let newID {
      beginCascadePage(articleID: newID)
    }

    cascadeScrollCommitTask?.cancel()
    guard let oldID, let newID, oldID != newID else { return }

    cascadeScrollCommitTask = Task(priority: .utility) {
      try? await Task.sleep(nanoseconds: 1_500_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        completeCascadePage(articleID: oldID)
      }
    }
  }

  func completeCascadePage(articleID: String) {
    guard !cascadeOuterScrollActive else { return }

    let dwell = cascadePageStartedAt.map { Date().timeIntervalSince($0) } ?? 0
    cascadePageStartedAt = nil
    let index = cascadeFeed.firstIndex { $0.id == articleID } ?? 0
    pendingCascadeRebuildIndex = index

    cascadeCompleteTask?.cancel()
    cascadeCompleteTask = Task(priority: .utility) {
      await Task.yield()
      guard !Task.isCancelled else { return }
      persistCascadeSeen(articleID: articleID, save: false)
      if dwell >= 2, let article = try? articleRepository.find(by: articleID) {
        try? articleService.markReadAndRecordDwell(article, seconds: dwell)
      }
      try? preferenceRepository.save()
    }
  }

  func handleCascadeLike(articleID: String) {
    pendingCascadeSimilarAnchorID = articleID
  }

  func handleCascadeSave(articleID: String) {
    pendingCascadeSimilarAnchorID = articleID
  }

  private func resetCascadeFeed() {
    loadCascadeSeenIDs()
    cascadeFeed = Array(cascadeCandidatePool().prefix(Self.cascadeFeedLimit))
    cascadePageStartedAt = nil
    pendingCascadeSimilarAnchorID = nil
    pendingCascadeRebuildIndex = nil
    cascadeReaderCache = [:]
    syncCascadePages()
  }

  private func syncCascadeFeedAfterRanking() {
    if isTabActive {
      pendingRankingCascadeSync = true
      return
    }
    applyCascadeFeedSyncAfterRanking()
  }

  private func applyCascadeFeedSyncAfterRanking() {
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

  private func flushDeferredCascadeWork() {
    if pendingRankingCascadeSync {
      pendingRankingCascadeSync = false
      invalidateRankingMetadataCache()
      reloadRankingOnly(force: true)
      return
    }
    guard let index = pendingCascadeRebuildIndex else { return }
    let anchorID = pendingCascadeSimilarAnchorID
    pendingCascadeRebuildIndex = nil
    pendingCascadeSimilarAnchorID = nil
    rebuildCascadeTail(from: index, injectSimilarTo: anchorID)
  }

  private func rebuildCascadeTail(from index: Int, injectSimilarTo anchorID: String?) {
    guard !cascadeFeed.isEmpty else { return }

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
    syncCascadePages()
  }

  private func syncCascadePages() {
    cascadePages = Array(cascadeFeed.prefix(Self.cascadeFeedLimit))
  }

  private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable @MainActor () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask { @MainActor in
        try await operation()
      }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        throw AIServiceError.notAvailable
      }
      guard let result = try await group.next() else {
        throw AIServiceError.notAvailable
      }
      group.cancelAll()
      return result
    }
  }
}
