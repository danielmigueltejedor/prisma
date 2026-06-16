import Foundation

@MainActor
@Observable
final class SavedViewModel {
  var savedArticles: [Article] = []
  var favorites: [Article] = []
  var collections: [Collection] = []
  var selectedFilter: SavedFilter = .all
  var sourceFilter: UUID?

  private let articleRepository: ArticleRepository
  private let collectionRepository: CollectionRepository
  private let feedSourceRepository: FeedSourceRepository

  init(
    articleRepository: ArticleRepository,
    collectionRepository: CollectionRepository,
    feedSourceRepository: FeedSourceRepository
  ) {
    self.articleRepository = articleRepository
    self.collectionRepository = collectionRepository
    self.feedSourceRepository = feedSourceRepository
  }

  enum SavedFilter: String, CaseIterable, Identifiable {
    case all, saved, favorites

    var id: String { rawValue }

    var title: String {
      switch self {
      case .all: String(localized: "saved.filter.all")
      case .saved: String(localized: "saved.filter.saved")
      case .favorites: String(localized: "saved.filter.favorites")
      }
    }
  }

  var displayedArticles: [Article] {
    var items: [Article]
    switch selectedFilter {
    case .all:
      items = savedArticles
    case .saved:
      items = savedArticles
    case .favorites:
      items = favorites
    }
    if let sourceFilter {
      items = items.filter { $0.sourceId == sourceFilter }
    }
    return items
  }

  func load() {
    do {
      savedArticles = try articleRepository.fetchSaved()
      favorites = try articleRepository.fetchFavorites()
      collections = try collectionRepository.fetchAll()
    } catch {}
  }

  func createCollection(name: String) {
    _ = try? collectionRepository.create(name: name)
    load()
  }
}
