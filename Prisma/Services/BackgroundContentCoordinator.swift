import BackgroundTasks
import Foundation
import UIKit

enum BackgroundTaskIdentifiers {
  static let appRefresh = "com.danielmigueltejedor.prisma.refresh"
  static let contentProcessing = "com.danielmigueltejedor.prisma.content-processing"

  static let all: [String] = [appRefresh, contentProcessing]
}

/// Prefetch gradual en segundo plano: feeds, traducciones, resúmenes, contexto y comparaciones.
@MainActor
final class BackgroundContentCoordinator {
  private static let articleFetchLimit = 120
  private static let candidateFetchLimit = 200
  private static let pauseBetweenStepsNs: UInt64 = 1_800_000_000
  private static let maxStepsPerUIBurst = 4
  private static let staleFeedInterval: TimeInterval = 30 * 60
  private static let processingRescheduleInterval: TimeInterval = 20 * 60

  private let feedService: FeedService
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let articleRepository: ArticleRepository
  private let translationService: ArticleTranslationService
  private let summaryService: ArticleSummaryService
  private let insightRepository: AIArticleInsightRepository
  private let aiService: AIService
  private let sharedRankingService: SharedArticleRankingService
  private let previewStore: ArticlePreviewTranslationStore
  private weak var backgroundWorkGate: AppBackgroundWorkGate?

  private var pipelineTask: Task<Void, Never>?
  private var uiBackgroundTaskID: UIBackgroundTaskIdentifier = .invalid
  private var cachedCandidates: [Article]?
  private var hasRegisteredTasks = false

  init(
    feedService: FeedService,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    articleRepository: ArticleRepository,
    translationService: ArticleTranslationService,
    summaryService: ArticleSummaryService,
    insightRepository: AIArticleInsightRepository,
    aiService: AIService,
    sharedRankingService: SharedArticleRankingService,
    previewStore: ArticlePreviewTranslationStore,
    backgroundWorkGate: AppBackgroundWorkGate? = nil
  ) {
    self.feedService = feedService
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.articleRepository = articleRepository
    self.translationService = translationService
    self.summaryService = summaryService
    self.insightRepository = insightRepository
    self.aiService = aiService
    self.sharedRankingService = sharedRankingService
    self.previewStore = previewStore
    self.backgroundWorkGate = backgroundWorkGate
  }

  func registerBackgroundTasks() {
    guard !hasRegisteredTasks else { return }
    hasRegisteredTasks = true

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: BackgroundTaskIdentifiers.appRefresh,
      using: nil
    ) { task in
      guard let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      Task { @MainActor in
        await self.handleAppRefreshTask(refreshTask)
      }
    }

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: BackgroundTaskIdentifiers.contentProcessing,
      using: nil
    ) { task in
      guard let processingTask = task as? BGProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }
      Task { @MainActor in
        await self.handleProcessingTask(processingTask)
      }
    }
  }

  func scheduleDeferredTasks() {
    scheduleAppRefresh()
    scheduleContentProcessing()
  }

  func handleMovedToBackground() {
    guard canRunBackgroundWork else { return }
    beginUIBackgroundTask()
    pipelineTask?.cancel()
    pipelineTask = Task(priority: .background) {
      await self.runPipeline(maxSteps: Self.maxStepsPerUIBurst, refreshFeeds: true)
      self.endUIBackgroundTask()
      self.scheduleDeferredTasks()
    }
  }

  func handleMovedToForeground() {
    pipelineTask?.cancel()
    endUIBackgroundTask()
  }

  func scheduleIdleWarmup() {
    guard canRunBackgroundWork else { return }
    pipelineTask?.cancel()
    pipelineTask = Task(priority: .utility) {
      try? await Task.sleep(nanoseconds: 6_000_000_000)
      guard !Task.isCancelled, self.canRunBackgroundWork else { return }
      await self.runPipeline(maxSteps: 3, refreshFeeds: false)
    }
  }

  func cancelPipeline() {
    pipelineTask?.cancel()
    pipelineTask = nil
  }

  // MARK: - BG tasks

  private func handleAppRefreshTask(_ task: BGAppRefreshTask) async {
    scheduleAppRefresh()

    let work = Task {
      await refreshFeedsIfStale()
      await runPipeline(maxSteps: 2, refreshFeeds: false)
    }

    task.expirationHandler = {
      work.cancel()
    }

    await work.value
    task.setTaskCompleted(success: !work.isCancelled)
    scheduleContentProcessing()
  }

  private func handleProcessingTask(_ task: BGProcessingTask) async {
    scheduleContentProcessing()

    let work = Task {
      await runPipeline(maxSteps: 1, refreshFeeds: false)
    }

    task.expirationHandler = {
      work.cancel()
    }

    await work.value
    task.setTaskCompleted(success: !work.isCancelled)
  }

  private func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifiers.appRefresh)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
  }

  private func scheduleContentProcessing() {
    let request = BGProcessingTaskRequest(identifier: BackgroundTaskIdentifiers.contentProcessing)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: Self.processingRescheduleInterval)
    try? BGTaskScheduler.shared.submit(request)
  }

  // MARK: - Pipeline

  private func runPipeline(maxSteps: Int, refreshFeeds: Bool) async {
    guard canRunBackgroundWork else { return }

    if refreshFeeds {
      await refreshFeedsIfStale()
      guard !Task.isCancelled else { return }
    }

    var completedSteps = 0
    while completedSteps < maxSteps, !Task.isCancelled, canRunBackgroundWork {
      if await translateOneIfNeeded() {
        completedSteps += 1
        await pauseBetweenSteps()
        continue
      }
      if await summarizeOneIfNeeded() {
        completedSteps += 1
        await pauseBetweenSteps()
        continue
      }
      if await generateContextOneIfNeeded() {
        completedSteps += 1
        await pauseBetweenSteps()
        continue
      }
      if await generateComparisonOneIfNeeded() {
        completedSteps += 1
        await pauseBetweenSteps()
        continue
      }
      break
    }

    if completedSteps > 0, let articles = try? articleRepository.fetchAll(limit: 40) {
      previewStore.mergeTranslations(for: articles)
    }
  }

  private func translateOneIfNeeded() async -> Bool {
    guard let article = await prioritizedArticles(missing: .translation).first else { return false }
    guard translationService.needsTranslation(for: article),
          translationService.cachedTranslation(for: article) == nil else { return false }
    guard await translationService.ensureTranslation(for: article) != nil else { return false }
    TranslationRefreshNotifier.publish()
    return true
  }

  private func summarizeOneIfNeeded() async -> Bool {
    guard let article = await prioritizedArticles(missing: .summary).first else { return false }
    guard summaryService.cachedSummary(for: article) == nil else { return false }
    if case .success = await summaryService.ensureSummary(for: article) {
      return true
    }
    return false
  }

  private func generateContextOneIfNeeded() async -> Bool {
    guard let article = await prioritizedArticles(missing: .context).first else { return false }
    do {
      let result = try await aiService.explainContext(article: article)
      let text = AITextFormatter.clean(result.explanation)
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
      _ = try insightRepository.save(articleId: article.id, kind: .context, text: text)
      return true
    } catch {
      return false
    }
  }

  private func generateComparisonOneIfNeeded() async -> Bool {
    guard let article = await prioritizedArticles(missing: .comparison).first else { return false }
    let candidates = candidateArticles()
    let anchor = ArticleMatchInput(article)
    let inputs = candidates.map(ArticleMatchInput.init)
    let peerIDs = ArticleTopicMatcher.sameStoryIDs(
      anchor: anchor,
      candidates: inputs,
      minimumScore: TopicCoverageService.sameStoryMinimumScore,
      limit: 6
    )
    guard peerIDs.count >= 2 else { return false }

    let verified = candidates.filter { peerIDs.contains($0.id) }
    do {
      let generated = try await aiService.compareSameStory(anchor: article, relatedArticles: verified)
      _ = try insightRepository.save(
        articleId: article.id,
        kind: .comparison,
        text: generated.comparisonText,
        relatedArticleIds: verified.map(\.id),
        unifiedStory: generated.unifiedStory
      )
      return true
    } catch {
      return false
    }
  }

  private enum MissingInsight {
    case translation
    case summary
    case context
    case comparison
  }

  private func prioritizedArticles(missing: MissingInsight) async -> [Article] {
    guard let ranked = try? await rankedArticles() else { return [] }
    switch missing {
    case .translation:
      return ranked.filter {
        translationService.needsTranslation(for: $0)
          && translationService.cachedTranslation(for: $0) == nil
      }
    case .summary:
      return ranked.filter { summaryService.cachedSummary(for: $0) == nil }
    case .context:
      return ranked.filter {
        (try? insightRepository.find(articleId: $0.id, kind: .context)) == nil
      }
    case .comparison:
      return ranked.filter {
        (try? insightRepository.find(articleId: $0.id, kind: .comparison)) == nil
      }
    }
  }

  private func rankedArticles() async throws -> [Article] {
    try await sharedRankingService.ranking(limit: Self.articleFetchLimit).ranked
  }

  private func candidateArticles() -> [Article] {
    if let cachedCandidates { return cachedCandidates }
    let fetched = (try? articleRepository.fetchAll(limit: Self.candidateFetchLimit)) ?? []
    cachedCandidates = fetched
    return fetched
  }

  private func refreshFeedsIfStale() async {
    let lastRefresh = try? preferenceRepository.getOrCreate().lastRefreshAt
    let isStale = lastRefresh.map { Date().timeIntervalSince($0) >= Self.staleFeedInterval } ?? false
    guard isStale else { return }
    _ = await feedService.refreshAllLenient()
    try? preferenceRepository.touchLastRefresh()
  }

  private var canRunBackgroundWork: Bool {
    guard AIServiceFactory.hasFreeOnDeviceAI else { return false }
    guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return false }
    guard backgroundWorkGate?.shouldDeferHeavyWork != true else { return false }
    return true
  }

  private func pauseBetweenSteps() async {
    try? await Task.sleep(nanoseconds: Self.pauseBetweenStepsNs)
    await Task.yield()
  }

  private func beginUIBackgroundTask() {
    endUIBackgroundTask()
    uiBackgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "PrismaBackgroundContent") {
      self.pipelineTask?.cancel()
      self.endUIBackgroundTask()
    }
  }

  private func endUIBackgroundTask() {
    guard uiBackgroundTaskID != .invalid else { return }
    UIApplication.shared.endBackgroundTask(uiBackgroundTaskID)
    uiBackgroundTaskID = .invalid
  }
}
