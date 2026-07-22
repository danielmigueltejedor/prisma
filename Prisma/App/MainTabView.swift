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
  @State private var pendingNavigation: DeferredSheetNavigation?
  @State private var connectivity = NetworkConnectivityMonitor.shared

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
    _todayViewModel = State(initialValue: TodayViewModel(
      articleService: dependencies.articleService,
      feedService: dependencies.feedService,
      feedSourceRepository: dependencies.feedSourceRepository,
      preferenceRepository: dependencies.preferenceRepository,
      searchService: dependencies.searchService,
      weatherService: dependencies.weatherService,
      collectionRepository: dependencies.collectionRepository
    ))
    _forYouViewModel = State(initialValue: ForYouViewModel(
      articleRepository: dependencies.articleRepository,
      articleService: dependencies.articleService,
      feedSourceRepository: dependencies.feedSourceRepository,
      preferenceRepository: dependencies.preferenceRepository,
      sharedRankingService: dependencies.sharedRankingService,
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
      articleRepository: dependencies.articleRepository,
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
        weather: todayViewModel.weather,
        makeReaderViewModel: { makeReaderViewModel(for: $0, cascade: true) },
        onSelectArticle: { openArticle($0) },
        onOpenSources: { selectedTab = 2 }
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
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !connectivity.isOnline {
        OfflineBanner()
      }
    }
    .onChange(of: selectedTab) { _, tab in
      if tab == 1 {
        forYouViewModel.tabDidBecomeActive()
        Task { await todayViewModel.loadWeather() }
      } else {
        forYouViewModel.tabDidBecomeInactive()
      }
      syncBackgroundWorkForInteraction()
      if tab == 0 {
        Task { await todayViewModel.loadWeather() }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .articleTrainingLike)) { notification in
      guard let articleID = notification.userInfo?[ArticleTrainingNotificationKey.articleID] as? String else { return }
      forYouViewModel.handleCascadeLike(articleID: articleID)
    }
    .onReceive(NotificationCenter.default.publisher(for: .articleTrainingSave)) { notification in
      guard let articleID = notification.userInfo?[ArticleTrainingNotificationKey.articleID] as? String else { return }
      forYouViewModel.handleCascadeSave(articleID: articleID)
    }
    .onChange(of: scenePhase) { _, phase in
      switch phase {
      case .background:
        dependencies.backgroundContentCoordinator.handleMovedToBackground()
        dependencies.backgroundTranslationCoordinator.scheduleSweep(priority: .background)
      case .active:
        dependencies.backgroundContentCoordinator.handleMovedToForeground()
      default:
        break
      }
    }
    .task {
      await dependencies.refreshEnabledSourcesOnLaunchIfNeeded()
      dependencies.schedulePostLaunchWarmup()
    }
    .onAppear {
      syncBackgroundWorkForInteraction()
    }
    .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
      guard !dependencies.backgroundWorkGate.shouldDeferHeavyWork else { return }
      dependencies.offlineReadingCoordinator.schedulePrefetch()
      dependencies.backgroundTranslationCoordinator.scheduleSweep(priority: .utility)
      dependencies.backgroundContentCoordinator.scheduleIdleWarmup()
    }
    .onReceive(NotificationCenter.default.publisher(for: .preferencesDidChange)) { _ in
      dependencies.weatherService.invalidateCache()
      Task { await todayViewModel.loadWeather() }
    }
    .tint(PrismaColors.accentFallback)
    .sheet(item: $selectedArticle) { article in
      ArticleReaderSheet(
        article: article,
        dependencies: dependencies,
        onSelectArticle: { next in
          guard next.id != article.id else { return }
          chainNavigation(.article(next)) { selectedArticle = nil }
        },
        onOpenSource: { source in
          chainNavigation(.source(source)) { selectedArticle = nil }
        },
        onOpenAuthor: { authorName in
          chainNavigation(.author(authorName)) { selectedArticle = nil }
        }
      )
    }
    .onChange(of: selectedArticle) { _, newValue in
      if newValue == nil {
        resumePendingNavigation()
      }
      syncBackgroundWorkForInteraction()
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
          chainNavigation(.article(article)) { selectedAuthor = nil }
        }
      )
    }
    .onChange(of: selectedAuthor) { _, newValue in
      if newValue == nil {
        resumePendingNavigation()
      }
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
          chainNavigation(.article(article)) { selectedSource = nil }
        }
      )
    }
    .onChange(of: selectedSource) { _, newValue in
      if newValue == nil {
        resumePendingNavigation()
      }
    }
    .background {
      TabBarReTapDetector { tabIndex in
        handleTabReTap(tabIndex)
      }
    }
  }

  private func syncBackgroundWorkForInteraction() {
    if selectedArticle != nil {
      dependencies.pauseBackgroundWorkForReader()
    } else {
      dependencies.resumeBackgroundWorkAfterReader()
    }
  }

  private func handleTabReTap(_ tabIndex: Int) {
    switch tabIndex {
    case 0:
      todayViewModel.refreshFromTabReTap()
    case 1:
      forYouViewModel.refreshFromTabReTap()
    default:
      break
    }
  }

  private func chainNavigation(_ next: DeferredSheetNavigation, dismiss: () -> Void) {
    pendingNavigation = next
    dismiss()
  }

  private func resumePendingNavigation() {
    guard let pending = pendingNavigation else { return }
    pendingNavigation = nil
    switch pending {
    case .article(let article):
      openArticle(article)
    case .source(let source):
      selectedSource = source
    case .author(let name):
      selectedAuthor = AuthorProfile(name: name)
    }
  }

  private func openArticle(_ article: Article) {
    dependencies.pauseBackgroundWorkForReader()
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
      localReadingCorpusService: dependencies.localReadingCorpusService,
      impressionMode: cascade ? .cascadeTraining : .standard
    )
  }
}

extension Article: Identifiable {}
