import SwiftUI

struct MainTabView: View {
  let dependencies: AppDependencies

  @State private var todayViewModel: TodayViewModel
  @State private var forYouViewModel: ForYouViewModel
  @State private var sourcesViewModel: SourcesViewModel
  @State private var savedViewModel: SavedViewModel
  @State private var settingsViewModel: SettingsViewModel

  @State private var selectedArticle: Article?
  @State private var showPaywall = false

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
    _todayViewModel = State(initialValue: TodayViewModel(
      articleService: dependencies.articleService,
      feedService: dependencies.feedService,
      feedSourceRepository: dependencies.feedSourceRepository,
      preferenceRepository: dependencies.preferenceRepository,
      searchService: dependencies.searchService
    ))
    _forYouViewModel = State(initialValue: ForYouViewModel(
      articleRepository: dependencies.articleRepository,
      feedSourceRepository: dependencies.feedSourceRepository,
      preferenceRepository: dependencies.preferenceRepository,
      recommendationEngine: dependencies.recommendationEngine,
      aiService: dependencies.aiService,
      plusGate: dependencies.plusGate
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
      feedSourceRepository: dependencies.feedSourceRepository
    ))
  }

  var body: some View {
    TabView {
      TodayView(viewModel: todayViewModel, onSelectArticle: { selectedArticle = $0 })
        .tabItem { Label(String(localized: "tab.today"), systemImage: "sun.max") }

      ForYouView(
        viewModel: forYouViewModel,
        onSelectArticle: { selectedArticle = $0 },
        onShowPaywall: { showPaywall = true }
      )
      .tabItem { Label(String(localized: "tab.foryou"), systemImage: "sparkles") }

      SourcesView(viewModel: sourcesViewModel)
        .tabItem { Label(String(localized: "tab.sources"), systemImage: "antenna.radiowaves.left.and.right") }

      SavedView(viewModel: savedViewModel, onSelectArticle: { selectedArticle = $0 })
        .tabItem { Label(String(localized: "tab.saved"), systemImage: "bookmark") }

      SettingsView(
        viewModel: settingsViewModel,
        subscriptionService: dependencies.subscriptionService,
        onShowPaywall: { showPaywall = true }
      )
      .tabItem { Label(String(localized: "tab.settings"), systemImage: "gearshape") }
    }
    .tint(PrismaColors.accentFallback)
    .sheet(item: $selectedArticle) { article in
      ArticleReaderView(
        viewModel: ArticleReaderViewModel(
          article: article,
          articleService: dependencies.articleService,
          articleRepository: dependencies.articleRepository,
          aiService: dependencies.aiService,
          plusGate: dependencies.plusGate,
          feedSourceRepository: dependencies.feedSourceRepository,
          preferenceRepository: dependencies.preferenceRepository
        ),
        onShowPaywall: { showPaywall = true },
        onSelectArticle: { next in
          selectedArticle = next
        }
      )
    }
    .sheet(isPresented: $showPaywall) {
      PaywallView(subscriptionService: dependencies.subscriptionService)
    }
  }
}

extension Article: Identifiable {}
