import Foundation

struct TopicCoverageService {
  static let sameStoryMinimumScore: Double = 42

  func crossSourceSameStory(
    for article: Article,
    from candidates: [Article],
    limit: Int = 6
  ) -> [Article] {
    candidates
      .filter { $0.id != article.id && $0.sourceId != article.sourceId }
      .map { ($0, ArticleTopicMatcher.sameStorySimilarity(between: article, and: $0)) }
      .filter { $0.1 >= Self.sameStoryMinimumScore }
      .sorted {
        if $0.1 == $1.1 {
          return ($0.0.publishedAt ?? .distantPast) > ($1.0.publishedAt ?? .distantPast)
        }
        return $0.1 > $1.1
      }
      .prefix(limit)
      .map(\.0)
  }
}
