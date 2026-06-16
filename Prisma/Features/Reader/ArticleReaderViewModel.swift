import Foundation
import SwiftUI

@MainActor
@Observable
final class ArticleReaderViewModel {
  let article: Article

  var aiSummary: String?
  var comparisonText: String?
  var contextExplanation: String?
  var similarArticles: [Article] = []
  var isLoadingAI = false
  var errorMessage: String?

  private let articleService: ArticleService
  private let articleRepository: ArticleRepository
  private let aiService: AIService
  private let plusGate: PrismaPlusGatekeeper
  private let feedSourceRepository: FeedSourceRepository
  private let preferenceRepository: PreferenceRepository
  private let similarArticlesService = SimilarArticlesService()

  init(
    article: Article,
    articleService: ArticleService,
    articleRepository: ArticleRepository,
    aiService: AIService,
    plusGate: PrismaPlusGatekeeper,
    feedSourceRepository: FeedSourceRepository,
    preferenceRepository: PreferenceRepository
  ) {
    self.article = article
    self.articleService = articleService
    self.articleRepository = articleRepository
    self.aiService = aiService
    self.plusGate = plusGate
    self.feedSourceRepository = feedSourceRepository
    self.preferenceRepository = preferenceRepository
  }

  var isPlusActive: Bool { plusGate.isPlusActive }

  var canCompareSources: Bool {
    (try? feedSourceRepository.fetchEnabled().count) ?? 0 > 1
  }

  var bodyHTML: String? {
    for html in [article.content, article.summary] {
      guard let html, !html.isEmpty else { continue }
      let plain = HTMLSanitizer.stripHTML(html) ?? ""
      if !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return html
      }
    }
    return nil
  }

  var displayContent: AttributedString? {
    guard let html = bodyHTML else { return nil }
    return HTMLSanitizer.attributedString(from: html)
  }

  var plainBodyText: String? {
    guard let html = bodyHTML else { return nil }
    return HTMLSanitizer.stripHTML(html)
  }

  var hasReadableInAppContent: Bool {
    guard let plain = plainBodyText else { return false }
    return plain.count >= 80 || article.contentAvailability == .fullRSS
  }

  var needsPartialNotice: Bool {
    hasReadableInAppContent && article.contentAvailability != .fullRSS
  }

  var fontSizeMultiplier: Double {
    (try? preferenceRepository.getOrCreate().readerFontSizeMultiplier) ?? 1.0
  }

  func onAppear() {
    try? articleService.markRead(article)
    loadSimilarArticles()
  }

  func loadSimilarArticles() {
    guard let all = try? articleRepository.fetchAll(limit: 200) else { return }
    similarArticles = similarArticlesService.related(to: article, from: all)
  }

  func toggleSaved() {
    try? articleService.toggleSaved(article)
  }

  func toggleFavorite() {
    try? articleService.toggleFavorite(article)
  }

  enum PlusAction {
    case summary
    case compare
    case context
  }

  func performPlusAction(_ action: PlusAction) async -> Bool {
    guard plusGate.requirePlus(for: .aiSummary) else { return false }

    isLoadingAI = true
    errorMessage = nil
    defer { isLoadingAI = false }

    do {
      switch action {
      case .summary:
        let result = try await aiService.summarizeArticle(article)
        aiSummary = result.summary
      case .compare:
        let all = (try? articleRepository.fetchAll(limit: 200)) ?? []
        let peers = similarArticlesService.crossSourcePeers(for: article, from: all)
        let related = ([article] + peers).uniqued(by: \.id)
        let cluster = ClusterDTO(
          id: article.id,
          title: article.title,
          summary: nil,
          articleIds: related.map(\.id),
          comparisonNote: nil
        )
        comparisonText = try await aiService.compareSources(cluster: cluster, articles: related)
      case .context:
        let result = try await aiService.explainContext(article: article)
        contextExplanation = result.explanation
      }
      return true
    } catch {
      errorMessage = error.localizedDescription
      return true
    }
  }
}

private extension Array {
  func uniqued<ID: Hashable>(by keyPath: KeyPath<Element, ID>) -> [Element] {
    var seen = Set<ID>()
    return filter { seen.insert($0[keyPath: keyPath]).inserted }
  }
}
