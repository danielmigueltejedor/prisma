import SwiftUI

struct ForYouCascadeView: View {
  @Bindable var viewModel: ForYouViewModel
  let makeReaderViewModel: (Article) -> ArticleReaderViewModel

  @State private var scrollPosition: String?
  @State private var visibleArticleID: String?
  @ObservedObject private var speechReader = ArticleSpeechReader.shared

  private var articles: [Article] {
    Array(viewModel.cascadeArticles.prefix(40))
  }

  var body: some View {
    Group {
      if articles.isEmpty {
        EmptyStateView(
          icon: "sparkles",
          title: String(localized: "foryou.empty.title"),
          message: String(localized: "foryou.empty.message")
        )
      } else {
        ScrollView(.vertical) {
          LazyVStack(spacing: 0) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
              CascadeArticlePageView(
                article: article,
                forYouViewModel: viewModel,
                makeReaderViewModel: makeReaderViewModel,
                recommendationReason: viewModel.recommendationReason(for: article),
                isSpeakingThisArticle: isSpeaking(article),
                onLike: { viewModel.handleCascadeLike(articleID: article.id) },
                onSave: { viewModel.handleCascadeSave(articleID: article.id) },
                isLast: index == articles.count - 1
              )
              .containerRelativeFrame(.vertical, count: 1, spacing: 0)
              .clipped()
              .id(article.id)
            }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .scrollIndicators(.hidden)
        .scrollClipDisabled(false)
        .animation(.none, value: articles.map(\.id))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onChange(of: scrollPosition) { oldValue, newValue in
          if let oldValue, oldValue != newValue {
            viewModel.completeCascadePage(articleID: oldValue)
          }
          if let newValue {
            viewModel.beginCascadePage(articleID: newValue)
            viewModel.preloadCascadeReaders(around: newValue, factory: makeReaderViewModel)
          }
          visibleArticleID = newValue
        }
        .onAppear {
          if scrollPosition == nil, let first = articles.first?.id {
            scrollPosition = first
            visibleArticleID = first
            viewModel.beginCascadePage(articleID: first)
            viewModel.preloadCascadeReaders(around: first, factory: makeReaderViewModel)
          }
        }
        .onChange(of: viewModel.cascadeFeedRefreshToken) { _, _ in
          jumpToFreshCascadeHead()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .safeAreaInset(edge: .top, spacing: 0) {
      if !articles.isEmpty {
        PrismaNavigationHeaderChrome {
          cascadeHeaderBar
        }
      }
    }
  }

  private func jumpToFreshCascadeHead() {
    guard let first = articles.first?.id else {
      scrollPosition = nil
      visibleArticleID = nil
      return
    }
    scrollPosition = first
    visibleArticleID = first
    viewModel.beginCascadePage(articleID: first)
    viewModel.preloadCascadeReaders(around: first, factory: makeReaderViewModel)
  }

  private var cascadeHeaderBar: some View {
    HStack(spacing: PrismaSpacing.sm) {
      Text(String(localized: "tab.foryou"))
        .font(PrismaTypography.headline())
        .foregroundStyle(PrismaColors.textPrimary)
        .lineLimit(1)
        .frame(maxWidth: .infinity)

      Text(String(localized: "settings.cascadeView.beta"))
        .font(PrismaTypography.caption2(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(PrismaColors.accentFallback.opacity(0.15))
        .clipShape(Capsule())
        .foregroundStyle(PrismaColors.accentFallback)
    }
    .padding(.horizontal, PrismaSpacing.md)
    .frame(minHeight: 48)
    .padding(.top, PrismaSpacing.xxs)
    .padding(.bottom, PrismaSpacing.sm)
  }

  private func isSpeaking(_ article: Article) -> Bool {
    speechReader.isSpeaking
      && speechReader.currentArticleID == article.id
      && visibleArticleID == article.id
  }
}

private struct CascadeArticlePageView: View {
  @Environment(\.openURL) private var openURL

  let article: Article
  let forYouViewModel: ForYouViewModel
  let makeReaderViewModel: (Article) -> ArticleReaderViewModel
  var recommendationReason: String?
  let isSpeakingThisArticle: Bool
  let onLike: () -> Void
  let onSave: () -> Void
  let isLast: Bool

  @State private var readerViewModel: ArticleReaderViewModel?
  @State private var showShare = false
  @State private var showMediaGallery = false
  @State private var galleryIndex = 0
  @State private var activeLikeBurst: (id: UUID, location: CGPoint)?
  @State private var aiSheet: CascadeAISheet?

  var body: some View {
    Group {
      if let readerViewModel {
        cascadePageContent(readerViewModel)
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task(id: article.id) {
      await Task.yield()
      guard !Task.isCancelled else { return }
      readerViewModel = forYouViewModel.cascadeReader(for: article, factory: makeReaderViewModel)
    }
  }

  @ViewBuilder
  private func cascadePageContent(_ readerViewModel: ArticleReaderViewModel) -> some View {
    ZStack(alignment: .trailing) {
      ScrollView {
        VStack(alignment: .leading, spacing: PrismaSpacing.md) {
          cascadeHeader(readerViewModel)
          cascadeBody(readerViewModel)
          cascadeFooter(readerViewModel)
        }
        .padding(.horizontal, PrismaSpacing.lg)
        .padding(.top, PrismaSpacing.md)
        .padding(.bottom, PrismaSpacing.xl)
        .padding(.trailing, 56)
      }
      .coordinateSpace(name: "cascadeArticleScroll")
      .overlay {
        if let burst = activeLikeBurst {
          CascadeLikeBurst(location: burst.location)
            .id(burst.id)
        }
      }
      .simultaneousGesture(
        SpatialTapGesture(count: 2, coordinateSpace: .local)
          .onEnded { value in
            triggerDoubleTapLike(at: value.location, readerViewModel: readerViewModel)
          }
      )

      CascadeActionRail(
        isSaved: readerViewModel.isSaved,
        isFavorite: readerViewModel.isFavorite,
        isSpeaking: isSpeakingThisArticle,
        canUseAI: readerViewModel.canUseAI,
        onLike: { performLikeToggle(readerViewModel) },
        onSave: {
          readerViewModel.toggleSaved()
          onSave()
        },
        onShare: { showShare = true },
        onSpeak: { toggleSpeech() },
        onSummary: { openAISheet(.summary, readerViewModel: readerViewModel) },
        onContext: { openAISheet(.context, readerViewModel: readerViewModel) }
      )
      .padding(.trailing, PrismaSpacing.sm)
      .padding(.bottom, 96)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .clipped()
    .sheet(isPresented: $showShare) {
      ShareSheet(items: shareItems)
    }
    .fullScreenCover(isPresented: $showMediaGallery) {
      ArticleMediaGalleryView(
        mediaItems: readerViewModel.mediaItems,
        selectedIndex: $galleryIndex
      )
    }
    .sheet(item: $aiSheet) { sheet in
      CascadeAISheetView(sheet: sheet, viewModel: readerViewModel)
    }
    .onAppear {
      readerViewModel.onAppear()
    }
    .task(id: article.id) {
      try? await Task.sleep(nanoseconds: 450_000_000)
      guard !Task.isCancelled, readerViewModel.canUseAI else { return }
      await readerViewModel.prefetchSummaryIfNeeded()
      await readerViewModel.prefetchContextIfNeeded()
    }
    .onDisappear {
      readerViewModel.onDisappear()
    }
  }

  @ViewBuilder
  private func cascadeHeader(_ viewModel: ArticleReaderViewModel) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      if viewModel.isLiveCoverage {
        LiveCoverageDot()
      }

      if let recommendationReason, !recommendationReason.isEmpty {
        Text(recommendationReason)
          .font(PrismaTypography.caption2(.semibold))
          .foregroundStyle(PrismaColors.accentFallback.opacity(0.9))
          .lineLimit(2)
      }

      Text(viewModel.displayTitle)
        .font(PrismaTypography.readerTitle())
        .foregroundStyle(PrismaColors.textPrimary)

      HStack(spacing: PrismaSpacing.xs) {
        if let source = viewModel.resolvedSource {
          SourceIconView(
            siteURL: source.siteURL,
            feedURL: source.feedURL,
            platform: source.effectivePlatform,
            size: 18
          )
          Text(source.name)
            .font(PrismaTypography.caption(.semibold))
            .foregroundStyle(PrismaColors.accentFallback)
        } else {
          Text(article.sourceName)
            .font(PrismaTypography.caption(.semibold))
            .foregroundStyle(PrismaColors.accentFallback)
        }

        if let publishedAt = article.publishedAt {
          Text("·")
            .foregroundStyle(PrismaColors.textTertiary)
          Text(publishedAt, style: .relative)
            .font(PrismaTypography.caption2())
            .foregroundStyle(PrismaColors.textTertiary)
        }
      }
    }
  }

  @ViewBuilder
  private func cascadeBody(_ viewModel: ArticleReaderViewModel) -> some View {
    if viewModel.needsTranslation {
      cascadeTranslationBanner(viewModel)
    }

    if let plain = viewModel.plainBodyText, viewModel.hasReadableInAppContent {
      Text(plain)
        .font(PrismaTypography.readerBody(
          sizeMultiplier: viewModel.readerFontSizeMultiplier,
          family: viewModel.readerFontFamily
        ))
        .foregroundStyle(PrismaColors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    } else if let html = viewModel.bodyHTML, viewModel.hasReadableInAppContent {
      ArticleHTMLView(
        html: html,
        baseURL: URL(string: article.url),
        fontFamily: viewModel.readerFontFamily,
        fontSizeMultiplier: viewModel.readerFontSizeMultiplier,
        suppressInlineImages: !viewModel.mediaItems.isEmpty,
        onOpenExternalURL: { url in openURL(url) }
      )
    } else if let summary = article.displaySummary {
      Text(summary)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
    }

    if !viewModel.mediaItems.isEmpty {
      ArticleMediaCarousel(mediaItems: viewModel.mediaItems) { index in
        galleryIndex = index
        showMediaGallery = true
      }
      .padding(.top, PrismaSpacing.sm)
    }
  }

  @ViewBuilder
  private func cascadeFooter(_ viewModel: ArticleReaderViewModel) -> some View {
    if isLast {
      Text(String(localized: "cascade.end"))
        .font(PrismaTypography.caption())
        .foregroundStyle(PrismaColors.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, PrismaSpacing.md)
    }
  }

  private var shareItems: [Any] {
    var items: [Any] = [article.title]
    if let url = URL(string: article.url) {
      items.append(url)
    }
    return items
  }

  private func performLikeToggle(_ readerViewModel: ArticleReaderViewModel) {
    let wasFavorite = readerViewModel.isFavorite
    readerViewModel.toggleFavorite()
    if readerViewModel.isFavorite, !wasFavorite {
      HapticFeedback.medium()
      onLike()
    }
  }

  private func triggerDoubleTapLike(at location: CGPoint, readerViewModel: ArticleReaderViewModel) {
    activeLikeBurst = (UUID(), location)
    guard !readerViewModel.isFavorite else { return }
    HapticFeedback.medium()
    readerViewModel.likeFromCascade()
    onLike()
  }

  private func toggleSpeech() {
    ArticleSpeechReader.shared.toggleSpeech(for: ArticleSpeechContent(article: article))
  }

  private func openAISheet(_ sheet: CascadeAISheet, readerViewModel: ArticleReaderViewModel) {
    aiSheet = sheet
    Task {
      switch sheet {
      case .summary:
        await readerViewModel.prefetchSummaryIfNeeded()
      case .context:
        await readerViewModel.prefetchContextIfNeeded()
      }
    }
  }

  @ViewBuilder
  private func cascadeTranslationBanner(_ viewModel: ArticleReaderViewModel) -> some View {
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
}

private struct CascadeLikeBurst: View {
  let location: CGPoint

  @State private var scale: CGFloat = 0.4
  @State private var opacity: Double = 1

  var body: some View {
    Image(systemName: "heart.fill")
      .font(.system(size: 88, weight: .bold))
      .foregroundStyle(.red.opacity(0.92))
      .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
      .scaleEffect(scale)
      .opacity(opacity)
      .position(location)
      .allowsHitTesting(false)
      .onAppear {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
          scale = 1.1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
          opacity = 0
          scale = 1.35
        }
      }
  }
}

private struct CascadeActionRail: View {
  let isSaved: Bool
  let isFavorite: Bool
  let isSpeaking: Bool
  var canUseAI = false
  let onLike: () -> Void
  let onSave: () -> Void
  let onShare: () -> Void
  let onSpeak: () -> Void
  var onSummary: (() -> Void)?
  var onContext: (() -> Void)?

  var body: some View {
    VStack(spacing: PrismaSpacing.md) {
      if canUseAI, let onSummary {
        CascadeRailButton(
          systemName: "sparkles",
          label: String(localized: "reader.showSummary"),
          action: onSummary
        )
      }
      if canUseAI, let onContext {
        CascadeRailButton(
          systemName: "info.circle",
          label: String(localized: "reader.showContext"),
          action: onContext
        )
      }
      CascadeRailButton(
        systemName: isFavorite ? "heart.fill" : "heart",
        label: String(localized: "action.favorite"),
        isActive: isFavorite,
        action: onLike
      )
      CascadeRailButton(
        systemName: "square.and.arrow.up",
        label: String(localized: "action.share"),
        action: onShare
      )
      CascadeRailButton(
        systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2",
        label: String(localized: "action.readAloud"),
        isActive: isSpeaking,
        action: onSpeak
      )
      CascadeRailButton(
        systemName: isSaved ? "bookmark.fill" : "bookmark",
        label: String(localized: "action.save"),
        isActive: isSaved,
        action: onSave
      )
    }
    .padding(.vertical, PrismaSpacing.sm)
    .padding(.horizontal, PrismaSpacing.xxs)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: PrismaRadius.lg, style: .continuous))
  }
}

private struct CascadeRailButton: View {
  let systemName: String
  let label: String
  var badge: Int? = nil
  var isActive = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        ZStack(alignment: .topTrailing) {
          Image(systemName: systemName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(isActive ? PrismaColors.accentFallback : PrismaColors.textPrimary)
            .frame(width: 28, height: 28)
          if let badge, badge > 0 {
            Text("\(min(badge, 99))")
              .font(.system(size: 9, weight: .bold))
              .padding(3)
              .background(Color.red)
              .foregroundStyle(.white)
              .clipShape(Circle())
              .offset(x: 6, y: -6)
          }
        }
        Text(label)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(PrismaColors.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(width: 52)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

private enum CascadeAISheet: String, Identifiable {
  case summary
  case context

  var id: String { rawValue }
}

private struct CascadeAISheetView: View {
  @Environment(\.dismiss) private var dismiss
  let sheet: CascadeAISheet
  @Bindable var viewModel: ArticleReaderViewModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: PrismaSpacing.md) {
          if isLoading {
            HStack(spacing: PrismaSpacing.sm) {
              ProgressView()
              Text(loadingText)
                .font(PrismaTypography.callout())
                .foregroundStyle(PrismaColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PrismaSpacing.lg)
          } else if let text = contentText, !text.isEmpty {
            Text(text)
              .font(PrismaTypography.body())
              .foregroundStyle(PrismaColors.textPrimary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(PrismaSpacing.lg)
          } else {
            Text(String(localized: "ai.unavailable.body"))
              .font(PrismaTypography.callout())
              .foregroundStyle(PrismaColors.textSecondary)
              .padding(PrismaSpacing.lg)
          }

          Text(String(localized: "reader.aiDisclaimer"))
            .font(PrismaTypography.caption2())
            .foregroundStyle(PrismaColors.textTertiary)
            .padding(.horizontal, PrismaSpacing.lg)
            .padding(.bottom, PrismaSpacing.lg)
        }
      }
      .background { GlassBackground() }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "action.close")) { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var title: String {
    switch sheet {
    case .summary:
      String(localized: "reader.aiSummary")
    case .context:
      String(localized: "reader.context")
    }
  }

  private var loadingText: String {
    switch sheet {
    case .summary:
      String(localized: "reader.summaryPreparing")
    case .context:
      String(localized: "reader.contextPreparing")
    }
  }

  private var isLoading: Bool {
    switch sheet {
    case .summary:
      viewModel.shouldShowSummaryPreparing
    case .context:
      viewModel.isGeneratingContext && !viewModel.hasContextAvailable
    }
  }

  private var contentText: String? {
    switch sheet {
    case .summary:
      viewModel.aiSummary
    case .context:
      viewModel.contextExplanation
    }
  }
}
