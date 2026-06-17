import Foundation

@MainActor
@Observable
final class SavedViewModel {
  var savedArticles: [Article] = []
  var favorites: [Article] = []
  var collections: [Collection] = []
  var selectedFilter: SavedFilter = .saved
  var selectedCollectionID: UUID?
  var sourceFilter: UUID?

  private let articleRepository: ArticleRepository
  private let collectionRepository: CollectionRepository
  private let feedSourceRepository: FeedSourceRepository
  private var hasLoadedData = false

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
    case saved, favorites

    var id: String { rawValue }

    var title: String {
      switch self {
      case .saved: String(localized: "saved.filter.saved")
      case .favorites: String(localized: "saved.filter.favorites")
      }
    }

    var emptyIcon: String {
      switch self {
      case .saved: "bookmark"
      case .favorites: "heart"
      }
    }

    var emptyTitle: String {
      switch self {
      case .saved: String(localized: "saved.empty.title")
      case .favorites: String(localized: "saved.empty.favorites.title")
      }
    }

    var emptyMessage: String {
      switch self {
      case .saved: String(localized: "saved.empty.message")
      case .favorites: String(localized: "saved.empty.favorites.message")
      }
    }
  }

  var displayedArticles: [Article] {
    var items: [Article]
    switch selectedFilter {
    case .saved:
      items = savedArticles
    case .favorites:
      items = favorites
    }
    if let sourceFilter {
      items = items.filter { $0.sourceId == sourceFilter }
    }
    if let selectedCollectionID,
       let collection = collections.first(where: { $0.id == selectedCollectionID }) {
      let articleIDs = Set(collection.savedArticles.compactMap(\.article?.id))
      items = items.filter { articleIDs.contains($0.id) }
    }
    return items
  }

  func loadIfNeeded() {
    guard !hasLoadedData else { return }
    reload()
  }

  func reload() {
    do {
      savedArticles = try articleRepository.fetchSaved()
      favorites = try articleRepository.fetchFavorites()
      collections = try collectionRepository.fetchAll()
      hasLoadedData = true
    } catch {}
  }

  func load() {
    reload()
  }

  func createCollection(name: String) {
    _ = try? collectionRepository.create(name: name)
    load()
  }
}
