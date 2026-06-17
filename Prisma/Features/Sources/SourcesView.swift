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
    }
  }

  private var sourcesBrowseMode: some View {
    List {
      Section {
        StyleFilterBar(
          filters: viewModel.styleFilters,
          selection: $viewModel.selectedStyle
        )
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }

      if viewModel.sources.isEmpty {
        Section {
          EmptyStateView(
            icon: "antenna.radiowaves.left.and.right",
            title: String(localized: "sources.empty.title"),
            message: String(localized: "sources.empty.message"),
            actionTitle: String(localized: "sources.add"),
            action: { showAddSource = true }
          )
          .listRowBackground(Color.clear)
        }
      } else {
        Section(String(localized: "sources.yours")) {
          ForEach(viewModel.displayedSources, id: \.id) { source in
            sourceRow(source)
          }
          .onDelete { indexSet in
            indexSet.map { viewModel.displayedSources[$0] }.forEach(viewModel.delete)
          }
        }
      }
    }
    .scrollContentBackground(.hidden)
    .captureNativeScrollOffset($headerScrollOffset)
  }

  private var sourcesSearchMode: some View {
    LiquidGlassSearchModeShell(
      hasQuery: viewModel.isSearching,
      hasResults: !viewModel.displayedSources.isEmpty,
      emptyTitle: String(localized: "search.mode.hint.title"),
      emptyMessage: String(localized: "sources.search.mode.hint"),
      noResultsTitle: String(localized: "search.noResults.title"),
      noResultsMessage: String(localized: "search.noResults.message"),
      scrollOffset: $headerScrollOffset
    ) {
      StyleFilterBar(
        filters: viewModel.styleFilters,
        selection: $viewModel.selectedStyle
      )
    } results: {
      LazyVStack(spacing: PrismaSpacing.md) {
        ForEach(viewModel.displayedSources, id: \.id) { source in
          sourceRow(source)
        }
      }
    }
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

  private func sourceRow(_ source: FeedSource) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
      Button {
        selectedSource = source
      } label: {
        HStack(spacing: PrismaSpacing.sm) {
          SourceIconView(
            siteURL: source.siteURL,
            feedURL: source.feedURL,
            platform: source.effectivePlatform,
            size: 36
          )
          VStack(alignment: .leading, spacing: 2) {
            HStack {
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
          Spacer()
          Toggle("", isOn: Binding(
            get: { source.isEnabled },
            set: { _ in viewModel.toggleEnabled(source) }
          ))
          .labelsHidden()
        }
      }
      .buttonStyle(.plain)

      HStack {
        Button(String(localized: "sources.favorite")) {
          viewModel.toggleFavorite(source)
        }
        .font(PrismaTypography.caption())

        Button(String(localized: "sources.block")) {
          viewModel.toggleBlocked(source)
        }
        .font(PrismaTypography.caption())

        Button(String(localized: "action.edit")) {
          editingSource = source
          editedName = source.name
        }
        .font(PrismaTypography.caption())

        Button(String(localized: "action.refresh")) {
          Task { await viewModel.refreshSource(source) }
        }
        .font(PrismaTypography.caption())
      }
      .buttonStyle(.borderless)
    }
    .padding(.vertical, PrismaSpacing.xxs)
  }

  private func exportOPML() {
    guard let content = viewModel.exportOPML() else { return }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("prisma-feeds.opml")
    try? content.write(to: url, atomically: true, encoding: .utf8)
    exportDocument = ExportDocument(url: url)
  }
}

struct ExportDocument: Identifiable {
  let id = UUID()
  let url: URL
}
