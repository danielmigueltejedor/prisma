import SwiftUI

struct MainTabView: View {
  let dependencies: AppDependencies

  @Environment(\.scenePhase) private var scenePhase

  @State private var todayViewModel: TodayViewModel
  @State private var forYouViewModel: ForYouViewModel
  @State private var sourcesViewModel: SourcesViewModel
  @State private var savedViewModel: SavedViewModel
  @State private var settingsViewModel: SettingsViewModel

  @State private var selectedArticle: Article?
  @State private var selectedSource: FeedSource?
  @State private var selectedAuthor: AuthorProfile?
  @State private var selectedTab = 0
  @State private var readerViewModel: ArticleReaderViewModel?

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
    _todayViewModel = State(initialValue: TodayViewModel(
      articleService: dependencies.articleService,
      feedService: dependencies.feedService,
      feedSourceRepository: dependencies.feedSourceRepository,
      preferenceRepository: dependencies.preferenceRepository,
      searchService: dependencies.searchService,
      translationService: dependencies.translationService,
      weatherService: dependencies.weatherService
    ))
    _forYouViewModel = State(initialValue: ForYouViewModel(
      articleRepository: dependencies.articleRepository,
      articleService: dependencies.articleService,
      feedSourceRepository: dependencies.feedSourceRepository,
      preferenceRepository: dependencies.preferenceRepository,
      recommendationEngine: dependencies.recommendationEngine,
      aiService: dependencies.aiService
    ))
    _sourcesViewModel = State(initialValue: SourcesViewModel(
      feedSourceRepository: dependencies.feedSourceRepository,
      feedService: dependencies.feedService,
      preferenceRepository: dependencies.preferenceRepository
    ))
    _savedViewModel = State(initialValue: SavedViewModel(
      articleRepository: dependencies.articleRepository,
      collectionRepository: dependencies.collectionRepository,
      feedSourceRepository: dependencies.feedSourceRepository
    ))
    _settingsViewModel = State(initialValue: SettingsViewModel(
      preferenceRepository: dependencies.preferenceRepository,
      feedSourceRepository: dependencies.feedSourceRepository,
      weatherService: dependencies.weatherService
    ))
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      TodayView(
        viewModel: todayViewModel,
        previewStore: dependencies.previewTranslationStore,
        onSelectArticle: { openArticle($0) }
      )
        .tabItem { Label(String(localized: "tab.today"), systemImage: "sun.max") }
        .tag(0)

      ForYouView(
        viewModel: forYouViewModel,
        previewStore: dependencies.previewTranslationStore,
        makeReaderViewModel: { makeReaderViewModel(for: $0, cascade: true) },
        onSelectArticle: { openArticle($0) }
      )
      .tabItem { Label(String(localized: "tab.foryou"), systemImage: "sparkles") }
      .tag(1)

      SourcesView(
        viewModel: sourcesViewModel,
        articleRepository: dependencies.articleRepository,
        feedService: dependencies.feedService,
        translationService: dependencies.translationService,
        previewStore: dependencies.previewTranslationStore,
        onSelectArticle: { openArticle($0) }
      )
        .tabItem { Label(String(localized: "tab.sources"), systemImage: "antenna.radiowaves.left.and.right") }
        .tag(2)

      SavedView(
        viewModel: savedViewModel,
        previewStore: dependencies.previewTranslationStore,
        onSelectArticle: { openArticle($0) }
      )
        .tabItem { Label(String(localized: "tab.saved"), systemImage: "bookmark") }
        .tag(3)

      SettingsView(viewModel: settingsViewModel)
        .tabItem { Label(String(localized: "tab.settings"), systemImage: "gearshape") }
        .tag(4)
    }
    .onChange(of: selectedTab) { _, tab in
      forYouViewModel.isTabActive = tab == 1
      if tab == 1 {
        forYouViewModel.tabDidBecomeActive()
      }
      if tab == 0 {
        Task { await todayViewModel.loadWeather() }
      }
      if tab == 3 {
        savedViewModel.reload()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        dependencies.offlineReadingCoordinator.schedulePrefetch()
      }
    }
    .task {
      await dependencies.refreshEnabledSourcesOnLaunchIfNeeded()
    }
    .onAppear {
      forYouViewModel.isTabActive = selectedTab == 1
      if selectedTab == 1 {
        forYouViewModel.tabDidBecomeActive()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
      dependencies.offlineReadingCoordinator.schedulePrefetch()
    }
    .onReceive(NotificationCenter.default.publisher(for: .preferencesDidChange)) { _ in
      dependencies.weatherService.invalidateCache()
      Task { await todayViewModel.loadWeather() }
    }
    .tint(PrismaColors.accentFallback)
    .sheet(item: $selectedArticle) { article in
      if let readerViewModel {
        ArticleReaderView(
          viewModel: readerViewModel,
          onSelectArticle: { next in
            guard next.id != article.id else { return }
            selectedArticle = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              openArticle(next)
            }
          },
          onOpenSource: { source in
            selectedArticle = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              selectedSource = source
            }
          },
          onOpenAuthor: { authorName in
            selectedArticle = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              selectedAuthor = AuthorProfile(name: authorName)
            }
          }
        )
      }
    }
    .onChange(of: selectedArticle) { _, newValue in
      if newValue == nil {
        readerViewModel = nil
      }
    }
    .sheet(item: $selectedAuthor) { author in
      AuthorDetailView(
        viewModel: AuthorDetailViewModel(
          authorName: author.name,
          articleRepository: dependencies.articleRepository,
          feedSourceRepository: dependencies.feedSourceRepository,
          feedService: dependencies.feedService
        ),
        previewStore: dependencies.previewTranslationStore,
        onSelectArticle: { article in
          selectedAuthor = nil
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            openArticle(article)
          }
        }
      )
    }
    .sheet(item: $selectedSource) { source in
        SourceDetailView(
          viewModel: SourceDetailViewModel(
            source: source,
            articleRepository: dependencies.articleRepository,
            feedService: dependencies.feedService,
            translationService: dependencies.translationService
          ),
          previewStore: dependencies.previewTranslationStore,
        onSelectArticle: { article in
          selectedSource = nil
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            openArticle(article)
          }
        }
      )
    }
  }

  private func openArticle(_ article: Article) {
    if readerViewModel?.article.id != article.id {
      readerViewModel = makeReaderViewModel(for: article)
    } else {
      readerViewModel?.syncLibraryState()
    }
    selectedArticle = article
  }

  private func makeReaderViewModel(for article: Article, cascade: Bool = false) -> ArticleReaderViewModel {
    ArticleReaderViewModel(
      article: article,
      articleService: dependencies.articleService,
      articleRepository: dependencies.articleRepository,
      aiService: dependencies.aiService,
      feedSourceRepository: dependencies.feedSourceRepository,
      feedService: dependencies.feedService,
      preferenceRepository: dependencies.preferenceRepository,
      translationService: dependencies.translationService,
      redditCommentsService: dependencies.redditCommentsService,
      redditCommentsTranslationService: dependencies.redditCommentsTranslationService,
      summaryService: dependencies.summaryService,
      insightRepository: dependencies.insightRepository,
      impressionMode: cascade ? .cascadeTraining : .standard
    )
  }
}

extension Article: Identifiable {}
