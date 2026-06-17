import SwiftUI

struct SourceDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Bindable var viewModel: SourceDetailViewModel
  var previewStore: ArticlePreviewTranslationStore
  var onSelectArticle: (Article) -> Void

  var body: some View {
    NavigationStack {
      PrismaScreen {
        if viewModel.articles.isEmpty, !viewModel.isRefreshing {
          EmptyStateView(
            icon: viewModel.source.effectivePlatform.systemImage,
            title: String(localized: "source.empty.title"),
            message: String(localized: "source.empty.message"),
            actionTitle: String(localized: "action.refresh"),
            action: { Task { await viewModel.refresh() } }
          )
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: PrismaSpacing.lg) {
              header
              articlesSection
            }
            .padding(PrismaSpacing.md)
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .top, spacing: 0) {
        HStack {
          PrismaDismissButton { dismiss() }
          Spacer()
          Button {
            Task { await viewModel.refresh() }
          } label: {
            if viewModel.isRefreshing {
              ProgressView()
            } else {
              Image(systemName: "arrow.clockwise")
                .font(.system(size: 17, weight: .medium))
            }
          }
          .disabled(viewModel.isRefreshing)
          .buttonStyle(.plain)
        }
        .padding(.horizontal, PrismaSpacing.md)
        .padding(.vertical, PrismaSpacing.xs)
      }
      .toolbar(.hidden, for: .navigationBar)
      .onAppear {
        viewModel.loadIfNeeded()
        previewStore.refresh(for: viewModel.articles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
        viewModel.handleFeedsRefreshed()
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.md) {
      HStack(spacing: PrismaSpacing.md) {
        SourceIconView(
          siteURL: viewModel.source.siteURL,
          feedURL: viewModel.source.feedURL,
          platform: viewModel.source.effectivePlatform,
          size: 56
        )

        VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
          Text(viewModel.source.name)
            .font(PrismaTypography.title())

          PlatformBadge(platform: viewModel.source.effectivePlatform)

          if let siteURL = viewModel.source.siteURL, let url = SafeURL.httpURL(from: siteURL) {
            Button {
              openURL(url)
            } label: {
              Text(siteURL.replacingOccurrences(of: "https://", with: ""))
                .font(PrismaTypography.caption())
                .foregroundStyle(PrismaColors.accentFallback)
                .lineLimit(1)
            }
            .buttonStyle(.plain)
          }
        }
      }

      Text(viewModel.displayDescription)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)

      if viewModel.source.effectivePlatform == .x {
        HStack(spacing: PrismaSpacing.xs) {
          Image(systemName: "info.circle")
            .foregroundStyle(PrismaColors.textTertiary)
          Text(String(localized: "source.x.bridgeNotice"))
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textTertiary)
        }
        .padding(PrismaSpacing.sm)
        .prismaGlass(cornerRadius: PrismaRadius.md)
      }

      HStack {
        Text(String(localized: "source.articleCount \(viewModel.articles.count)"))
          .font(PrismaTypography.caption(.semibold))
          .foregroundStyle(PrismaColors.textSecondary)
        Spacer()
        if let lastFetched = viewModel.source.lastFetchedAt {
          Text(String(localized: "source.lastUpdated \(lastFetched.formatted(date: .abbreviated, time: .shortened))"))
            .font(PrismaTypography.caption2())
            .foregroundStyle(PrismaColors.textTertiary)
        }
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private var articlesSection: some View {
    ForEach(viewModel.articles, id: \.id) { article in
      Button { onSelectArticle(article) } label: {
        TranslatedArticleCard(article: article, previewStore: previewStore)
      }
      .buttonStyle(.plain)
    }
  }
}

struct PlatformBadge: View {
  let platform: FeedPlatform

  var body: some View {
    HStack(spacing: PrismaSpacing.xxs) {
      Image(systemName: platform.systemImage)
      Text(platform.displayName)
    }
    .font(PrismaTypography.caption2(.semibold))
    .padding(.horizontal, PrismaSpacing.xs)
    .padding(.vertical, PrismaSpacing.xxs)
    .background(PrismaColors.elevatedSurface)
    .foregroundStyle(PrismaColors.textSecondary)
    .clipShape(Capsule())
  }
}

extension FeedSource: Identifiable {}
