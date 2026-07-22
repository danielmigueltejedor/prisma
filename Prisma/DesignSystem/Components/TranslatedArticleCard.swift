import SwiftUI

struct TranslatedArticleCard: View, Equatable {
  let article: Article
  let previewStore: ArticlePreviewTranslationStore
  var recommendationReason: String? = nil

  static func == (lhs: TranslatedArticleCard, rhs: TranslatedArticleCard) -> Bool {
    lhs.article.id == rhs.article.id
      && lhs.article.isRead == rhs.article.isRead
      && lhs.article.isSaved == rhs.article.isSaved
      && lhs.article.isFavorite == rhs.article.isFavorite
      && lhs.article.likeCount == rhs.article.likeCount
      && lhs.article.viewCount == rhs.article.viewCount
      && lhs.previewStore.revision(for: lhs.article.id) == rhs.previewStore.revision(for: rhs.article.id)
      && lhs.recommendationReason == rhs.recommendationReason
  }

  var body: some View {
    let preview = previewStore.preview(for: article)
    ArticleCard(
      title: preview.title,
      sourceName: article.sourceName,
      publishedAt: article.publishedAt,
      summary: preview.summary,
      imageURL: article.resolvedImageURL,
      isRead: article.isRead,
      isSaved: article.isSaved,
      likeCount: article.likeCount,
      viewCount: article.viewCount,
      readingTimeMinutes: article.readingTimeEstimate,
      sourceSiteURL: article.feedSource?.siteURL,
      sourceFeedURL: article.originalFeedUrl,
      platform: article.feedSource?.effectivePlatform ?? .news,
      isLive: LiveCoverageDetector.isLiveArticle(article),
      recommendationReason: recommendationReason
    )
  }
}
