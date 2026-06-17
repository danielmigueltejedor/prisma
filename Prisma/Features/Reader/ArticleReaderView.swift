import SwiftUI

struct ArticleReaderView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Bindable var viewModel: ArticleReaderViewModel
  var onSelectArticle: ((Article) -> Void)?
  var onOpenSource: ((FeedSource) -> Void)?
  var onOpenAuthor: ((String) -> Void)?

  @State private var showSimilarBar = true
  @State private var showImageGallery = false
  @State private var galleryIndex = 0
  @State private var showShare = false
  @ObservedObject private var speechReader = ArticleSpeechReader.shared

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: PrismaSpacing.md) {
          header

          if viewModel.needsTranslation {
            translationBanner
          }

          if !viewModel.imageURLs.isEmpty {
            ArticleImageCarousel(imageURLs: viewModel.imageURLs) { index in
              galleryIndex = index
              showImageGallery = true
            }
          }

          if viewModel.showsNativeLiveTimeline {
            LiveTimelineView(
              entries: viewModel.liveEntries,
              isRefreshing: viewModel.isRefreshingLive,
              lastUpdated: viewModel.liveLastUpdated,
              onRefresh: {
                Task { await viewModel.refreshLiveTimeline() }
              }
            )
          }

          if !viewModel.showsNativeLiveTimeline || viewModel.liveEntries.count < 2 {
            articleBody
          }

          if viewModel.needsPartialNotice {
            partialNoticeBanner
          }

          if viewModel.isRedditPost {
            RedditCommentsSection(
              comments: viewModel.redditComments,
              isLoading: viewModel.isLoadingRedditComments,
              errorMessage: viewModel.redditCommentsError
            )
            .onAppear {
              viewModel.scheduleRedditCommentsIfNeeded()
            }
          }

          aiActions
            .padding(.top, PrismaSpacing.xxs)

          if let summary = viewModel.aiSummary, viewModel.showingSummary {
            aiResultCard(title: String(localized: "reader.aiSummary"), text: summary)
          }
          if let context = viewModel.contextExplanation, viewModel.showingContext {
            aiResultCard(title: String(localized: "reader.context"), text: context)
          }

          attributionFooter
        }
        .padding(PrismaSpacing.lg)
        .padding(
          .bottom,
          showSimilarBar && !viewModel.similarArticles.isEmpty ? PrismaSpacing.md : 0
        )
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
      }
      .background { GlassBackground() }
      .safeAreaInset(edge: .top, spacing: 0) {
        readerTopBar
      }
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .bottom) {
        if showSimilarBar, !viewModel.similarArticles.isEmpty {
          SimilarArticlesSection(
            articles: viewModel.similarArticles,
            onSelect: { onSelectArticle?($0) },
            compact: true,
            poweredByAI: viewModel.similarArticlesPoweredByAI,
            isLoadingAI: viewModel.isLoadingAISimilarArticles
          )
          .padding(.horizontal, PrismaSpacing.md)
          .padding(.top, PrismaSpacing.xs)
          .padding(.bottom, PrismaSpacing.xxs)
          .background(.ultraThinMaterial)
        }
      }
      .onAppear { viewModel.onAppear() }
      .onDisappear { viewModel.onDisappear() }
      .fullScreenCover(isPresented: $showImageGallery) {
        ArticleImageGalleryView(
          imageURLs: viewModel.imageURLs,
          selectedIndex: $galleryIndex
        )
      }
      .sheet(isPresented: $showShare) {
        ShareSheet(items: shareItems)
      }
    }
  }

  private var readerTopBar: some View {
    HStack(spacing: PrismaSpacing.sm) {
      PrismaDismissButton { dismiss() }

      Spacer()

      LiquidGlassToolbarGroup {
        if viewModel.hasReadableInAppContent {
          ReaderTypographyMenu(viewModel: viewModel)
        }
        ReaderToolbarIconButton(
          systemName: speechReader.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2",
          isActive: speechReader.isSpeaking,
          accessibilityLabel: String(localized: "action.readAloud")
        ) {
          toggleSpeech()
        }
        ReaderToolbarIconButton(
          systemName: "square.and.arrow.up",
          accessibilityLabel: String(localized: "action.share")
        ) {
          showShare = true
        }
        ReaderToolbarIconButton(
          systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark",
          isActive: viewModel.isSaved,
          accessibilityLabel: String(localized: "action.save")
        ) {
          viewModel.toggleSaved()
        }
        ReaderToolbarIconButton(
          systemName: viewModel.isFavorite ? "heart.fill" : "heart",
          isActive: viewModel.isFavorite,
          accessibilityLabel: String(localized: "action.favorite")
        ) {
          viewModel.toggleFavorite()
        }
      }
    }
    .padding(.horizontal, PrismaSpacing.md)
    .padding(.top, PrismaSpacing.xs)
    .padding(.bottom, PrismaSpacing.xs)
  }

  @ViewBuilder
  private var articleBody: some View {
    if let html = viewModel.bodyHTML, viewModel.hasReadableInAppContent {
      ArticleHTMLView(
        html: html,
        baseURL: normalizedArticleURL(),
        fontFamily: viewModel.readerFontFamily,
        fontSizeMultiplier: viewModel.readerFontSizeMultiplier,
        suppressInlineImages: !viewModel.imageURLs.isEmpty,
        onOpenExternalURL: { url in openURL(url) }
      )
    } else if let plain = viewModel.plainBodyText {
      Text(plain)
        .font(PrismaTypography.readerBody(
          sizeMultiplier: viewModel.readerFontSizeMultiplier,
          family: viewModel.readerFontFamily
        ))
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
      if viewModel.isLiveCoverage {
        LiveCoverageDot()
      }

      Text(viewModel.displayTitle)
        .font(PrismaTypography.readerTitle())
        .foregroundStyle(PrismaColors.textPrimary)
        .animation(.easeInOut(duration: 0.2), value: viewModel.displayTitle)

      HStack(spacing: PrismaSpacing.xs) {
        if let source = viewModel.resolvedSource {
          Button {
            onOpenSource?(source)
          } label: {
            HStack(spacing: PrismaSpacing.xs) {
              SourceIconView(
                siteURL: source.siteURL,
                feedURL: source.feedURL,
                platform: source.effectivePlatform,
                size: 20
              )
              Text(source.name)
                .font(PrismaTypography.callout(.semibold))
                .foregroundStyle(PrismaColors.accentFallback)
            }
          }
          .buttonStyle(.plain)
        } else {
          SourceIconView(
            siteURL: viewModel.article.feedSource?.siteURL,
            feedURL: viewModel.article.originalFeedUrl,
            size: 20
          )
          Text(viewModel.article.sourceName)
            .font(PrismaTypography.callout(.semibold))
            .foregroundStyle(PrismaColors.accentFallback)
        }

        if let author = viewModel.article.authorName {
          Text("·")
          Button {
            onOpenAuthor?(author)
          } label: {
            Text(author)
              .font(PrismaTypography.callout(.semibold))
              .foregroundStyle(PrismaColors.accentFallback)
          }
          .buttonStyle(.plain)
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

  private var translationBanner: some View {
    HStack(spacing: PrismaSpacing.sm) {
      if viewModel.isTranslating {
        ProgressView()
          .controlSize(.small)
        Text(String(localized: "reader.translating"))
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textSecondary)
      } else if viewModel.hasTranslation {
        Image(systemName: "character.book.closed")
          .foregroundStyle(PrismaColors.accentFallback)
        Text(String(localized: "reader.translatedTo \(viewModel.targetLanguageName)"))
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textSecondary)
        Spacer()
        Button(viewModel.isShowingTranslation
          ? String(localized: "reader.viewOriginal")
          : String(localized: "reader.viewTranslation")) {
          viewModel.toggleTranslationView()
        }
        .font(PrismaTypography.caption(.semibold))
      } else {
        Image(systemName: "character.book.closed")
          .foregroundStyle(PrismaColors.textTertiary)
        Text(String(localized: "reader.translationPending"))
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textTertiary)
        Spacer()
        Button(String(localized: "reader.viewTranslation")) {
          Task { await viewModel.prepareTranslation() }
        }
        .font(PrismaTypography.caption(.semibold))
      }
    }
    .padding(PrismaSpacing.sm)
    .prismaGlass(cornerRadius: PrismaRadius.md)
  }

  private var partialNoticeBanner: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(String(localized: "reader.partialNotice"))
        .font(PrismaTypography.callout())
        .foregroundStyle(PrismaColors.textSecondary)
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private var aiActions: some View {
    VStack(spacing: PrismaSpacing.sm) {
      if viewModel.hasSummaryAvailable {
        aiToggleButton(
          title: viewModel.showingSummary
            ? String(localized: "reader.hideSummary")
            : String(localized: "reader.showSummary"),
          icon: "sparkles",
          isActive: viewModel.showingSummary
        ) {
          viewModel.showingSummary.toggle()
        }
      } else if viewModel.shouldShowSummaryPreparing {
        aiStatusRow(
          icon: "sparkles",
          text: String(localized: "reader.summaryPreparing")
        )
      }

      if viewModel.hasComparisonAvailable {
        aiToggleButton(
          title: viewModel.showingComparison
            ? String(localized: "reader.hideComparison")
            : String(localized: "reader.showComparison"),
          icon: "arrow.left.arrow.right",
          isActive: viewModel.showingComparison
        ) {
          viewModel.showingComparison.toggle()
        }

        if viewModel.showingComparison {
          if !viewModel.verifiedSameStoryArticles.isEmpty {
            SimilarArticlesSection(
              articles: viewModel.verifiedSameStoryArticles,
              onSelect: { article in onSelectArticle?(article) },
              compact: true,
              poweredByAI: true
            )
          }

          if let unified = viewModel.unifiedStory, !unified.isEmpty {
            aiResultCard(title: String(localized: "reader.unifiedStory"), text: unified)
          }

          if let comparison = viewModel.comparisonText {
            aiResultCard(title: String(localized: "reader.compare"), text: comparison)
          }
        }
      } else if viewModel.isGeneratingComparison {
        aiStatusRow(
          icon: "arrow.left.arrow.right",
          text: String(localized: "reader.comparisonSearching")
        )
      }

      if viewModel.hasContextAvailable {
        aiToggleButton(
          title: viewModel.showingContext
            ? String(localized: "reader.hideContext")
            : String(localized: "reader.showContext"),
          icon: "info.circle",
          isActive: viewModel.showingContext
        ) {
          viewModel.showingContext.toggle()
        }
      } else if viewModel.isGeneratingContext {
        aiStatusRow(
          icon: "info.circle",
          text: String(localized: "reader.contextPreparing")
        )
      }

      if !viewModel.canUseAI {
        aiUnavailableHint
      } else {
        Text(String(localized: "reader.aiDisclaimer"))
          .font(PrismaTypography.caption2())
          .foregroundStyle(PrismaColors.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private func aiToggleButton(
    title: String,
    icon: String,
    isActive: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: icon)
        Text(title)
        Spacer()
        if isActive {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(PrismaColors.accentFallback)
        }
      }
      .font(PrismaTypography.callout(.medium))
      .padding(PrismaSpacing.md)
      .prismaGlass(cornerRadius: PrismaRadius.md)
      .opacity(viewModel.canUseAI ? 1 : 0.55)
    }
    .buttonStyle(.plain)
    .disabled(!viewModel.canUseAI)
  }

  private func aiStatusRow(icon: String, text: String) -> some View {
    HStack(spacing: PrismaSpacing.sm) {
      ProgressView()
        .controlSize(.small)
      Image(systemName: icon)
        .foregroundStyle(PrismaColors.textTertiary)
      Text(text)
        .font(PrismaTypography.caption())
        .foregroundStyle(PrismaColors.textSecondary)
      Spacer()
    }
    .padding(PrismaSpacing.md)
    .prismaGlass(cornerRadius: PrismaRadius.md)
  }

  private var aiUnavailableHint: some View {
    HStack(spacing: PrismaSpacing.xs) {
      Image(systemName: "apple.intelligence")
        .foregroundStyle(PrismaColors.textTertiary)
      Text(aiUnavailableMessage)
        .font(PrismaTypography.caption())
        .foregroundStyle(PrismaColors.textSecondary)
    }
    .padding(PrismaSpacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .prismaGlass(cornerRadius: PrismaRadius.md)
  }

  private var aiUnavailableMessage: String {
    if let key = AppleIntelligenceAvailability.current.userMessageKey {
      return String(localized: String.LocalizationValue(key))
    }
    return String(localized: "ai.unavailable.body")
  }

  private func aiResultCard(title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      HStack {
        Image(systemName: "sparkles")
          .foregroundStyle(PrismaColors.accentFallback)
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
      PrismaButton(title: String(localized: "reader.openInBrowser"), style: .secondary) {
        openInBrowser()
      }
    }
    .padding(.top, PrismaSpacing.md)
  }

  private func openInBrowser() {
    guard let url = normalizedArticleURL() else { return }
    openURL(url)
  }

  private func normalizedArticleURL() -> URL? {
    SafeURL.httpURL(from: viewModel.article.url)
  }

  private var shareItems: [Any] {
    var items: [Any] = [viewModel.displayTitle]
    if let url = normalizedArticleURL() {
      items.append(url)
    }
    return items
  }

  private func toggleSpeech() {
    speechReader.toggleSpeech(for: ArticleSpeechContent(article: viewModel.article))
  }
}
