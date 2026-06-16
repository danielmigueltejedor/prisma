import SwiftUI
import SafariServices

struct ArticleReaderView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var viewModel: ArticleReaderViewModel
  var onShowPaywall: () -> Void
  var onSelectArticle: ((Article) -> Void)?

  @State private var showSafari = false
  @State private var safariURL: URL?
  @State private var showSimilarBar = false
  @State private var readerMode = true

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: PrismaSpacing.lg) {
          header
          if let imageURL = viewModel.article.imageUrl.flatMap(URL.init(string:)) {
            AsyncImage(url: imageURL) { phase in
              if case .success(let image) = phase {
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(maxHeight: 220)
                  .clipShape(RoundedRectangle(cornerRadius: PrismaRadius.lg, style: .continuous))
              }
            }
          }

          articleBody

          if viewModel.needsPartialNotice {
            partialNoticeBanner
          }

          plusActions

          if let summary = viewModel.aiSummary {
            aiResultCard(title: String(localized: "reader.aiSummary"), text: summary)
          }
          if let comparison = viewModel.comparisonText {
            aiResultCard(title: String(localized: "reader.compare"), text: comparison)
          }
          if let context = viewModel.contextExplanation {
            aiResultCard(title: String(localized: "reader.context"), text: context)
          }

          if !viewModel.similarArticles.isEmpty {
            SimilarArticlesSection(articles: viewModel.similarArticles) { article in
              onSelectArticle?(article)
            }
            .onAppear { showSimilarBar = true }
            .onDisappear { showSimilarBar = false }
          }

          attributionFooter
        }
        .padding(PrismaSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background { GlassBackground() }
      .overlay {
        if viewModel.isLoadingAI {
          Color.black.opacity(0.15).ignoresSafeArea()
          ProgressView()
            .padding()
            .prismaGlass()
        }
      }
      .safeAreaInset(edge: .bottom) {
        if showSimilarBar, !viewModel.similarArticles.isEmpty {
          SimilarArticlesSection(
            articles: viewModel.similarArticles,
            onSelect: { onSelectArticle?($0) },
            compact: true
          )
          .padding(.horizontal, PrismaSpacing.md)
          .padding(.vertical, PrismaSpacing.sm)
          .background(.ultraThinMaterial)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
              .symbolRenderingMode(.hierarchical)
          }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
          if viewModel.hasReadableInAppContent {
            Button {
              readerMode.toggle()
            } label: {
              Label(
                readerMode
                  ? String(localized: "reader.readingModeOn")
                  : String(localized: "reader.readingModeOff"),
                systemImage: readerMode ? "text.book.closed.fill" : "text.book.closed"
              )
              .labelStyle(.iconOnly)
            }
            .accessibilityLabel(
              readerMode
                ? String(localized: "reader.readingModeOn")
                : String(localized: "reader.readingModeOff")
            )
          }
          Button { openInBrowser() } label: {
            Label(String(localized: "reader.openInBrowser"), systemImage: "safari")
              .labelStyle(.iconOnly)
          }
          Button { viewModel.toggleSaved() } label: {
            Image(systemName: viewModel.article.isSaved ? "bookmark.fill" : "bookmark")
          }
          Button { viewModel.toggleFavorite() } label: {
            Image(systemName: viewModel.article.isFavorite ? "star.fill" : "star")
          }
        }
      }
      .onAppear { viewModel.onAppear() }
      .sheet(isPresented: $showSafari) {
        if let safariURL {
          SafariView(url: safariURL)
        }
      }
    }
  }

  @ViewBuilder
  private var articleBody: some View {
    if let html = viewModel.bodyHTML, viewModel.hasReadableInAppContent {
      VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
        if readerMode {
          HStack(spacing: PrismaSpacing.xs) {
            Image(systemName: "text.book.closed.fill")
              .foregroundStyle(PrismaColors.accentFallback)
            Text(String(localized: "reader.readingModeActive"))
              .font(PrismaTypography.caption(.semibold))
              .foregroundStyle(PrismaColors.textSecondary)
          }
        }
        ArticleHTMLView(
          html: html,
          readerMode: readerMode,
          fontSizeMultiplier: viewModel.fontSizeMultiplier
        )
      }
    } else if let plain = viewModel.plainBodyText {
      Text(plain)
        .font(PrismaTypography.readerBody())
        .foregroundStyle(PrismaColors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
        Text(String(localized: "reader.noContent"))
          .font(PrismaTypography.body())
          .foregroundStyle(PrismaColors.textSecondary)
        PrismaButton(title: String(localized: "reader.openInBrowser"), style: .primary) {
          openInBrowser()
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(viewModel.article.title)
        .font(PrismaTypography.readerTitle())
        .foregroundStyle(PrismaColors.textPrimary)

      HStack(spacing: PrismaSpacing.xs) {
        SourceIconView(
          siteURL: viewModel.article.feedSource?.siteURL,
          feedURL: viewModel.article.originalFeedUrl,
          size: 20
        )
        Text(viewModel.article.sourceName)
          .font(PrismaTypography.callout(.semibold))
          .foregroundStyle(PrismaColors.accentFallback)

        if let author = viewModel.article.authorName {
          Text("·")
          Text(author)
            .font(PrismaTypography.callout())
            .foregroundStyle(PrismaColors.textSecondary)
        }

        if let date = viewModel.article.publishedAt {
          Text("·")
          Text(date, style: .date)
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textTertiary)
        }
      }
    }
  }

  private var partialNoticeBanner: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(String(localized: "reader.partialNotice"))
        .font(PrismaTypography.callout())
        .foregroundStyle(PrismaColors.textSecondary)
      PrismaButton(title: String(localized: "reader.openInBrowser"), style: .secondary) {
        openInBrowser()
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private var plusActions: some View {
    VStack(spacing: PrismaSpacing.sm) {
      plusButton(
        title: String(localized: "reader.aiSummary"),
        icon: "sparkles",
        feature: .aiSummary
      ) {
        await handlePlus { await viewModel.performPlusAction(.summary) }
      }

      if viewModel.canCompareSources {
        plusButton(
          title: String(localized: "reader.compare"),
          icon: "arrow.left.arrow.right",
          feature: .compareSources
        ) {
          await handlePlus { await viewModel.performPlusAction(.compare) }
        }
      }

      plusButton(
        title: String(localized: "reader.context"),
        icon: "info.circle",
        feature: .aiSummary
      ) {
        await handlePlus { await viewModel.performPlusAction(.context) }
      }
    }
  }

  private func plusButton(
    title: String,
    icon: String,
    feature: PlusFeature,
    action: @escaping () async -> Void
  ) -> some View {
    Button {
      Task { await action() }
    } label: {
      HStack {
        Image(systemName: icon)
        Text(title)
        Spacer()
        if !viewModel.isPlusActive {
          PrismaPlusBadge()
        }
      }
      .font(PrismaTypography.callout(.medium))
      .padding(PrismaSpacing.md)
      .prismaGlass(cornerRadius: PrismaRadius.md)
    }
    .buttonStyle(.plain)
  }

  private func handlePlus(action: () async -> Bool) async {
    if viewModel.isPlusActive {
      _ = await action()
    } else {
      onShowPaywall()
    }
  }

  private func aiResultCard(title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      HStack {
        PrismaPlusBadge()
        Text(title)
          .font(PrismaTypography.headline())
      }
      Text(text)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private var attributionFooter: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
      Divider()
      Text(String(localized: "reader.attribution"))
        .font(PrismaTypography.caption())
        .foregroundStyle(PrismaColors.textTertiary)
      Button(String(localized: "reader.openInBrowser")) {
        openInBrowser()
      }
      .font(PrismaTypography.callout(.semibold))
    }
    .padding(.top, PrismaSpacing.md)
  }

  private func openInBrowser() {
    guard let url = URL(string: viewModel.article.url) else { return }
    safariURL = url
    showSafari = true
  }
}

struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> SFSafariViewController {
    SFSafariViewController(url: url)
  }

  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
