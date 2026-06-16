import SwiftUI

struct ArticleCard: View {
  let title: String
  let sourceName: String
  let publishedAt: Date?
  let summary: String?
  let imageURL: URL?
  var isRead: Bool = false
  var isSaved: Bool = false
  var readingTimeMinutes: Int?
  var sourceSiteURL: String? = nil
  var sourceFeedURL: String? = nil

  var body: some View {
    HStack(alignment: .top, spacing: PrismaSpacing.sm) {
      VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
        HStack(spacing: PrismaSpacing.xs) {
          if let sourceFeedURL {
            SourceIconView(siteURL: sourceSiteURL, feedURL: sourceFeedURL, size: 16)
          }
          Text(sourceName)
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.accentFallback)

          if let publishedAt {
            Text("·")
              .foregroundStyle(PrismaColors.textTertiary)
            Text(publishedAt, style: .relative)
              .font(PrismaTypography.caption2())
              .foregroundStyle(PrismaColors.textTertiary)
          }

          if let readingTimeMinutes {
            Text("·")
              .foregroundStyle(PrismaColors.textTertiary)
            Text("\(readingTimeMinutes) min")
              .font(PrismaTypography.caption2())
              .foregroundStyle(PrismaColors.textTertiary)
          }
        }

        Text(title)
          .font(PrismaTypography.headline(isRead ? .regular : .semibold))
          .foregroundStyle(isRead ? PrismaColors.textSecondary : PrismaColors.textPrimary)
          .lineLimit(3)
          .multilineTextAlignment(.leading)

        if let summary, !summary.isEmpty {
          Text(summary)
            .font(PrismaTypography.callout())
            .foregroundStyle(PrismaColors.textSecondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 0)

      if let imageURL {
        AsyncImage(url: imageURL) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          case .failure, .empty:
            RoundedRectangle(cornerRadius: PrismaRadius.sm)
              .fill(PrismaColors.elevatedSurface)
          @unknown default:
            EmptyView()
          }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: PrismaRadius.sm, style: .continuous))
        .accessibilityHidden(true)
      }

      if isSaved {
        Image(systemName: "bookmark.fill")
          .font(.caption)
          .foregroundStyle(PrismaColors.accentFallback)
          .accessibilityLabel(String(localized: "article.saved"))
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
    .accessibilityElement(children: .combine)
    .accessibilityHint(isRead ? String(localized: "article.read") : "")
  }
}
