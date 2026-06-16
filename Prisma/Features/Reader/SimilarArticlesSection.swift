import SwiftUI

struct SimilarArticlesSection: View {
  let articles: [Article]
  var onSelect: (Article) -> Void
  var compact: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(String(localized: "reader.similar"))
        .font(compact ? PrismaTypography.callout(.semibold) : PrismaTypography.title())
        .foregroundStyle(PrismaColors.textPrimary)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: PrismaSpacing.sm) {
          ForEach(articles, id: \.id) { article in
            Button { onSelect(article) } label: {
              similarCard(article)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func similarCard(_ article: Article) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
      HStack(spacing: PrismaSpacing.xs) {
        SourceIconView(
          siteURL: article.feedSource?.siteURL,
          feedURL: article.originalFeedUrl,
          size: compact ? 18 : 22
        )
        Text(article.sourceName)
          .font(PrismaTypography.caption2())
          .foregroundStyle(PrismaColors.accentFallback)
          .lineLimit(1)
      }

      Text(article.title)
        .font(compact ? PrismaTypography.caption(.semibold) : PrismaTypography.callout(.semibold))
        .foregroundStyle(PrismaColors.textPrimary)
        .lineLimit(compact ? 2 : 3)
        .multilineTextAlignment(.leading)
        .frame(width: compact ? 180 : 220, alignment: .leading)
    }
    .padding(compact ? PrismaSpacing.sm : PrismaSpacing.md)
    .prismaGlass(cornerRadius: PrismaRadius.md)
  }
}
