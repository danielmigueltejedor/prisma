import SwiftUI

private enum CascadeLayout {
  static let railWidth: CGFloat = 58
  static let tabBarClearance: CGFloat = 8
  static let contentRailSpacing: CGFloat = 10
}

struct ForYouCascadeView: View {
  let viewModel: ForYouViewModel
  let makeReaderViewModel: (Article) -> ArticleReaderViewModel
  let onOpenArticle: (Article) -> Void

  @State private var scrollPosition: String?
  @State private var activeReader: ArticleReaderViewModel?
  @State private var committedArticleID: String?

  private var articles: [Article] {
    viewModel.cascadePages
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
        cascadePager
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      PrismaColors.background
        .ignoresSafeArea()
    }
    .clipped()
  }

  private var cascadePager: some View {
    ScrollView(.vertical) {
      LazyVStack(spacing: 0) {
        ForEach(articles) { article in
          cascadePage(for: article)
            .containerRelativeFrame(.vertical, count: 1, spacing: 0)
            .frame(maxWidth: .infinity)
            .id(article.id)
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)
    .scrollPosition(id: $scrollPosition)
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    .scrollClipDisabled(false)
    .onScrollPhaseChange { _, newPhase in
      let isScrolling = newPhase != .idle
      viewModel.setCascadeOuterScrollActive(isScrolling)
      if isScrolling {
        activeReader?.cancelBackgroundWork()
      }
      guard newPhase == .idle, let scrollPosition else { return }
      settlePage(articleID: scrollPosition)
    }
    .onAppear {
      guard activeReader == nil, let first = articles.first else { return }
      scrollPosition = first.id
      Task { @MainActor in
        await Task.yield()
        settlePage(articleID: first.id)
      }
    }
    .onChange(of: viewModel.cascadeFeedRefreshToken) { _, _ in
      guard let first = articles.first else {
        scrollPosition = nil
        activeReader = nil
        committedArticleID = nil
        return
      }
      scrollPosition = first.id
      committedArticleID = nil
      Task { @MainActor in
        await Task.yield()
        settlePage(articleID: first.id)
      }
    }
  }

  @ViewBuilder
  private func cascadePage(for article: Article) -> some View {
    let isActive = committedArticleID == article.id
    let showsActiveContent = isActive
      && activeReader != nil
      && activeReader?.isCascadePresentationReady == true

    ZStack {
      CascadeArticlePlaceholder(article: article)
        .opacity(showsActiveContent ? 0 : 1)
        .allowsHitTesting(!showsActiveContent)

      if showsActiveContent, let activeReader {
        CascadeArticleActivePage(
          article: article,
          readerViewModel: activeReader,
          recommendationReason: viewModel.recommendationReason(for: article),
          onLike: { viewModel.handleCascadeLike(articleID: article.id) },
          onSave: { viewModel.handleCascadeSave(articleID: article.id) },
          onOpenArticle: { onOpenArticle(article) },
          isLast: article.id == articles.last?.id
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private func settlePage(articleID: String) {
    guard articles.contains(where: { $0.id == articleID }) else { return }
    let previousID = committedArticleID
    guard previousID != articleID else { return }

    if let previousID, previousID != articleID {
      viewModel.handleCascadeScrollChange(from: previousID, to: articleID)
    }

    activeReader?.onDisappear()
    guard let article = articles.first(where: { $0.id == articleID }) else { return }
    activeReader = viewModel.activateCascadeReader(
      for: article,
      factory: makeReaderViewModel
    )
    activeReader?.syncLibraryState()
    activeReader?.onAppear()

    committedArticleID = articleID
    viewModel.beginCascadePage(articleID: articleID)
    if previousID == nil {
      viewModel.handleCascadeScrollChange(from: nil, to: articleID)
    }
  }

}

private struct CascadeArticlePlaceholder: View {
  let article: Article

  var body: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.md) {
      Text(article.title)
        .font(PrismaTypography.readerTitle())
        .foregroundStyle(PrismaColors.textPrimary)
        .lineLimit(4)
      Spacer(minLength: 0)
    }
    .padding(PrismaSpacing.lg)
    .padding(.bottom, CascadeLayout.tabBarClearance)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(PrismaColors.background)
    .clipped()
  }
}

private struct CascadeArticleActivePage: View {
  let article: Article
  @Bindable var readerViewModel: ArticleReaderViewModel
  var recommendationReason: String?
  let onLike: () -> Void
  let onSave: () -> Void
  let onOpenArticle: () -> Void
  let isLast: Bool

  @State private var showShare = false
  @State private var showMediaGallery = false
  @State private var galleryIndex = 0
  @State private var activeLikeBurst: (id: UUID, location: CGPoint)?
  @State private var aiSheet: CascadeAISheet?
  @ObservedObject private var speechReader = ArticleSpeechReader.shared

  private var isSpeakingThisArticle: Bool {
    speechReader.isSpeaking && speechReader.currentArticleID == article.id
  }

  private var showsReadFullAction: Bool {
    guard let plain = readerViewModel.plainBodyText else { return false }
    return plain.count > 400
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      pageContent
        .padding(.trailing, CascadeLayout.railWidth + CascadeLayout.contentRailSpacing)

      CascadeActionRail(
        isSaved: readerViewModel.isSaved,
        isFavorite: readerViewModel.isFavorite,
        isSpeaking: isSpeakingThisArticle,
        onLike: performLikeToggle,
        onSave: {
          readerViewModel.toggleSaved()
          onSave()
        },
        onShare: { showShare = true },
        onSpeak: { toggleSpeech() },
        onSummary: readerViewModel.hasSummaryAvailable
          ? { openAISheet(.summary) }
          : nil,
        onComparison: readerViewModel.hasComparisonAvailable
          ? { openAISheet(.comparison) }
          : nil,
        onContext: readerViewModel.hasContextAvailable
          ? { openAISheet(.context) }
          : nil
      )
      .frame(width: CascadeLayout.railWidth, alignment: .top)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    .padding(.horizontal, PrismaSpacing.lg)
    .padding(.top, PrismaSpacing.sm)
    .padding(.bottom, PrismaSpacing.lg + CascadeLayout.tabBarClearance)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(PrismaColors.background)
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
  }

  private var pageContent: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.md) {
      cascadeHeader
      cascadeBody
      if showsReadFullAction {
        readFullButton
      }
      cascadeFooter
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .overlay {
      if let burst = activeLikeBurst {
        CascadeLikeBurst(location: burst.location)
          .id(burst.id)
      }
    }
    .simultaneousGesture(
      SpatialTapGesture(count: 2, coordinateSpace: .local)
        .onEnded { value in
          triggerDoubleTapLike(at: value.location)
        }
    )
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var cascadeHeader: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      if let recommendationReason, !recommendationReason.isEmpty {
        Text(recommendationReason)
          .font(PrismaTypography.caption2(.semibold))
          .foregroundStyle(PrismaColors.accentFallback.opacity(0.9))
          .lineLimit(2)
      }

      Button(action: onOpenArticle) {
        Text(readerViewModel.displayTitle)
          .font(PrismaTypography.readerTitle())
          .foregroundStyle(PrismaColors.textPrimary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)

      HStack(spacing: PrismaSpacing.xs) {
        if let source = readerViewModel.resolvedSource {
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
  private var cascadeBody: some View {
    if readerViewModel.needsTranslation, readerViewModel.hasTranslation {
      cascadeTranslationBanner
    }

    if let plain = readerViewModel.plainBodyText,
       plain.trimmingCharacters(in: .whitespacesAndNewlines).count >= 80,
       readerViewModel.hasReadableInAppContent {
      Text(plain)
        .font(PrismaTypography.readerBody(
          sizeMultiplier: readerViewModel.readerFontSizeMultiplier,
          family: readerViewModel.readerFontFamily
        ))
        .foregroundStyle(PrismaColors.textPrimary)
        .lineLimit(showsReadFullAction ? 14 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    } else if let plain = readerViewModel.plainBodyText, readerViewModel.hasReadableInAppContent {
      Text(plain)
        .font(PrismaTypography.readerBody(
          sizeMultiplier: readerViewModel.readerFontSizeMultiplier,
          family: readerViewModel.readerFontFamily
        ))
        .foregroundStyle(PrismaColors.textPrimary)
        .lineLimit(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    } else if let summary = article.displaySummary {
      Text(summary)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
    } else {
      Text(String(localized: "reader.noContent"))
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textTertiary)
    }

    if !readerViewModel.mediaItems.isEmpty {
      ArticleMediaCarousel(
        mediaItems: readerViewModel.mediaItems,
        presentation: .cascade
      ) { index in
        galleryIndex = index
        showMediaGallery = true
      }
      .padding(.top, PrismaSpacing.sm)
    }
  }

  private var readFullButton: some View {
    Button(action: onOpenArticle) {
      Text(String(localized: "cascade.readFull"))
        .font(PrismaTypography.callout(.semibold))
        .foregroundStyle(PrismaColors.accentFallback)
        .frame(maxWidth: .infinity)
        .padding(.vertical, PrismaSpacing.sm)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var cascadeFooter: some View {
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

  private func performLikeToggle() {
    let wasFavorite = readerViewModel.isFavorite
    readerViewModel.toggleFavorite()
    guard readerViewModel.isFavorite, !wasFavorite else { return }
    HapticFeedback.medium()
    onLike()
  }

  private func triggerDoubleTapLike(at location: CGPoint) {
    guard !readerViewModel.isFavorite else { return }
    activeLikeBurst = (UUID(), location)
    HapticFeedback.medium()
    readerViewModel.likeFromCascade()
    onLike()
  }

  private func toggleSpeech() {
    ArticleSpeechReader.shared.toggleSpeech(for: ArticleSpeechContent(article: article))
  }

  private func openAISheet(_ sheet: CascadeAISheet) {
    aiSheet = sheet
  }

  @ViewBuilder
  private var cascadeTranslationBanner: some View {
    HStack(spacing: PrismaSpacing.sm) {
      Image(systemName: "character.book.closed")
        .foregroundStyle(PrismaColors.accentFallback)
      Text(String(localized: "reader.translatedTo \(readerViewModel.targetLanguageName)"))
        .font(PrismaTypography.caption())
        .foregroundStyle(PrismaColors.textSecondary)
      Spacer()
      Button(readerViewModel.isShowingTranslation
        ? String(localized: "reader.viewOriginal")
        : String(localized: "reader.viewTranslation")) {
        readerViewModel.toggleTranslationView()
      }
      .font(PrismaTypography.caption(.semibold))
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
  let onLike: () -> Void
  let onSave: () -> Void
  let onShare: () -> Void
  let onSpeak: () -> Void
  var onSummary: (() -> Void)?
  var onComparison: (() -> Void)?
  var onContext: (() -> Void)?

  var body: some View {
    VStack(spacing: PrismaSpacing.md) {
      if let onSummary {
        CascadeRailButton(
          systemName: "sparkles",
          label: String(localized: "reader.showSummary"),
          action: onSummary
        )
      }
      if let onComparison {
        CascadeRailButton(
          systemName: "arrow.left.arrow.right",
          label: String(localized: "reader.showComparison"),
          action: onComparison
        )
      }
      if let onContext {
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
    .modifier(CascadeRailGlassBackground())
  }
}

private struct CascadeRailGlassBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: PrismaRadius.lg))
    } else {
      content
        .prismaGlass(cornerRadius: PrismaRadius.lg)
    }
  }
}

private struct CascadeRailButton: View {
  let systemName: String
  let label: String
  var isActive = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: systemName)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(isActive ? PrismaColors.accentFallback : PrismaColors.textPrimary)
          .frame(width: 28, height: 28)
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
  case comparison
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
          switch sheet {
          case .summary, .context:
            if let text = contentText, !text.isEmpty {
              Text(text)
                .font(PrismaTypography.body())
                .foregroundStyle(PrismaColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PrismaSpacing.lg)
            }
          case .comparison:
            comparisonContent
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

  @ViewBuilder
  private var comparisonContent: some View {
    if let unified = viewModel.unifiedStory, !unified.isEmpty {
      cascadeAISection(
        title: String(localized: "reader.unifiedStory"),
        text: unified
      )
    }
    if let comparison = viewModel.comparisonText, !comparison.isEmpty {
      cascadeAISection(
        title: String(localized: "reader.compare"),
        text: comparison
      )
    }
  }

  private func cascadeAISection(title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(title)
        .font(PrismaTypography.headline())
        .foregroundStyle(PrismaColors.textPrimary)
      Text(text)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(PrismaSpacing.lg)
  }

  private var title: String {
    switch sheet {
    case .summary:
      String(localized: "reader.aiSummary")
    case .comparison:
      String(localized: "reader.showComparison")
    case .context:
      String(localized: "reader.context")
    }
  }

  private var contentText: String? {
    switch sheet {
    case .summary:
      viewModel.aiSummary
    case .comparison:
      nil
    case .context:
      viewModel.contextExplanation
    }
  }
}
