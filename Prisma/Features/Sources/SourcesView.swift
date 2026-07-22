import SwiftUI
import UniformTypeIdentifiers

struct SourcesView: View {
  @Bindable var viewModel: SourcesViewModel
  var articleRepository: ArticleRepository
  var feedService: FeedService
  var translationService: ArticleTranslationService
  var previewStore: ArticlePreviewTranslationStore
  var onSelectArticle: (Article) -> Void

  @State private var showAddSource = false
  @State private var showImporter = false
  @State private var exportDocument: ExportDocument?
  @State private var editingSource: FeedSource?
  @State private var editedName = ""
  @State private var selectedSource: FeedSource?
  @State private var pendingArticleFromSource: Article?
  @State private var isSearchExpanded = false
  @State private var headerScrollOffset: CGFloat = 0
  @State private var showSourcesError = false
  @State private var showSourcesSuccess = false
  @State private var sourceActionMenu: FeedSource?
  @FocusState private var searchFocused: Bool

  var body: some View {
    NavigationStack {
      PrismaScreen {
        if isSearchExpanded {
          sourcesSearchMode
        } else {
          sourcesBrowseMode
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top, spacing: 0) {
        PrismaNavigationHeaderChrome(scrollOffset: headerScrollOffset) {
          MorphingLiquidGlassNavigationBar(
            isExpanded: $isSearchExpanded,
            searchText: $viewModel.searchText,
            title: String(localized: "tab.sources"),
            prompt: String(localized: "sources.search"),
            onTextChange: {},
            focus: $searchFocused
          ) {
            sourcesMenu
          }
        }
      }
      .animation(.easeInOut(duration: 0.28), value: isSearchExpanded)
      .onChange(of: isSearchExpanded) { _, expanded in
        if !expanded { headerScrollOffset = 0 }
      }
      .sheet(isPresented: $showAddSource, onDismiss: { viewModel.reload() }) {
        AddSourceView(viewModel: viewModel)
      }
      .fileImporter(
        isPresented: $showImporter,
        allowedContentTypes: [.xml, UTType(filenameExtension: "opml") ?? .xml]
      ) { result in
        if case .success(let url) = result,
           let data = try? Data(contentsOf: url) {
          viewModel.importOPML(data: data)
        }
      }
      .sheet(item: $exportDocument) { document in
        ShareSheet(items: [document.url])
      }
      .alert(String(localized: "sources.rename"), isPresented: .init(
        get: { editingSource != nil },
        set: { if !$0 { editingSource = nil } }
      )) {
        TextField(String(localized: "sources.field.name"), text: $editedName)
        Button(String(localized: "action.save")) {
          if let source = editingSource {
            viewModel.rename(source, to: editedName)
          }
          editingSource = nil
        }
        Button(String(localized: "action.cancel"), role: .cancel) {
          editingSource = nil
        }
      }
      .onAppear { viewModel.loadIfNeeded() }
      .onReceive(NotificationCenter.default.publisher(for: .feedsDidRefresh)) { _ in
        viewModel.reload()
      }
      .onChange(of: viewModel.errorMessage) { _, message in
        if message != nil { showSourcesError = true }
      }
      .onChange(of: viewModel.successMessage) { _, message in
        if message != nil {
          HapticFeedback.success()
          showSourcesSuccess = true
        }
      }
      .alert(String(localized: "error.generic"), isPresented: $showSourcesError) {
        Button(String(localized: "action.close"), role: .cancel) {
          viewModel.errorMessage = nil
        }
      } message: {
        if let message = viewModel.errorMessage {
          Text(message)
        }
      }
      .alert(String(localized: "sources.success.title"), isPresented: $showSourcesSuccess) {
        Button(String(localized: "action.close"), role: .cancel) {
          viewModel.successMessage = nil
        }
      } message: {
        if let message = viewModel.successMessage {
          Text(message)
        }
      }
      .sheet(item: $selectedSource) { source in
        SourceDetailView(
          viewModel: SourceDetailViewModel(
            source: source,
            articleRepository: articleRepository,
            feedService: feedService,
            translationService: translationService
          ),
          previewStore: previewStore,
          onSelectArticle: { article in
            pendingArticleFromSource = article
            selectedSource = nil
          }
        )
      }
      .onChange(of: selectedSource) { _, newValue in
        if newValue == nil, let article = pendingArticleFromSource {
          pendingArticleFromSource = nil
          onSelectArticle(article)
        }
      }
      .overlay {
        if let source = sourceActionMenu {
          SourceActionMenuOverlay(
            source: source,
            onToggleFavorite: {
              viewModel.toggleFavorite(source)
              sourceActionMenu = nil
            },
            onToggleBlocked: {
              viewModel.toggleBlocked(source)
              sourceActionMenu = nil
            },
            onEdit: {
              sourceActionMenu = nil
              editingSource = source
              editedName = source.name
            },
            onRefresh: {
              sourceActionMenu = nil
              Task { await viewModel.refreshSource(source) }
            },
            onDismiss: { sourceActionMenu = nil }
          )
        }
      }
    }
  }

  private var sourcesBrowseMode: some View {
    sourcesList(
      showsEmptyLibraryState: viewModel.sources.isEmpty,
      showsSearchPlaceholder: false,
      showsNoResults: false
    )
  }

  private var sourcesSearchMode: some View {
    sourcesList(
      showsEmptyLibraryState: false,
      showsSearchPlaceholder: !viewModel.isSearching,
      showsNoResults: viewModel.isSearching && viewModel.displayedSources.isEmpty
    )
  }

  private func sourcesList(
    showsEmptyLibraryState: Bool,
    showsSearchPlaceholder: Bool,
    showsNoResults: Bool
  ) -> some View {
    List {
      Section {
        StyleFilterBar(
          filters: viewModel.styleFilters,
          selection: $viewModel.selectedStyle
        )
        .listRowInsets(sourceFilterRowInsets)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
      }

      if showsEmptyLibraryState {
        Section {
          EmptyStateView(
            icon: "antenna.radiowaves.left.and.right",
            title: String(localized: "sources.empty.title"),
            message: String(localized: "sources.empty.message"),
            actionTitle: String(localized: "sources.add"),
            action: { showAddSource = true }
          )
          .listRowInsets(sourceEmptyRowInsets)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        }
      } else if showsSearchPlaceholder {
        Section {
          sourcesSearchPlaceholder(
            title: String(localized: "search.mode.hint.title"),
            message: String(localized: "sources.search.mode.hint")
          )
          .listRowInsets(sourceEmptyRowInsets)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        }
      } else if showsNoResults {
        Section {
          sourcesSearchPlaceholder(
            title: String(localized: "search.noResults.title"),
            message: String(localized: "search.noResults.message")
          )
          .listRowInsets(sourceEmptyRowInsets)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        }
      } else {
        Section {
          ForEach(viewModel.displayedSources, id: \.id) { source in
            sourceListRow(for: source)
          }
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .scrollIndicators(.hidden)
    .captureNativeScrollOffset($headerScrollOffset)
  }

  private var sourceFilterRowInsets: EdgeInsets {
    EdgeInsets(
      top: 0,
      leading: PrismaSpacing.md,
      bottom: PrismaSpacing.xxs,
      trailing: PrismaSpacing.md
    )
  }

  private var sourceEmptyRowInsets: EdgeInsets {
    EdgeInsets(
      top: PrismaSpacing.xl,
      leading: PrismaSpacing.md,
      bottom: PrismaSpacing.xl,
      trailing: PrismaSpacing.md
    )
  }

  private var sourceRowInsets: EdgeInsets {
    EdgeInsets(
      top: PrismaSpacing.xxs,
      leading: PrismaSpacing.md,
      bottom: PrismaSpacing.xxs,
      trailing: PrismaSpacing.md
    )
  }

  @ViewBuilder
  private func sourceListRow(for source: FeedSource) -> some View {
    SourceListRow(
      source: source,
      onOpen: { selectedSource = source },
      onShowActions: { sourceActionMenu = source },
      onToggleEnabled: { viewModel.toggleEnabled(source) }
    )
    .listRowInsets(sourceRowInsets)
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button {
        Task { await viewModel.refreshSource(source) }
      } label: {
        Label(String(localized: "action.refresh"), systemImage: "arrow.clockwise")
      }
      .tint(PrismaColors.accentFallback)

      Button(role: .destructive) {
        viewModel.delete(source)
      } label: {
        Label(String(localized: "action.delete"), systemImage: "trash")
      }
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        viewModel.toggleFavorite(source)
      } label: {
        Label(
          String(localized: "sources.favorite"),
          systemImage: source.isFavorite ? "star.slash.fill" : "star.fill"
        )
      }
      .tint(.yellow)

      Button {
        viewModel.toggleBlocked(source)
      } label: {
        Label(
          String(localized: "sources.block"),
          systemImage: source.isBlocked ? "hand.raised.slash.fill" : "hand.raised.fill"
        )
      }
      .tint(.orange)
    }
  }

  private func sourcesSearchPlaceholder(title: String, message: String) -> some View {
    VStack(spacing: PrismaSpacing.sm) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 36, weight: .medium))
        .foregroundStyle(PrismaColors.textTertiary)
      Text(title)
        .font(PrismaTypography.headline())
        .foregroundStyle(PrismaColors.textPrimary)
      Text(message)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, PrismaSpacing.xxl)
  }

  private var sourcesMenu: some View {
    Menu {
      Button(String(localized: "sources.add"), systemImage: "plus") {
        showAddSource = true
      }
      Button(String(localized: "sources.importOPML"), systemImage: "square.and.arrow.down") {
        showImporter = true
      }
      Button(String(localized: "sources.exportOPML"), systemImage: "square.and.arrow.up") {
        exportOPML()
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
  }

  private func exportOPML() {
    guard let content = viewModel.exportOPML() else { return }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("prisma-feeds.opml")
    try? content.write(to: url, atomically: true, encoding: .utf8)
    exportDocument = ExportDocument(url: url)
  }
}

private struct SourceListRow: View {
  let source: FeedSource
  let onOpen: () -> Void
  let onShowActions: () -> Void
  let onToggleEnabled: () -> Void

  var body: some View {
    HStack(spacing: PrismaSpacing.sm) {
      rowContent
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .highPriorityGesture(
          LongPressGesture(minimumDuration: 0.45)
            .onEnded { _ in
              HapticFeedback.medium()
              onShowActions()
            }
        )
        .accessibilityHint(String(localized: "sources.row.actions.hint"))

      Toggle("", isOn: Binding(
        get: { source.isEnabled },
        set: { _ in onToggleEnabled() }
      ))
      .labelsHidden()
    }
    .padding(PrismaSpacing.sm)
    .prismaGlass(cornerRadius: PrismaRadius.md)
  }

  private var rowContent: some View {
    HStack(spacing: PrismaSpacing.sm) {
      SourceIconView(
        siteURL: source.siteURL,
        feedURL: source.feedURL,
        platform: source.effectivePlatform,
        size: 36
      )
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: PrismaSpacing.xxs) {
          Text(source.name)
            .font(PrismaTypography.headline())
            .foregroundStyle(PrismaColors.textPrimary)
          if source.isFavorite {
            Image(systemName: "star.fill")
              .font(.caption)
              .foregroundStyle(PrismaColors.warning)
          }
          if source.isBlocked {
            Image(systemName: "hand.raised.fill")
              .font(.caption)
              .foregroundStyle(PrismaColors.danger)
          }
        }
        Text(source.feedURL)
          .font(PrismaTypography.caption2())
          .foregroundStyle(PrismaColors.textTertiary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
  }
}

private struct SourceActionMenuOverlay: View {
  let source: FeedSource
  let onToggleFavorite: () -> Void
  let onToggleBlocked: () -> Void
  let onEdit: () -> Void
  let onRefresh: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.22)
        .ignoresSafeArea()
        .onTapGesture(perform: onDismiss)

      SourceRowLiquidGlassMenu(
        source: source,
        onToggleFavorite: onToggleFavorite,
        onToggleBlocked: onToggleBlocked,
        onEdit: onEdit,
        onRefresh: onRefresh
      )
      .transition(.scale(scale: 0.92, anchor: .center).combined(with: .opacity))
    }
    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: source.id)
  }
}

private struct SourceRowLiquidGlassMenu: View {
  let source: FeedSource
  let onToggleFavorite: () -> Void
  let onToggleBlocked: () -> Void
  let onEdit: () -> Void
  let onRefresh: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      SourceRowLiquidGlassMenuButton(
        icon: source.isFavorite ? "star.fill" : "star",
        title: String(localized: "sources.favorite"),
        isActive: source.isFavorite,
        action: onToggleFavorite
      )
      menuDivider
      SourceRowLiquidGlassMenuButton(
        icon: source.isBlocked ? "hand.raised.fill" : "hand.raised",
        title: String(localized: "sources.block"),
        isActive: source.isBlocked,
        action: onToggleBlocked
      )
      menuDivider
      SourceRowLiquidGlassMenuButton(
        icon: "pencil",
        title: String(localized: "action.edit"),
        action: onEdit
      )
      menuDivider
      SourceRowLiquidGlassMenuButton(
        icon: "arrow.clockwise",
        title: String(localized: "action.refresh"),
        action: onRefresh
      )
    }
    .frame(minWidth: 228)
    .modifier(SourceRowLiquidGlassMenuSurface())
    .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
  }

  private var menuDivider: some View {
    Divider()
      .overlay(PrismaColors.textTertiary.opacity(0.25))
      .padding(.horizontal, PrismaSpacing.sm)
  }
}

private struct SourceRowLiquidGlassMenuButton: View {
  let icon: String
  let title: String
  var isActive = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: PrismaSpacing.sm) {
        Image(systemName: icon)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(isActive ? PrismaColors.accentFallback : PrismaColors.textPrimary)
          .frame(width: 24)
        Text(title)
          .font(PrismaTypography.callout())
          .foregroundStyle(PrismaColors.textPrimary)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, PrismaSpacing.md)
      .padding(.vertical, 11)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}

private struct SourceRowLiquidGlassMenuSurface: ViewModifier {
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

struct ExportDocument: Identifiable {
  let id = UUID()
  let url: URL
}
