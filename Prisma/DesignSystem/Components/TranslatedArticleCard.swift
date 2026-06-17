import SwiftUI

struct TranslatedArticleCard: View {
  let article: Article
  let previewStore: ArticlePreviewTranslationStore
  var recommendationReason: String? = nil

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
