import Foundation

struct SharedRankingResult {
  let ranked: [Article]
  let interest: ReadingInterestProfile
  let favoriteSourceIds: Set<UUID>
  let savedCategoryNames: Set<String>
  let fingerprint: String
}

/// Ranking compartido con TTL y coalescing para evitar recomputar en cada coordinador.
@MainActor
final class SharedArticleRankingService {
  private static let cacheTTL: TimeInterval = 300
  private static let defaultFetchLimit = 200

  private let articleRepository: ArticleRepository
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let recommendationEngine: RecommendationEngine

  private var cached: (result: SharedRankingResult, fetchedAt: Date)?
  private var inFlight: Task<SharedRankingResult, Error>?
  private var sourcesByIdCache: [UUID: FeedSource]?
  private var favoriteSourceIdsCache: Set<UUID>?
  private var blockedSourceIdsCache: Set<UUID>?

  init(
    articleRepository: ArticleRepository,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository,
    recommendationEngine: RecommendationEngine
  ) {
    self.articleRepository = articleRepository
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
    self.recommendationEngine = recommendationEngine
  }

  func invalidate() {
    cached = nil
    sourcesByIdCache = nil
    favoriteSourceIdsCache = nil
    blockedSourceIdsCache = nil
  }

  func ranking(limit: Int = defaultFetchLimit, force: Bool = false) async throws -> SharedRankingResult {
    if !force, let cached, !isStale(cached) {
      return cached.result
    }

    if let inFlight {
      return try await inFlight.value
    }

    let task = Task { @MainActor in
      try await computeRanking(limit: limit)
    }
    inFlight = task
    defer { inFlight = nil }

    let result = try await task.value
    cached = (result, .now)
    return result
  }

  /// Versión síncrona para callers que ya están en un Task de utilidad.
  func rankingSync(limit: Int = defaultFetchLimit, force: Bool = false) throws -> SharedRankingResult {
    if !force, let cached, !isStale(cached) {
      return cached.result
    }
    let result = try computeRankingSync(limit: limit)
    cached = (result, .now)
    return result
  }

  private func isStale(_ entry: (result: SharedRankingResult, fetchedAt: Date)) -> Bool {
    Date().timeIntervalSince(entry.fetchedAt) > Self.cacheTTL
  }

  private func computeRanking(limit: Int) async throws -> SharedRankingResult {
    await Task.yield()
    try Task.checkCancellation()
    return try computeRankingSync(limit: limit)
  }

  private func computeRankingSync(limit: Int) throws -> SharedRankingResult {
    let prefs = try preferenceRepository.getOrCreate()
    let all = try articleRepository.fetchAll(limit: limit)
    let sourcesById = try sourcesByIdCached()
    let favorites = try favoriteSourceIdsCached()
    let savedCategories = Set(all.filter(\.isSaved).flatMap(\.categoryNames))
    let blockedSources = try blockedSourceIdsCached()
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

    return SharedRankingResult(
      ranked: ranked,
      interest: interest,
      favoriteSourceIds: favorites,
      savedCategoryNames: savedCategories,
      fingerprint: Self.fingerprint(for: all)
    )
  }

  private func sourcesByIdCached() throws -> [UUID: FeedSource] {
    if let sourcesByIdCache { return sourcesByIdCache }
    let sources = try feedSourceRepository.fetchAll()
    let dict = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
    sourcesByIdCache = dict
    return dict
  }

  private func favoriteSourceIdsCached() throws -> Set<UUID> {
    if let favoriteSourceIdsCache { return favoriteSourceIdsCache }
    let ids = Set(try feedSourceRepository.fetchFavorites().map(\.id))
    favoriteSourceIdsCache = ids
    return ids
  }

  private func blockedSourceIdsCached() throws -> Set<UUID> {
    if let blockedSourceIdsCache { return blockedSourceIdsCache }
    let ids = try feedSourceRepository.fetchBlockedSourceIds()
    blockedSourceIdsCache = ids
    return ids
  }

  private static func fingerprint(for articles: [Article]) -> String {
    let head = articles.prefix(5).map(\.id).joined(separator: "|")
    return "\(articles.count)|\(head)"
  }
}
