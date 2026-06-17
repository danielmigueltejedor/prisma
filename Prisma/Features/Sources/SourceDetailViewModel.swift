import Foundation

@MainActor
@Observable
final class SourceDetailViewModel {
  let source: FeedSource

  var articles: [Article] = []
  var isRefreshing = false
  var errorMessage: String?

  private let articleRepository: ArticleRepository
  private let feedService: FeedService
  private var hasLoadedData = false

  init(
    source: FeedSource,
    articleRepository: ArticleRepository,
    feedService: FeedService,
    translationService: ArticleTranslationService
  ) {
    self.source = source
    self.articleRepository = articleRepository
    self.feedService = feedService
    _ = translationService
  }

  var displayDescription: String {
    if let text = source.feedDescription, !text.isEmpty { return text }
    if let feed = RecommendedFeeds.find(feedURL: source.feedURL),
       let text = feed.description, !text.isEmpty {
      return text
    }
    return defaultDescription
  }

  var recommendedFeed: RecommendedFeed? {
    RecommendedFeeds.find(feedURL: source.feedURL)
  }

  func loadIfNeeded() {
    guard !hasLoadedData else { return }
    reload()
  }

  func handleFeedsRefreshed() {
    reload()
  }

  func reload() {
    do {
      articles = try articleRepository.fetch(for: source.id)
      hasLoadedData = true
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refresh() async {
    isRefreshing = true
    errorMessage = nil
    defer { isRefreshing = false }

    do {
      _ = try await feedService.refresh(source: source)
      reload()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private var defaultDescription: String {
    switch source.platform {
    case .reddit:
      return String(localized: "source.description.reddit")
    case .x:
      return String(localized: "source.description.x")
    case .news:
      return String(localized: "source.description.news \(source.name)")
    }
  }
}
