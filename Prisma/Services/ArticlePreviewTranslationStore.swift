import Foundation

struct ArticlePreviewText: Equatable {
  let title: String
  let summary: String?
}

@MainActor
@Observable
final class ArticlePreviewTranslationStore {
  private let translationService: ArticleTranslationService
  private(set) var byArticleId: [String: ArticleTranslation] = [:]

  init(translationService: ArticleTranslationService) {
    self.translationService = translationService
  }

  func refresh(for articles: [Article]) {
    let ids = articles.map(\.id)
    guard ids != lastArticleIDs else { return }
    lastArticleIDs = ids
    byArticleId = translationService.cachedTranslations(for: articles)
  }

  func forceRefresh(for articles: [Article]) {
    lastArticleIDs = []
    refresh(for: articles)
  }

  private var lastArticleIDs: [String] = []

  func preview(for article: Article) -> ArticlePreviewText {
    translationService.previewDisplay(for: article, cache: byArticleId)
  }
}
