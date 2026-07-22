import SwiftUI

struct ForYouView: View {
  @Bindable var viewModel: ForYouViewModel
  var previewStore: ArticlePreviewTranslationStore
  var weather: WeatherSnapshot?
  var makeReaderViewModel: (Article) -> ArticleReaderViewModel
  var onSelectArticle: (Article) -> Void
  var onOpenSources: (() -> Void)?

  @State private var showErrorAlert = false

  var body: some View {
    NavigationStack {
      feedScreen
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
      } else {
        ForYouCascadeView(
          viewModel: viewModel,
          makeReaderViewModel: makeReaderViewModel,
          onOpenArticle: onSelectArticle
        )
      }
    }
    .navigationTitle("")
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      if !viewModel.articles.isEmpty {
        PrismaNavigationHeaderChrome {
          ForYouNavigationBar(weather: weather)
        }
      }
    }
    .onAppear {
      viewModel.loadIfNeeded()
    }
    .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
      viewModel.handleFeedsRefreshed()
    }
    .onReceive(NotificationCenter.default.publisher(for: .articleLibraryDidChange)) { _ in
      viewModel.handleLibraryChanged()
    }
    .onReceive(NotificationCenter.default.publisher(for: .preferencesDidChange)) { _ in
      viewModel.handlePreferencesChanged()
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
  }
}

private struct ForYouNavigationBar: View {
  let weather: WeatherSnapshot?

  var body: some View {
    HStack(spacing: PrismaSpacing.sm) {
      Text(String(localized: "tab.foryou"))
        .font(PrismaTypography.headline())
        .foregroundStyle(PrismaColors.textPrimary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)

      TodayWeatherBadge(weather: weather)
    }
    .padding(.horizontal, PrismaSpacing.md)
    .frame(minHeight: 48)
    .padding(.top, PrismaSpacing.xxs)
    .padding(.bottom, PrismaSpacing.sm)
  }
}
