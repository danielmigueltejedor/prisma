import SwiftUI

struct ForYouView: View {
  @Bindable var viewModel: ForYouViewModel
  var previewStore: ArticlePreviewTranslationStore
  var makeReaderViewModel: (Article) -> ArticleReaderViewModel
  var onSelectArticle: (Article) -> Void

  @State private var selectedCluster: ClusterDTO?
  @State private var lastPreviewArticleIDs: [String] = []

  var body: some View {
    NavigationStack {
      PrismaScreen {
        if viewModel.articles.isEmpty {
          EmptyStateView(
            icon: "sparkles",
            title: String(localized: "foryou.empty.title"),
            message: String(localized: "foryou.empty.message")
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
        previewStore.refresh(for: viewModel.articles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
        viewModel.handleFeedsRefreshed()
        previewStore.refresh(for: viewModel.articles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .articleLibraryDidChange)) { _ in
        viewModel.handleLibraryChanged()
        previewStore.refresh(for: viewModel.articles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .preferencesDidChange)) { _ in
        viewModel.handlePreferencesChanged()
      }
      .overlay {
        if !viewModel.cascadeViewEnabled, viewModel.isLoadingAI, viewModel.clusters.isEmpty {
          ProgressView()
            .padding()
            .prismaGlass()
        }
      }
      .sheet(item: $selectedCluster) { cluster in
        ClusterDetailView(
          cluster: cluster,
          articles: viewModel.articles(for: cluster),
          previewStore: previewStore,
          onSelectArticle: { article in
            selectedCluster = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              onSelectArticle(article)
            }
          }
        )
      }
    }
  }

  private var listFeed: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: PrismaSpacing.lg) {
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
            TranslatedArticleCard(article: article, previewStore: previewStore)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(PrismaSpacing.md)
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
