import Foundation

@MainActor
@Observable
final class AuthorDetailViewModel {
  let authorName: String

  var articles: [Article] = []
  var sourceNames: [String] = []
  var isRefreshing = false
  var errorMessage: String?

  private let articleRepository: ArticleRepository
  private let feedSourceRepository: FeedSourceRepository
  private let feedService: FeedService
  private var hasLoadedData = false

  init(
    authorName: String,
    articleRepository: ArticleRepository,
    feedSourceRepository: FeedSourceRepository,
    feedService: FeedService
  ) {
    self.authorName = authorName
    self.articleRepository = articleRepository
    self.feedSourceRepository = feedSourceRepository
    self.feedService = feedService
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
      articles = try articleRepository.fetch(byAuthor: authorName)
      sourceNames = Array(Set(articles.map(\.sourceName))).sorted()
      hasLoadedData = true
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refresh() async {
    let sourceIds = Set(articles.map(\.sourceId))
    guard !sourceIds.isEmpty else { return }

    isRefreshing = true
    errorMessage = nil
    defer { isRefreshing = false }

    do {
      for sourceId in sourceIds {
        guard let source = try feedSourceRepository.find(by: sourceId), source.isEnabled else { continue }
        try await feedService.refresh(source: source)
      }
      reload()
      FeedRefreshNotifier.publish()
    } catch {
      errorMessage = error.localizedDescription
      reload()
    }
  }
}
