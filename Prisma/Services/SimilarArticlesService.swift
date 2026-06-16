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
}
