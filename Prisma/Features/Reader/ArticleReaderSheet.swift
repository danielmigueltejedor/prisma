import SwiftUI

struct ArticleReaderSheet: View {
  let article: Article
  let dependencies: AppDependencies
  var onSelectArticle: (Article) -> Void
  var onOpenSource: (FeedSource) -> Void
  var onOpenAuthor: (String) -> Void

  @State private var viewModel: ArticleReaderViewModel?

  var body: some View {
    Group {
      if let viewModel {
        ArticleReaderView(
          viewModel: viewModel,
          onSelectArticle: onSelectArticle,
          onOpenSource: onOpenSource,
          onOpenAuthor: onOpenAuthor
        )
      } else {
        PrismaScreen {
          LoadingView(message: String(localized: "app.loading"))
        }
      }
    }
    .task(id: article.id) {
      dependencies.pauseBackgroundWorkForReader()
      await Task.yield()
      guard !Task.isCancelled else { return }
      viewModel = makeReaderViewModel(for: article)
    }
  }

  private func makeReaderViewModel(for article: Article) -> ArticleReaderViewModel {
    ArticleReaderViewModel(
      article: article,
      articleService: dependencies.articleService,
      articleRepository: dependencies.articleRepository,
      aiService: dependencies.aiService,
      feedSourceRepository: dependencies.feedSourceRepository,
      feedService: dependencies.feedService,
      preferenceRepository: dependencies.preferenceRepository,
      translationService: dependencies.translationService,
      redditCommentsService: dependencies.redditCommentsService,
      redditCommentsTranslationService: dependencies.redditCommentsTranslationService,
      summaryService: dependencies.summaryService,
      insightRepository: dependencies.insightRepository,
      localReadingCorpusService: dependencies.localReadingCorpusService,
      impressionMode: .standard
    )
  }
}
