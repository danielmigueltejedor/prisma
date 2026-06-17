import Foundation

struct SimilarArticlesService {
  func related(to article: Article, from all: [Article], limit: Int = 8) -> [Article] {
    ArticleTopicMatcher.related(to: article, from: all, limit: limit)
  }

  func crossSourcePeers(for article: Article, from all: [Article], limit: Int = 6) -> [Article] {
    related(to: article, from: all, limit: limit * 2)
      .filter { $0.sourceId != article.sourceId }
      .prefix(limit)
      .map { $0 }
  }

  func aiRelated(
    to article: Article,
    from all: [Article],
    aiService: AIService,
    limit: Int = 8
  ) async throws -> [Article] {
    let prefiltered = ArticleTopicMatcher.related(to: article, from: all, limit: 24)
    guard !prefiltered.isEmpty else { return [] }

    let rankedIDs = try await aiService.rankSimilarArticles(
      anchor: article,
      candidates: prefiltered,
      limit: limit
    )
    let byID = Dictionary(uniqueKeysWithValues: prefiltered.map { ($0.id, $0) })
    let ranked = rankedIDs.compactMap { byID[$0] }
    if ranked.isEmpty {
      return Array(prefiltered.prefix(limit))
    }
    return ranked
  }
}
