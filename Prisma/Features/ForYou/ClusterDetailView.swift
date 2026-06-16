import SwiftUI

struct ClusterDetailView: View {
  @Environment(\.dismiss) private var dismiss
  let cluster: ClusterDTO
  let articles: [Article]
  var onSelectArticle: (Article) -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: PrismaSpacing.lg) {
          header
          storyBody
          if let comparison = cluster.comparisonNote {
            comparisonCard(comparison)
          }
          sourcesSection
          articlesSection
        }
        .padding(PrismaSpacing.lg)
      }
      .background { GlassBackground() }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(String(localized: "action.close")) { dismiss() }
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      HStack {
        PrismaPlusBadge()
        Text(String(localized: "foryou.synthesized"))
          .font(PrismaTypography.caption(.semibold))
          .foregroundStyle(PrismaColors.textSecondary)
      }
      Text(cluster.title)
        .font(PrismaTypography.largeTitle())
      if let sources = cluster.sourceNames, !sources.isEmpty {
        Text(sources.joined(separator: " · "))
          .font(PrismaTypography.callout())
          .foregroundStyle(PrismaColors.accentFallback)
      }
    }
  }

  private var storyBody: some View {
    Text(cluster.synthesizedStory ?? cluster.summary ?? "")
      .font(PrismaTypography.readerBody())
      .foregroundStyle(PrismaColors.textPrimary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func comparisonCard(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
      Text(String(localized: "reader.compare"))
        .font(PrismaTypography.headline())
      Text(text)
        .font(PrismaTypography.callout())
        .foregroundStyle(PrismaColors.textSecondary)
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }

  private var sourcesSection: some View {
    HStack(spacing: PrismaSpacing.md) {
      ForEach(uniqueSources, id: \.id) { source in
        VStack(spacing: PrismaSpacing.xxs) {
          SourceIconView(siteURL: source.siteURL, feedURL: source.feedURL, size: 36)
          Text(source.name)
            .font(PrismaTypography.caption2())
            .foregroundStyle(PrismaColors.textSecondary)
            .lineLimit(1)
        }
      }
    }
  }

  private var articlesSection: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(String(localized: "foryou.sourceArticles"))
        .font(PrismaTypography.headline())

      ForEach(articles, id: \.id) { article in
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
  }

  private var uniqueSources: [FeedSourceProxy] {
    var seen = Set<UUID>()
    return articles.compactMap { article -> FeedSourceProxy? in
      guard seen.insert(article.sourceId).inserted else { return nil }
      return FeedSourceProxy(
        id: article.sourceId,
        name: article.sourceName,
        siteURL: article.feedSource?.siteURL,
        feedURL: article.originalFeedUrl
      )
    }
  }
}

private struct FeedSourceProxy: Identifiable {
  let id: UUID
  let name: String
  let siteURL: String?
  let feedURL: String
}
