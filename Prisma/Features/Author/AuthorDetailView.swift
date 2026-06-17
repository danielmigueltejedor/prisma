import SwiftUI

struct AuthorDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var viewModel: AuthorDetailViewModel
  var previewStore: ArticlePreviewTranslationStore
  var onSelectArticle: (Article) -> Void

  var body: some View {
    NavigationStack {
      PrismaScreen {
        if viewModel.articles.isEmpty, !viewModel.isRefreshing {
          EmptyStateView(
            icon: "person.crop.circle",
            title: String(localized: "author.empty.title"),
            message: String(localized: "author.empty.message"),
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
        ZStack {
          Circle()
            .fill(PrismaColors.accentFallback.opacity(0.15))
            .frame(width: 56, height: 56)
          Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 30))
            .foregroundStyle(PrismaColors.accentFallback)
        }

        VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
          Text(viewModel.authorName)
            .font(PrismaTypography.title())

          Text(String(localized: "author.profile"))
            .font(PrismaTypography.caption(.semibold))
            .foregroundStyle(PrismaColors.textSecondary)
        }
      }

      if !viewModel.sourceNames.isEmpty {
        Text(String(localized: "author.sources \(viewModel.sourceNames.joined(separator: ", "))"))
          .font(PrismaTypography.body())
          .foregroundStyle(PrismaColors.textSecondary)
      }

      Text(String(localized: "author.articleCount \(viewModel.articles.count)"))
        .font(PrismaTypography.caption(.semibold))
        .foregroundStyle(PrismaColors.textSecondary)
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
