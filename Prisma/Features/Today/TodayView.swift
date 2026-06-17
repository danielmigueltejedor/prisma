import SwiftUI
import SwiftData

struct TodayView: View {
  @Bindable var viewModel: TodayViewModel
  var previewStore: ArticlePreviewTranslationStore
  var onSelectArticle: (Article) -> Void

  @State private var isSearchExpanded = false
  @State private var headerScrollOffset: CGFloat = 0
  @FocusState private var searchFocused: Bool

  var body: some View {
    NavigationStack {
      PrismaScreen {
        if isSearchExpanded {
          todaySearchMode
        } else if viewModel.isLoading && viewModel.articles.isEmpty {
          LoadingView(message: String(localized: "today.loading"))
        } else if let error = viewModel.errorMessage, viewModel.articles.isEmpty {
          ErrorStateView(
            title: String(localized: "error.generic"),
            message: error,
            onRetry: { Task { await viewModel.refresh() } }
          )
        } else if viewModel.articles.isEmpty {
          EmptyStateView(
            icon: "newspaper",
            title: String(localized: "today.empty.title"),
            message: String(localized: "today.empty.message"),
            actionTitle: String(localized: "today.empty.action"),
            action: { Task { await viewModel.refresh() } }
          )
        } else {
          todayBrowseMode
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top, spacing: 0) {
        PrismaNavigationHeaderChrome(scrollOffset: headerScrollOffset) {
          MorphingLiquidGlassNavigationBar(
            isExpanded: $isSearchExpanded,
            searchText: $viewModel.searchText,
            title: String(localized: "tab.today"),
            prompt: String(localized: "search.prompt"),
            onTextChange: { viewModel.scheduleSearch() },
            focus: $searchFocused
          ) {
            TodayWeatherBadge(weather: viewModel.weather)
          }
        }
      }
      .animation(.easeInOut(duration: 0.28), value: isSearchExpanded)
      .onChange(of: isSearchExpanded) { _, expanded in
        if !expanded { headerScrollOffset = 0 }
      }
      .onAppear {
        viewModel.loadIfNeeded()
        previewStore.refresh(for: viewModel.articles)
        Task { await viewModel.refreshIfStale() }
      }
      .onChange(of: viewModel.articles.count) { _, _ in
        previewStore.refresh(for: viewModel.articles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .articleTranslationsDidUpdate)) { _ in
        previewStore.forceRefresh(for: viewModel.articles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
        viewModel.handleFeedsRefreshed()
        previewStore.refresh(for: viewModel.articles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .articleLibraryDidChange)) { _ in
        viewModel.reload()
        previewStore.refresh(for: viewModel.articles)
      }
      .onChange(of: viewModel.scrollToTopToken) { _, _ in
        if isSearchExpanded {
          isSearchExpanded = false
          searchFocused = false
        }
      }
    }
  }

  private var todayBrowseMode: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: PrismaSpacing.md) {
          Color.clear.frame(height: 0).id("today-scroll-top")

          browseFilters

        if let briefing = viewModel.dailyBriefing {
          dailyBriefingCard(briefing)
        }

        sectionHeader(String(localized: "today.section.latest"))
        articleRows(viewModel.latestArticles)

        if !viewModel.favoriteSourceArticles.isEmpty {
          sectionHeader(String(localized: "today.section.favorites"))
          articleRows(viewModel.favoriteSourceArticles)
        }

        if !viewModel.recentlySaved.isEmpty {
          sectionHeader(String(localized: "today.section.saved"))
          articleRows(viewModel.recentlySaved)
        }
      }
      .padding(PrismaSpacing.md)
    }
    .refreshable { await viewModel.refresh() }
    .captureNativeScrollOffset($headerScrollOffset)
    .onChange(of: viewModel.scrollToTopToken) { _, _ in
      withAnimation(.easeOut(duration: 0.2)) {
        proxy.scrollTo("today-scroll-top", anchor: .top)
      }
      headerScrollOffset = 0
    }
    }
  }

  private var todaySearchMode: some View {
    LiquidGlassSearchModeShell(
      hasQuery: viewModel.isSearching,
      hasResults: !viewModel.displayedArticles.isEmpty,
      emptyTitle: String(localized: "search.mode.hint.title"),
      emptyMessage: String(localized: "search.mode.hint.message"),
      noResultsTitle: String(localized: "search.noResults.title"),
      noResultsMessage: String(localized: "search.noResults.message"),
      scrollOffset: $headerScrollOffset
    ) {
      browseFilters
    } results: {
      sectionHeader(String(localized: "search.results.title"))
      articleRows(viewModel.displayedArticles.prefix(50).map { $0 })
    }
  }

  private var browseFilters: some View {
    Group {
      HStack {
        Toggle(String(localized: "filter.unread"), isOn: $viewModel.showUnreadOnly)
          .font(PrismaTypography.caption())
          .onChange(of: viewModel.showUnreadOnly) { _, _ in
            viewModel.performSearch()
          }
      }

      StyleFilterBar(
        filters: viewModel.styleFilters,
        selection: $viewModel.selectedStyle
      )
      .onChange(of: viewModel.selectedStyle) { _, _ in
        viewModel.performSearch()
      }
    }
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(PrismaTypography.title())
      .foregroundStyle(PrismaColors.textPrimary)
      .padding(.top, PrismaSpacing.xxs)
  }

  private func dailyBriefingCard(_ briefing: DailyBriefingDTO) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      HStack(spacing: PrismaSpacing.xs) {
        Image(systemName: "sun.horizon.fill")
          .foregroundStyle(PrismaColors.accentFallback)
        Text(briefing.title)
          .font(PrismaTypography.headline())
      }
      ForEach(Array(briefing.sections.prefix(3).enumerated()), id: \.offset) { _, section in
        VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
          Text(section.headline)
            .font(PrismaTypography.callout(.semibold))
          Text(section.summary)
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textSecondary)
            .lineLimit(3)
        }
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  @ViewBuilder
  private func articleRows(_ items: [Article]) -> some View {
    ForEach(items, id: \.id) { article in
      Button { onSelectArticle(article) } label: {
        TranslatedArticleCard(article: article, previewStore: previewStore)
      }
      .buttonStyle(.plain)
    }
  }
}
