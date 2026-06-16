import SwiftUI

struct SavedView: View {
  @Bindable var viewModel: SavedViewModel
  var onSelectArticle: (Article) -> Void

  @State private var newCollectionName = ""
  @State private var showNewCollection = false

  var body: some View {
    NavigationStack {
      PrismaScreen {
        if viewModel.displayedArticles.isEmpty {
          EmptyStateView(
            icon: "bookmark",
            title: String(localized: "saved.empty.title"),
            message: String(localized: "saved.empty.message")
          )
        } else {
          ScrollView {
            LazyVStack(spacing: PrismaSpacing.sm) {
              Picker(String(localized: "saved.filter"), selection: $viewModel.selectedFilter) {
                ForEach(SavedViewModel.SavedFilter.allCases) { filter in
                  Text(filter.title).tag(filter)
                }
              }
              .pickerStyle(.segmented)
              .padding(.bottom, PrismaSpacing.sm)

              if !viewModel.collections.isEmpty {
                collectionsSection
              }

              ForEach(viewModel.displayedArticles, id: \.id) { article in
                Button { onSelectArticle(article) } label: {
                  ArticleCard(
                    title: article.title,
                    sourceName: article.sourceName,
                    publishedAt: article.publishedAt,
                    summary: HTMLSanitizer.stripHTML(article.summary),
                    imageURL: article.imageUrl.flatMap(URL.init(string:)),
                    isRead: article.isRead,
                    isSaved: article.isSaved,
                    readingTimeMinutes: article.readingTimeEstimate,
                    sourceSiteURL: article.feedSource?.siteURL,
                    sourceFeedURL: article.originalFeedUrl
                  )
                }
                .buttonStyle(.plain)
              }
            }
            .padding(PrismaSpacing.md)
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
      .onAppear { viewModel.load() }
    }
  }

  private var collectionsSection: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(String(localized: "saved.collections"))
        .font(PrismaTypography.headline())
      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          ForEach(viewModel.collections, id: \.id) { collection in
            CategoryChip(title: collection.name)
          }
        }
      }
    }
    .padding(.bottom, PrismaSpacing.sm)
  }
}
