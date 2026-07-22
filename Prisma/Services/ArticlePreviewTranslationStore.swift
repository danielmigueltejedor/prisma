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
  private(set) var revisionToken = 0
  private var revisionByArticleId: [String: Int] = [:]
  private var lastArticleIDs: [String] = []

  init(translationService: ArticleTranslationService) {
    self.translationService = translationService
  }

  func revision(for articleID: String) -> Int {
    revisionByArticleId[articleID, default: 0]
  }

  func refresh(for articles: [Article]) {
    let ids = articles.map(\.id)
    guard ids != lastArticleIDs else { return }
    lastArticleIDs = ids
    mergeTranslations(for: articles)
  }

  func forceRefresh(for articles: [Article]) {
    lastArticleIDs = []
    refresh(for: articles)
  }

  func mergeTranslations(for articles: [Article]) {
    let translations = translationService.cachedTranslations(for: articles)
    var changed = false
    for article in articles {
      let id = article.id
      let next = translations[id]
      let previous = byArticleId[id]
      let titleChanged = previous?.translatedTitle != next?.translatedTitle
      if titleChanged || (previous == nil) != (next == nil) {
        byArticleId[id] = next
        revisionByArticleId[id, default: 0] += 1
        changed = true
      }
    }
    if changed {
      revisionToken += 1
    }
  }

  func preview(for article: Article) -> ArticlePreviewText {
    translationService.previewDisplay(for: article, cache: byArticleId)
  }
}
