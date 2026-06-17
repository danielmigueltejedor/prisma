import SwiftUI

struct SavedView: View {
  @Bindable var viewModel: SavedViewModel
  var previewStore: ArticlePreviewTranslationStore
  var onSelectArticle: (Article) -> Void

  @State private var newCollectionName = ""
  @State private var showNewCollection = false

  var body: some View {
    NavigationStack {
      PrismaScreen {
        VStack(alignment: .leading, spacing: PrismaSpacing.md) {
          SavedLibraryFilterBar(selection: $viewModel.selectedFilter)
            .padding(.horizontal, PrismaSpacing.md)
            .padding(.top, PrismaSpacing.sm)

          if viewModel.displayedArticles.isEmpty {
            EmptyStateView(
              icon: viewModel.selectedFilter.emptyIcon,
              title: viewModel.selectedFilter.emptyTitle,
              message: viewModel.selectedFilter.emptyMessage
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            ScrollView {
              LazyVStack(spacing: PrismaSpacing.sm) {
                if !viewModel.collections.isEmpty, viewModel.selectedFilter == .saved {
                  collectionsSection
                }

                ForEach(viewModel.displayedArticles, id: \.id) { article in
                  Button { onSelectArticle(article) } label: {
                    TranslatedArticleCard(article: article, previewStore: previewStore)
                  }
                  .buttonStyle(.plain)
                }
              }
              .padding(.horizontal, PrismaSpacing.md)
              .padding(.bottom, PrismaSpacing.md)
            }
          }
        }
      }
      .navigationTitle(String(localized: "tab.saved"))
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showNewCollection = true
          } label: {
            Image(systemName: "folder.badge.plus")
          }
        }
      }
      .alert(String(localized: "saved.newCollection"), isPresented: $showNewCollection) {
        TextField(String(localized: "saved.collectionName"), text: $newCollectionName)
        Button(String(localized: "action.save")) {
          viewModel.createCollection(name: newCollectionName)
          newCollectionName = ""
        }
        Button(String(localized: "action.cancel"), role: .cancel) {}
      }
      .onAppear {
        viewModel.loadIfNeeded()
        previewStore.refresh(for: viewModel.displayedArticles)
      }
      .onChange(of: viewModel.selectedFilter) { _, _ in
        previewStore.refresh(for: viewModel.displayedArticles)
      }
      .onReceive(NotificationCenter.default.publisher(for: .articleLibraryDidChange)) { _ in
        viewModel.reload()
        previewStore.refresh(for: viewModel.displayedArticles)
      }
    }
  }

  private var collectionsSection: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(String(localized: "saved.collections"))
        .font(PrismaTypography.headline())
      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          CategoryChip(
            title: String(localized: "saved.collections.all"),
            isSelected: viewModel.selectedCollectionID == nil
          ) {
            viewModel.selectedCollectionID = nil
          }
          ForEach(viewModel.collections, id: \.id) { collection in
            CategoryChip(
              title: collection.name,
              isSelected: viewModel.selectedCollectionID == collection.id
            ) {
              viewModel.selectedCollectionID = collection.id
            }
          }
        }
      }
    }
    .padding(.bottom, PrismaSpacing.xs)
  }
}
