import SwiftUI
import SwiftData

struct TodayView: View {
  @Bindable var viewModel: TodayViewModel
  var previewStore: ArticlePreviewTranslationStore
  var onSelectArticle: (Article) -> Void

  @State private var isSearchExpanded = false
  @State private var headerScrollOffset: CGFloat = 0
  @State private var articleActionMenu: Article?
  @State private var shareItems: [Any] = []
  @State private var showShare = false
  @State private var lastPreviewArticleIDs: [String] = []
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
        refreshPreviewsIfNeeded(force: true)
        Task { await viewModel.refreshIfStale() }
      }
      .onChange(of: viewModel.latestArticles.map(\.id)) { _, ids in
        refreshPreviewsIfNeeded(articleIDs: ids)
      }
      .onReceive(NotificationCenter.default.publisher(for: .articleTranslationsDidUpdate)) { _ in
        previewStore.mergeTranslations(for: viewModel.latestArticles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
        viewModel.handleFeedsRefreshed()
        refreshPreviewsIfNeeded(force: true)
      }
      .onReceive(NotificationCenter.default.publisher(for: .articleLibraryDidChange)) { _ in
        viewModel.reload()
        refreshPreviewsIfNeeded(force: true)
      }
      .onChange(of: viewModel.scrollToTopToken) { _, _ in
        if isSearchExpanded {
          isSearchExpanded = false
          searchFocused = false
        }
      }
      .sheet(isPresented: $showShare) {
        ShareSheet(items: shareItems)
      }
      .overlay {
        if let article = articleActionMenu {
          ArticleActionMenuOverlay(
            article: article,
            collections: viewModel.collections,
            isInCollection: { viewModel.isArticleInCollection(article, collection: $0) },
            onToggleLike: {
              viewModel.toggleLike(article)
              articleActionMenu = nil
            },
            onToggleSave: {
              viewModel.toggleSaved(article)
              articleActionMenu = nil
            },
            onShare: {
              shareItems = viewModel.shareItems(for: article)
              articleActionMenu = nil
              showShare = true
            },
            onAddToCollection: { collection in
              viewModel.addToCollection(article, collection: collection)
              articleActionMenu = nil
            },
            onDismiss: { articleActionMenu = nil }
          )
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
      TodayArticleRow(
        article: article,
        previewStore: previewStore,
        onSelect: { onSelectArticle(article) },
        onShowActions: { articleActionMenu = article }
      )
      .equatable()
    }
  }

  private func refreshPreviewsIfNeeded(articleIDs: [String]? = nil, force: Bool = false) {
    let articles = viewModel.latestArticles
    let ids = articleIDs ?? articles.map(\.id)
    if !force, ids == lastPreviewArticleIDs { return }
    lastPreviewArticleIDs = ids
    previewStore.refresh(for: articles)
  }
}

private struct TodayArticleRow: View, Equatable {
  let article: Article
  let previewStore: ArticlePreviewTranslationStore
  let onSelect: () -> Void
  let onShowActions: () -> Void

  static func == (lhs: TodayArticleRow, rhs: TodayArticleRow) -> Bool {
    lhs.article.id == rhs.article.id
      && lhs.article.isRead == rhs.article.isRead
      && lhs.article.isSaved == rhs.article.isSaved
      && lhs.article.isFavorite == rhs.article.isFavorite
      && lhs.previewStore.revision(for: lhs.article.id) == rhs.previewStore.revision(for: rhs.article.id)
  }

  var body: some View {
    TranslatedArticleCard(article: article, previewStore: previewStore)
      .equatable()
      .contentShape(Rectangle())
      .onTapGesture(perform: onSelect)
      .highPriorityGesture(
        LongPressGesture(minimumDuration: 0.45)
          .onEnded { _ in
            HapticFeedback.medium()
            onShowActions()
          }
      )
      .accessibilityHint(String(localized: "article.actions.hint"))
  }
}
