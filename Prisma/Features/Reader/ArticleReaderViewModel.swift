import Foundation
import SwiftUI

enum ReaderImpressionMode {
  /// Marca como leído al abrir (lector estándar).
  case standard
  /// Solo registra señal al salir; la cascada controla lectura y tiempo.
  case cascadeTraining
}

@MainActor
@Observable
final class ArticleReaderViewModel {
  private static let candidateFetchLimit = 80

  let article: Article

  var aiSummary: String?
  var comparisonText: String?
  var unifiedStory: String?
  var contextExplanation: String?
  var sameTopicArticles: [Article] = []
  var verifiedSameStoryArticles: [Article] = []
  var similarArticles: [Article] = []
  var similarArticlesPoweredByAI = false
  var isLoadingAISimilarArticles = false
  var showingSummary = false
  var showingComparison = false
  var showingContext = false
  var isGeneratingSummary = false
  var isGeneratingComparison = false
  var isGeneratingContext = false
  var errorMessage: String?

  var translation: ArticleTranslation?
  var isTranslating = false
  var showingOriginal = false
  var isSaved = false
  var isFavorite = false
  var readerFontFamily: ReaderFontFamily = .serif
  var readerFontSizeMultiplier: Double = 1.0
  var redditComments: [RedditComment] = []
  var isLoadingRedditComments = false
  var redditCommentsError: String?
  var liveEntries: [LiveTimelineEntry] = []
  var isRefreshingLive = false
  var liveLastUpdated: Date?

  var mediaItems: [ArticleMediaItem] = []

  var imageURLs: [URL] {
    mediaItems.compactMap { item in
      switch item {
      case .image(let url):
        return url
      case .video(_, let thumbnail):
        return thumbnail
      }
    }
  }

  private let articleService: ArticleService
  private let articleRepository: ArticleRepository
  private let aiService: AIService
  private let feedSourceRepository: FeedSourceRepository
  private let feedService: FeedService?
  private let preferenceRepository: PreferenceRepository
  private let translationService: ArticleTranslationService
  private let redditCommentsService: RedditCommentsService
  private let redditCommentsTranslationService: RedditCommentsTranslationService
  private let summaryService: ArticleSummaryService
  private let insightRepository: AIArticleInsightRepository
  private var hasMarkedRead = false
  private var hasLoadedSimilar = false
  private var hasLoadedRedditComments = false
  private var hasStartedComparisonPrefetch = false
  private var hasStartedContextPrefetch = false
  private var hasStartedSummaryPrefetch = false
  private var cachedVerifiedPeerIDs: [String] = []
  private var readerTasks: [Task<Void, Never>] = []
  private var openedAt: Date?
  private var cachedOriginalBodyHTML: String?
  private var cachedPlainBodyText: String?
  private var cachedCandidateArticles: [Article]?
  private var cachedResolvedSource: FeedSource?
  private var hasPreparedPresentation = false
  private var liveRefreshTask: Task<Void, Never>?
  private let impressionMode: ReaderImpressionMode

  init(
    article: Article,
    articleService: ArticleService,
    articleRepository: ArticleRepository,
    aiService: AIService,
    feedSourceRepository: FeedSourceRepository,
    feedService: FeedService? = nil,
    preferenceRepository: PreferenceRepository,
    translationService: ArticleTranslationService,
    redditCommentsService: RedditCommentsService,
    redditCommentsTranslationService: RedditCommentsTranslationService,
    summaryService: ArticleSummaryService,
    insightRepository: AIArticleInsightRepository,
    impressionMode: ReaderImpressionMode = .standard
  ) {
    self.article = article
    self.impressionMode = impressionMode
    self.articleService = articleService
    self.articleRepository = articleRepository
    self.aiService = aiService
    self.feedSourceRepository = feedSourceRepository
    self.feedService = feedService
    self.preferenceRepository = preferenceRepository
    self.translationService = translationService
    self.redditCommentsService = redditCommentsService
    self.redditCommentsTranslationService = redditCommentsTranslationService
    self.summaryService = summaryService
    self.insightRepository = insightRepository
    self.isSaved = article.isSaved
    self.isFavorite = article.isFavorite
    self.cachedResolvedSource = article.feedSource

    if let preferences = try? preferenceRepository.getOrCreate() {
      readerFontFamily = preferences.readerFontFamily
      readerFontSizeMultiplier = preferences.readerFontSizeMultiplier
    }

    if impressionMode == .cascadeTraining {
      return
    }

    cachedOriginalBodyHTML = Self.resolveOriginalBodyHTML(for: article)
    cachedPlainBodyText = cachedOriginalBodyHTML.flatMap { HTMLSanitizer.stripHTML($0) }
    if cachedOriginalBodyHTML != nil {
      hasPreparedPresentation = true
    }

    if let cached = summaryService.cachedSummary(for: article) {
      let cleaned = AITextFormatter.clean(cached.summary)
      if !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        aiSummary = cleaned
      }
    }
    if let cachedComparison = try? insightRepository.find(articleId: article.id, kind: .comparison) {
      comparisonText = AITextFormatter.clean(cachedComparison.text)
      if let unified = cachedComparison.unifiedStoryText, !unified.isEmpty {
        unifiedStory = AITextFormatter.clean(unified)
      }
      cachedVerifiedPeerIDs = cachedComparison.relatedArticleIds
    }
    if let cachedContext = try? insightRepository.find(articleId: article.id, kind: .context) {
      contextExplanation = AITextFormatter.clean(cachedContext.text)
    }
    if translationService.needsTranslation(for: article),
       let cached = translationService.cachedTranslation(for: article) {
      translation = cached
    }
  }

  var hasOnDeviceAI: Bool { AIServiceFactory.hasFreeOnDeviceAI }

  var canUseAI: Bool {
    #if DEBUG
    return true
    #else
    return hasOnDeviceAI
    #endif
  }

  var hasSummaryAvailable: Bool {
    guard let aiSummary else { return false }
    return !aiSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var shouldShowSummaryPreparing: Bool {
    canUseAI && !hasSummaryAvailable && (isGeneratingSummary || hasStartedSummaryPrefetch)
  }

  var hasComparisonAvailable: Bool {
    guard comparisonText != nil else { return false }
    return !verifiedSameStoryArticles.isEmpty || !cachedVerifiedPeerIDs.isEmpty
  }

  var hasContextAvailable: Bool {
    contextExplanation != nil
  }

  var hasSameTopicCoverage: Bool {
    !sameTopicArticles.isEmpty
  }

  var sameTopicSourceNames: [String] {
    Array(Set(verifiedSameStoryArticles.map(\.sourceName))).sorted()
  }

  var resolvedSource: FeedSource? {
    cachedResolvedSource ?? article.feedSource
  }

  var isRedditPost: Bool {
    if isLiveCoverage { return false }
    if let platform = resolvedSource?.platform {
      return platform == .reddit
    }
    return FeedPlatform.detect(
      feedURL: article.originalFeedUrl,
      siteURL: article.feedSource?.siteURL
    ) == .reddit
  }

  var isLiveCoverage: Bool {
    LiveCoverageDetector.hasActiveLiveTimeline(article)
  }

  var showsNativeLiveTimeline: Bool {
    liveEntries.count >= 2
  }

  var needsTranslation: Bool {
    translationService.needsTranslation(for: article)
  }

  var hasTranslation: Bool {
    translation != nil
  }

  var isShowingTranslation: Bool {
    hasTranslation && !showingOriginal
  }

  var targetLanguageName: String {
    ReadingLanguage.displayName(for: translationService.targetLanguageCode)
  }

  var displayTitle: String {
    if isShowingTranslation, let translation {
      return translation.translatedTitle
    }
    return article.title
  }

  var bodyHTML: String? {
    if isShowingTranslation, let translation {
      return translatedHTML(from: translation.translatedBody)
    }
    return originalBodyHTML
  }

  var originalBodyHTML: String? {
    cachedOriginalBodyHTML
  }

  var plainBodyText: String? {
    if isShowingTranslation, let translation {
      return translation.translatedBody
    }
    return cachedPlainBodyText
  }

  var hasReadableInAppContent: Bool {
    if isShowingTranslation, let translation {
      return !translation.translatedBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    guard let plain = cachedPlainBodyText else { return false }
    return plain.count >= 80 || article.contentAvailability == .fullRSS
  }

  var needsPartialNotice: Bool {
    !isShowingTranslation && hasReadableInAppContent && article.contentAvailability != .fullRSS
  }

  func setReaderFontFamily(_ family: ReaderFontFamily) {
    readerFontFamily = family
    guard let preferences = try? preferenceRepository.getOrCreate() else { return }
    preferences.readerFontFamily = family
    try? preferenceRepository.save()
  }

  func setReaderFontSizeMultiplier(_ multiplier: Double) {
    let clamped = min(max(multiplier, 0.8), 1.6)
    readerFontSizeMultiplier = clamped
    guard let preferences = try? preferenceRepository.getOrCreate() else { return }
    preferences.readerFontSizeMultiplier = clamped
    try? preferenceRepository.save()
  }

  func onAppear() {
    openedAt = Date()
    loadCachedTranslationIfNeeded()

    if impressionMode == .cascadeTraining {
      prepareForCascadeDisplay()
      if needsTranslation, translation == nil {
        enqueueReaderTask(priority: .utility) {
          await self.prepareTranslation()
        }
      }
      if isLiveCoverage {
        reloadLiveEntries()
      }
      return
    }

    if impressionMode == .standard, !hasPreparedPresentation {
      hasPreparedPresentation = true
      enqueueReaderTask(priority: .userInitiated) {
        await self.prepareArticlePresentation()
      }
    }

    if needsTranslation, translation == nil {
      enqueueReaderTask(priority: .utility) {
        await self.prepareTranslation()
      }
    }

    if canUseAI, !hasSummaryAvailable, !hasStartedSummaryPrefetch {
      hasStartedSummaryPrefetch = true
      enqueueReaderTask(priority: .utility) {
        await self.prefetchSummaryIfNeeded()
      }
    }

    if !hasLoadedSimilar {
      hasLoadedSimilar = true
      enqueueReaderTask(priority: .utility) {
        await self.loadRelatedContentInBackground()
      }
    }

    reloadLiveEntries()
    startLiveRefreshIfNeeded()
  }

  func onDisappear() {
    if impressionMode == .cascadeTraining {
      stopLiveRefresh()
      openedAt = nil
      return
    }

    stopLiveRefresh()
    readerTasks.forEach { $0.cancel() }
    readerTasks.removeAll()

    guard impressionMode == .standard, let openedAt else {
      self.openedAt = nil
      return
    }
    let seconds = Date().timeIntervalSince(openedAt)
    if seconds >= 2, !hasMarkedRead {
      hasMarkedRead = true
      try? articleService.markRead(article)
    }
    try? articleService.recordDwellTime(article, seconds: seconds)
    self.openedAt = nil
  }

  func toggleTranslationView() {
    showingOriginal.toggle()
  }

  func prefetchSummaryIfNeeded() async {
    guard canUseAI, !hasSummaryAvailable else { return }
    guard !isGeneratingSummary else { return }

    isGeneratingSummary = true
    defer { isGeneratingSummary = false }

    if let saved = await summaryService.ensureSummary(for: article) {
      let cleaned = AITextFormatter.clean(saved.summary)
      guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
      aiSummary = cleaned
    }
  }

  func prefetchComparisonIfNeeded() async {
    guard canUseAI, comparisonText == nil else { return }
    guard !isGeneratingComparison else { return }

    let localCandidates = sameTopicArticles
    guard !localCandidates.isEmpty else { return }

    isGeneratingComparison = true
    errorMessage = nil
    defer { isGeneratingComparison = false }

    do {
      let verifiedIDs = try await aiService.filterSameStoryArticleIDs(
        anchor: article,
        candidates: localCandidates
      )
      let verified = localCandidates.filter { verifiedIDs.contains($0.id) }
      verifiedSameStoryArticles = verified

      guard !verified.isEmpty else {
        comparisonText = nil
        unifiedStory = nil
        return
      }

      let generated = try await aiService.compareSameStory(anchor: article, relatedArticles: verified)
      comparisonText = AITextFormatter.clean(generated.comparisonText)
      unifiedStory = AITextFormatter.clean(generated.unifiedStory)
      cachedVerifiedPeerIDs = verified.map(\.id)
      _ = try? insightRepository.save(
        articleId: article.id,
        kind: .comparison,
        text: generated.comparisonText,
        relatedArticleIds: verified.map(\.id),
        unifiedStory: generated.unifiedStory
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func prefetchContextIfNeeded() async {
    guard canUseAI, contextExplanation == nil else { return }
    guard !isGeneratingContext else { return }

    isGeneratingContext = true
    errorMessage = nil
    defer { isGeneratingContext = false }

    do {
      let result = try await aiService.explainContext(article: article)
      let generated = AITextFormatter.clean(result.explanation)
      contextExplanation = generated
      _ = try? insightRepository.save(articleId: article.id, kind: .context, text: generated)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func prepareTranslation() async {
    guard needsTranslation else { return }

    if let cached = translationService.cachedTranslation(for: article) {
      translation = cached
      return
    }

    isTranslating = true
    defer { isTranslating = false }

    if let result = await translationService.ensureTranslation(for: article) {
      translation = result
    }
  }

  func explainContext() async {
    await prefetchContextIfNeeded()
  }

  func scheduleRedditCommentsIfNeeded() {
    guard isRedditPost, !hasLoadedRedditComments else { return }
    enqueueReaderTask(priority: .utility) {
      await self.loadRedditCommentsIfNeeded()
    }
  }

  func loadRedditCommentsIfNeeded() async {
    guard isRedditPost, !hasLoadedRedditComments else { return }
    hasLoadedRedditComments = true
    isLoadingRedditComments = true
    redditCommentsError = nil
    defer { isLoadingRedditComments = false }

    guard !Task.isCancelled else { return }

    do {
      let fetched = try await redditCommentsService.fetchComments(for: article)
      redditComments = await redditCommentsTranslationService.translatedComments(
        for: article,
        comments: fetched
      )
    } catch {
      redditCommentsError = error.localizedDescription
    }
  }

  func refreshLiveTimeline() async {
    guard isLiveCoverage, let feedService, let source = resolvedSource else { return }
    guard !isRefreshingLive else { return }

    isRefreshingLive = true
    defer { isRefreshingLive = false }

    _ = try? await feedService.refresh(source: source)
    reloadLiveEntries()
    liveLastUpdated = .now
  }

  private func reloadLiveEntries() {
    liveEntries = LiveTimelineService.entries(for: article)
    if liveLastUpdated == nil {
      liveLastUpdated = article.updatedAt ?? article.publishedAt
    }
  }

  private func startLiveRefreshIfNeeded() {
    guard isLiveCoverage, feedService != nil else { return }
    liveRefreshTask?.cancel()
    liveRefreshTask = Task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 45_000_000_000)
        guard !Task.isCancelled else { return }
        await refreshLiveTimeline()
      }
    }
  }

  private func stopLiveRefresh() {
    liveRefreshTask?.cancel()
    liveRefreshTask = nil
  }

  func toggleSaved() {
    try? articleService.toggleSaved(article)
    isSaved = article.isSaved
  }

  func toggleFavorite() {
    try? articleService.toggleFavorite(article)
    isFavorite = article.isFavorite
  }

  func syncLibraryState() {
    isSaved = article.isSaved
    isFavorite = article.isFavorite
  }

  /// Prepara título, cuerpo e imágenes de forma síncrona para la cascada.
  func prepareForCascadeDisplay() {
    if cachedOriginalBodyHTML == nil {
      cachedOriginalBodyHTML = Self.resolveOriginalBodyHTML(for: article)
      cachedPlainBodyText = cachedOriginalBodyHTML.flatMap { HTMLSanitizer.stripHTML($0) }
    }
    if mediaItems.isEmpty {
      mediaItems = ArticleMediaExtractor.mediaItems(for: article)
    }
    if cachedResolvedSource == nil {
      cachedResolvedSource = try? feedSourceRepository.find(by: article.sourceId)
    }
    if isLiveCoverage {
      reloadLiveEntries()
    }
    hasPreparedPresentation = true
  }

  func likeFromCascade() {
    guard !article.isFavorite else { return }
    try? articleService.toggleFavorite(article)
    isFavorite = article.isFavorite
  }

  private func loadCachedTranslationIfNeeded() {
    guard translation == nil, needsTranslation else { return }
    if let cached = translationService.cachedTranslation(for: article) {
      translation = cached
    }
  }

  private func enqueueReaderTask(
    priority: TaskPriority = .utility,
    _ operation: @escaping @Sendable () async -> Void
  ) {
    let task = Task(priority: priority) {
      await operation()
    }
    readerTasks.append(task)
  }

  private func loadRelatedContentInBackground() async {
    await Task.yield()
    guard !Task.isCancelled else { return }

    guard let candidates = try? articleRepository.fetchAll(limit: Self.candidateFetchLimit) else { return }
    guard !Task.isCancelled else { return }

    let anchor = ArticleMatchInput(article)
    let inputs = candidates.map(ArticleMatchInput.init)
    let minimumPeerScore = TopicCoverageService.sameStoryMinimumScore

    let matchResult = await Task.detached(priority: .utility) {
      (
        ArticleTopicMatcher.relatedIDs(anchor: anchor, candidates: inputs, limit: 8),
        ArticleTopicMatcher.sameStoryIDs(
          anchor: anchor,
          candidates: inputs,
          minimumScore: minimumPeerScore,
          limit: 6
        )
      )
    }.value

    guard !Task.isCancelled else { return }

    let similarOrder = Dictionary(uniqueKeysWithValues: matchResult.0.enumerated().map { ($1, $0) })
    let peerOrder = Dictionary(uniqueKeysWithValues: matchResult.1.enumerated().map { ($1, $0) })

    cachedCandidateArticles = candidates
    similarArticles = candidates
      .filter { similarOrder[$0.id] != nil }
      .sorted { (similarOrder[$0.id] ?? 0) < (similarOrder[$1.id] ?? 0) }
    sameTopicArticles = candidates
      .filter { peerOrder[$0.id] != nil }
      .sorted { (peerOrder[$0.id] ?? 0) < (peerOrder[$1.id] ?? 0) }
    similarArticlesPoweredByAI = false
    hydrateVerifiedPeers(from: candidates)

    guard canUseAI else { return }

    isLoadingAISimilarArticles = true
    let similarService = SimilarArticlesService()
    if let aiRanked = try? await similarService.aiRelated(
      to: article,
      from: candidates,
      aiService: aiService,
      limit: 8
    ), !aiRanked.isEmpty {
      similarArticles = aiRanked
      similarArticlesPoweredByAI = true
    }
    isLoadingAISimilarArticles = false

    try? await Task.sleep(nanoseconds: 1_500_000_000)
    guard !Task.isCancelled else { return }

    if !hasStartedContextPrefetch {
      hasStartedContextPrefetch = true
      await prefetchContextIfNeeded()
    }

    guard !sameTopicArticles.isEmpty, !hasStartedComparisonPrefetch else { return }

    try? await Task.sleep(nanoseconds: 2_000_000_000)
    guard !Task.isCancelled else { return }

    hasStartedComparisonPrefetch = true
    await prefetchComparisonIfNeeded()
  }

  private func prepareArticlePresentation() async {
    await Task.yield()
    guard !Task.isCancelled else { return }

    if cachedOriginalBodyHTML == nil {
      cachedOriginalBodyHTML = Self.resolveOriginalBodyHTML(for: article)
      cachedPlainBodyText = cachedOriginalBodyHTML.flatMap { HTMLSanitizer.stripHTML($0) }
    }

    reloadLiveEntries()

    if mediaItems.isEmpty {
      mediaItems = ArticleMediaExtractor.mediaItems(for: article)
    }
    await Task.yield()
    guard !Task.isCancelled else { return }

    if cachedResolvedSource == nil {
      cachedResolvedSource = try? feedSourceRepository.find(by: article.sourceId)
    }
  }

  private func hydrateVerifiedPeers(from candidates: [Article]) {
    guard verifiedSameStoryArticles.isEmpty, !cachedVerifiedPeerIDs.isEmpty else { return }
    verifiedSameStoryArticles = candidates.filter { cachedVerifiedPeerIDs.contains($0.id) }
  }

  private func candidateArticles() -> [Article] {
    if let cachedCandidateArticles { return cachedCandidateArticles }
    let fetched = (try? articleRepository.fetchAll(limit: Self.candidateFetchLimit)) ?? []
    cachedCandidateArticles = fetched
    return fetched
  }

  private static func resolveOriginalBodyHTML(for article: Article) -> String? {
    for html in [article.content, article.summary] {
      guard let html, !html.isEmpty else { continue }
      let plain = HTMLSanitizer.stripHTML(html) ?? ""
      if !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return html
      }
    }
    return nil
  }

  private func translatedHTML(from plainText: String) -> String {
    plainText
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .map { "<p>\(Self.escapeHTML($0))</p>" }
      .joined()
  }

  private static func escapeHTML(_ text: String) -> String {
    text
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}
