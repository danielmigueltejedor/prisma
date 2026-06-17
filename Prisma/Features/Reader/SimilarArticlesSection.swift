import SwiftUI

struct SimilarArticlesSection: View {
  let articles: [Article]
  var onSelect: (Article) -> Void
  var compact: Bool = false
  var showsImages: Bool? = nil
  var poweredByAI: Bool = false
  var isLoadingAI: Bool = false

  private var shouldShowImages: Bool {
    showsImages ?? !compact
  }

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? PrismaSpacing.xs : PrismaSpacing.sm) {
      HStack(alignment: .firstTextBaseline) {
        Text(String(localized: "reader.similar"))
          .font(compact ? PrismaTypography.caption(.semibold) : PrismaTypography.title())
          .foregroundStyle(PrismaColors.textPrimary)

        Spacer()

        if isLoadingAI {
          ProgressView()
            .controlSize(.small)
        } else if poweredByAI {
          Label(String(localized: "ai.appleIntelligence"), systemImage: "apple.intelligence")
            .font(PrismaTypography.caption2(.semibold))
            .foregroundStyle(PrismaColors.accentFallback)
            .labelStyle(.titleAndIcon)
        }
      }

      if isLoadingAI, articles.isEmpty {
        Text(String(localized: "reader.similar.loading"))
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textSecondary)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: compact ? PrismaSpacing.xs : PrismaSpacing.sm) {
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

  @ViewBuilder
  private func similarCard(_ article: Article) -> some View {
    if compact, !shouldShowImages {
      compactTextCard(article)
    } else {
      standardCard(article)
    }
  }

  private func compactTextCard(_ article: Article) -> some View {
    HStack(alignment: .top, spacing: PrismaSpacing.sm) {
      SourceIconView(
        siteURL: article.feedSource?.siteURL,
        feedURL: article.originalFeedUrl,
        platform: article.feedSource?.effectivePlatform ?? .news,
        size: 20
      )

      VStack(alignment: .leading, spacing: 2) {
        Text(article.sourceName)
          .font(PrismaTypography.caption2())
          .foregroundStyle(PrismaColors.accentFallback)
          .lineLimit(1)

        Text(article.title)
          .font(PrismaTypography.caption(.semibold))
          .foregroundStyle(PrismaColors.textPrimary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
      }
    }
    .frame(width: 168, alignment: .leading)
    .padding(.horizontal, PrismaSpacing.sm)
    .padding(.vertical, PrismaSpacing.xs)
    .prismaGlass(cornerRadius: PrismaRadius.sm)
  }

  private func standardCard(_ article: Article) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
      if shouldShowImages, let imageURL = article.resolvedImageURL {
        ArticleRemoteImage(url: imageURL, maxPixelSize: compact ? 220 : 280) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          RoundedRectangle(cornerRadius: PrismaRadius.sm, style: .continuous)
            .fill(PrismaColors.surface)
            .overlay { ProgressView().controlSize(.small) }
        }
        .frame(width: compact ? 180 : 220, height: compact ? 96 : 112)
        .clipShape(RoundedRectangle(cornerRadius: PrismaRadius.sm, style: .continuous))
      }

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
