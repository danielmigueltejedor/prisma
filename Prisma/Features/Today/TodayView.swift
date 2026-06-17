import SwiftUI
import SwiftData

struct TodayView: View {
  @Bindable var viewModel: TodayViewModel
  var onSelectArticle: (Article) -> Void

  var body: some View {
    NavigationStack {
      PrismaScreen {
        if viewModel.isLoading && viewModel.articles.isEmpty {
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
          ScrollView {
            LazyVStack(alignment: .leading, spacing: PrismaSpacing.lg) {
              HStack {
                Toggle(String(localized: "filter.unread"), isOn: $viewModel.showUnreadOnly)
                  .font(PrismaTypography.caption())
                  .onChange(of: viewModel.showUnreadOnly) { _, _ in
                    viewModel.performSearch()
                  }
              }

              if !viewModel.trendingArticles.isEmpty {
                sectionHeader("Tendencias")
                articleList(viewModel.trendingArticles)
              }

              sectionHeader(String(localized: "today.section.latest"))
              articleList(viewModel.displayedArticles.prefix(20).map { $0 })

              if !viewModel.favoriteSourceArticles.isEmpty {
                sectionHeader(String(localized: "today.section.favorites"))
                articleList(viewModel.favoriteSourceArticles)
              }

              if !viewModel.recentlySaved.isEmpty {
                sectionHeader(String(localized: "today.section.saved"))
                articleList(viewModel.recentlySaved)
              }
            }
            .padding(PrismaSpacing.md)
          }
          .refreshable { await viewModel.refresh() }
        }
      }
      .navigationTitle(String(localized: "tab.today"))
      .searchable(text: $viewModel.searchText, prompt: String(localized: "search.prompt"))
      .onChange(of: viewModel.searchText) { _, _ in
        viewModel.performSearch()
      }
      .onAppear {
        viewModel.load()
        if viewModel.articles.isEmpty {
          Task { await viewModel.refresh() }
        }
      }
    }
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(PrismaTypography.title())
      .foregroundStyle(PrismaColors.textPrimary)
      .padding(.top, PrismaSpacing.xs)
  }

  private func articleList(_ items: [Article]) -> some View {
    LazyVStack(spacing: PrismaSpacing.sm) {
      ForEach(items, id: \.id) { article in
        Button { onSelectArticle(article) } label: {
          ArticleCard(
            title: article.title,
            sourceName: article.sourceName,
            publishedAt: article.publishedAt,
            summary: HTMLSanitizer.stripHTML(article.summary),
            imageURL: article.imageUrl.flatMap(URL.init(string:)),
            isRead: article.isRead,
            isSaved: article.isSaved,
            likeCount: article.likeCount,
            viewCount: article.viewCount,
            readingTimeMinutes: article.readingTimeEstimate,
            sourceSiteURL: article.feedSource?.siteURL,
            sourceFeedURL: article.originalFeedUrl
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}
