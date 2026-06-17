import SwiftUI

struct ForYouView: View {
  @Bindable var viewModel: ForYouViewModel
  var previewStore: ArticlePreviewTranslationStore
  var makeReaderViewModel: (Article) -> ArticleReaderViewModel
  var onSelectArticle: (Article) -> Void
  var onOpenSources: (() -> Void)?

  @State private var selectedCluster: ClusterDTO?
  @State private var pendingArticleFromCluster: Article?
  @State private var lastPreviewArticleIDs: [String] = []
  @State private var showErrorAlert = false

  var body: some View {
    NavigationStack {
      feedScreen
        .sheet(item: $selectedCluster, content: clusterSheet)
        .onChange(of: selectedCluster?.id) { _, _ in
          handleClusterDismissal()
        }
    }
  }

  private var feedScreen: some View {
    PrismaScreen {
      if viewModel.isLoadingRanking && viewModel.articles.isEmpty {
        LoadingView(message: String(localized: "foryou.loading"))
      } else if viewModel.articles.isEmpty {
        EmptyStateView(
          icon: "sparkles",
          title: String(localized: "foryou.empty.title"),
          message: String(localized: "foryou.empty.message"),
          actionTitle: String(localized: "foryou.empty.action"),
          action: { onOpenSources?() }
        )
      } else if viewModel.cascadeViewEnabled {
        ForYouCascadeView(
          viewModel: viewModel,
          makeReaderViewModel: { article in
            viewModel.cascadeReader(for: article, factory: makeReaderViewModel)
          }
        )
      } else {
        listFeed
      }
    }
    .navigationTitle(viewModel.cascadeViewEnabled ? "" : String(localized: "tab.foryou"))
    .toolbar(viewModel.cascadeViewEnabled ? .hidden : .visible, for: .navigationBar)
    .onAppear {
      viewModel.loadIfNeeded()
      refreshPreviewsIfNeeded()
    }
    .onChange(of: viewModel.listFeedRefreshToken) { _, _ in
      refreshPreviewsIfNeeded()
    }
    .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
      viewModel.handleFeedsRefreshed()
      refreshPreviewsIfNeeded()
    }
    .onReceive(NotificationCenter.default.publisher(for: .articleLibraryDidChange)) { _ in
      viewModel.handleLibraryChanged()
    }
    .onReceive(NotificationCenter.default.publisher(for: .preferencesDidChange)) { _ in
      viewModel.handlePreferencesChanged()
    }
    .onReceive(NotificationCenter.default.publisher(for: .articleTranslationsDidUpdate)) { _ in
      refreshPreviewsIfNeeded(force: true)
    }
    .onChange(of: viewModel.errorMessage) { _, message in
      showErrorAlert = message != nil
    }
    .alert(String(localized: "error.generic"), isPresented: $showErrorAlert) {
      Button(String(localized: "action.close"), role: .cancel) {
        viewModel.errorMessage = nil
      }
    } message: {
      if let message = viewModel.errorMessage {
        Text(message)
      }
    }
    .overlay {
      if !viewModel.cascadeViewEnabled, viewModel.isLoadingAI, viewModel.clusters.isEmpty {
        ProgressView()
          .padding()
          .prismaGlass()
      }
    }
  }

  private func clusterSheet(cluster: ClusterDTO) -> some View {
    ClusterDetailView(
      cluster: cluster,
      articles: viewModel.articles(for: cluster),
      previewStore: previewStore,
      onSelectArticle: { article in
        pendingArticleFromCluster = article
        selectedCluster = nil
      }
    )
  }

  private func handleClusterDismissal() {
    guard selectedCluster == nil, let article = pendingArticleFromCluster else { return }
    pendingArticleFromCluster = nil
    onSelectArticle(article)
  }

  private var listFeed: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: PrismaSpacing.lg) {
          Color.clear.frame(height: 0).id("foryou-list-top")

          if !viewModel.clusters.isEmpty {
            sectionHeader(String(localized: "foryou.clusters"))
            ForEach(viewModel.clusters, id: \.id) { cluster in
              Button { selectedCluster = cluster } label: {
                clusterCard(cluster)
              }
              .buttonStyle(.plain)
            }
          }

          sectionHeader(String(localized: "foryou.smartFeed"))

          ForEach(viewModel.articles.prefix(30), id: \.id) { article in
            Button { onSelectArticle(article) } label: {
              TranslatedArticleCard(
                article: article,
                previewStore: previewStore,
                recommendationReason: viewModel.recommendationReason(for: article)
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(PrismaSpacing.md)
      }
      .onChange(of: viewModel.listFeedRefreshToken) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo("foryou-list-top", anchor: .top)
        }
      }
    }
  }

  private func refreshPreviewsIfNeeded(force: Bool = false) {
    let ids = viewModel.articles.prefix(30).map(\.id)
    if !force, ids == lastPreviewArticleIDs { return }
    lastPreviewArticleIDs = ids
    if force {
      previewStore.forceRefresh(for: viewModel.articles)
    } else {
      previewStore.refresh(for: viewModel.articles)
    }
  }

  private func clusterCard(_ cluster: ClusterDTO) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      HStack {
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(PrismaColors.textTertiary)
      }

      Text(cluster.title)
        .font(PrismaTypography.headline())
        .multilineTextAlignment(.leading)

      if let story = cluster.synthesizedStory ?? cluster.summary {
        Text(story)
          .font(PrismaTypography.callout())
          .foregroundStyle(PrismaColors.textSecondary)
          .lineLimit(3)
      }

      HStack(spacing: PrismaSpacing.xs) {
        if let sources = cluster.sourceNames {
          ForEach(sources.prefix(4), id: \.self) { source in
            Text(source)
              .font(PrismaTypography.caption2())
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(PrismaColors.elevatedSurface)
              .clipShape(Capsule())
          }
        }
        Spacer()
        Text(String(localized: "foryou.cluster.count \(cluster.articleIds.count)"))
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textTertiary)
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(PrismaTypography.title())
  }
}

extension ClusterDTO: Identifiable {}
