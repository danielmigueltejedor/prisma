import Foundation

/// Traduce en segundo plano todos los artículos en idioma distinto al configurado,
/// priorizando inglés y el ranking de interés.
@MainActor
final class BackgroundTranslationCoordinator {
  private static let articleFetchLimit = 500
  private static let maxTranslationsPerSweep = 250
  private static let sweepCooldown: TimeInterval = 15

  private let articleRepository: ArticleRepository
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let translationService: ArticleTranslationService
  private let recommendationEngine: RecommendationEngine
  private let previewStore: ArticlePreviewTranslationStore

  private var sweepTask: Task<Void, Never>?
  private var lastSweepStartedAt: Date?

  init(
    articleRepository: ArticleRepository,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    translationService: ArticleTranslationService,
    recommendationEngine: RecommendationEngine,
    previewStore: ArticlePreviewTranslationStore
  ) {
    self.articleRepository = articleRepository
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.translationService = translationService
    self.recommendationEngine = recommendationEngine
    self.previewStore = previewStore
  }

  func scheduleSweep(priority: TaskPriority = .utility) {
    guard AIServiceFactory.hasFreeOnDeviceAI else { return }
    guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
    if let lastSweepStartedAt,
       Date().timeIntervalSince(lastSweepStartedAt) < Self.sweepCooldown {
      return
    }

    sweepTask?.cancel()
    sweepTask = Task(priority: priority) {
      defer { sweepTask = nil }
      await performSweep()
    }
  }

  private func performSweep() async {
    guard !Task.isCancelled else { return }
    lastSweepStartedAt = .now

    guard let candidates = try? prioritizedUntranslatedArticles() else { return }
    guard !candidates.isEmpty else { return }

    var translatedCount = 0
    for article in candidates {
      guard !Task.isCancelled else { return }
      guard translatedCount < Self.maxTranslationsPerSweep else { break }
      guard translationService.cachedTranslation(for: article) == nil else { continue }

      if await translationService.ensureTranslation(for: article) != nil {
        translatedCount += 1
        if translatedCount.isMultiple(of: 3) {
          TranslationRefreshNotifier.publish()
        }
      }
      await Task.yield()
    }

    if translatedCount > 0 {
      TranslationRefreshNotifier.publish()
      if let all = try? articleRepository.fetchAll(limit: Self.articleFetchLimit) {
        previewStore.forceRefresh(for: all)
      }
    }

    if translatedCount >= Self.maxTranslationsPerSweep,
       candidates.count > translatedCount {
      scheduleSweep(priority: .background)
    }
  }

  private func prioritizedUntranslatedArticles() throws -> [Article] {
    let prefs = try preferenceRepository.getOrCreate()
    let enabledSourceIds = Set(try feedSourceRepository.fetchEnabled().map(\.id))
    let all = try articleRepository.fetchAll(limit: Self.articleFetchLimit)
      .filter { enabledSourceIds.contains($0.sourceId) }

    let needing = all.filter { article in
      translationService.needsTranslation(for: article)
        && translationService.cachedTranslation(for: article) == nil
    }
    guard !needing.isEmpty else { return [] }

    let sources = try feedSourceRepository.fetchAll()
    let sourcesById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
    let favorites = Set(try feedSourceRepository.fetchFavorites().map(\.id))
    let blockedSources = try feedSourceRepository.fetchBlockedSourceIds()
    let savedCategories = Set(all.filter(\.isSaved).flatMap(\.categoryNames))
    let readCounts = Dictionary(grouping: all.filter(\.isRead), by: \.sourceId).mapValues(\.count)
    let interest = ReadingInterestProfiler.build(
      from: all,
      favoriteSourceIds: favorites,
      sourcesById: sourcesById
    )

    let ranked = recommendationEngine.rank(
      articles: all,
      favoriteSourceIds: favorites,
      savedCategoryNames: savedCategories,
      readSourceCounts: readCounts,
      blockedKeywords: prefs.blockedKeywords,
      blockedSourceIds: blockedSources,
      interest: interest
    )
    let rankByID = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($1.id, $0) })

    return needing.sorted { lhs, rhs in
      translationPriority(lhs, rankIndex: rankByID[lhs.id], favorites: favorites)
        > translationPriority(rhs, rankIndex: rankByID[rhs.id], favorites: favorites)
    }
  }

  private func translationPriority(
    _ article: Article,
    rankIndex: Int?,
    favorites: Set<UUID>
  ) -> Int {
    var score = 0
    if let rankIndex {
      score += max(0, 10_000 - rankIndex)
    }
    if isEnglish(article) {
      score += 8_000
    }
    if favorites.contains(article.sourceId) {
      score += 2_000
    }
    if article.isSaved {
      score += 1_500
    }
    if article.isFavorite {
      score += 1_200
    }
    if let publishedAt = article.publishedAt {
      let hours = max(0, -publishedAt.timeIntervalSinceNow / 3_600)
      score += Int(max(0, 720 - hours))
    }
    return score
  }

  private func isEnglish(_ article: Article) -> Bool {
    guard let code = ArticleLanguageDetector.detectLanguageCode(for: article) else { return false }
    return code.hasPrefix("en")
  }
}

@MainActor
enum TranslationRefreshNotifier {
  private static var debounceTask: Task<Void, Never>?

  static func publish() {
    debounceTask?.cancel()
    debounceTask = Task {
      try? await Task.sleep(nanoseconds: 350_000_000)
      guard !Task.isCancelled else { return }
      NotificationCenter.default.post(name: .articleTranslationsDidUpdate, object: nil)
    }
  }
}
