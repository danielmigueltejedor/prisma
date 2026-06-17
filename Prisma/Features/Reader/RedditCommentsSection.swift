import SwiftUI

struct RedditCommentsSection: View {
  let comments: [RedditComment]
  var isLoading: Bool
  var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.md) {
      HStack(spacing: PrismaSpacing.xs) {
        Image(systemName: "bubble.left.and.bubble.right.fill")
          .foregroundStyle(PrismaColors.accentFallback)
        Text(String(localized: "reader.reddit.comments"))
          .font(PrismaTypography.headline())
        Spacer()
        if !comments.isEmpty {
          Text("\(comments.count)")
            .font(PrismaTypography.caption(.semibold))
            .foregroundStyle(PrismaColors.textTertiary)
        }
      }

      if isLoading {
        HStack(spacing: PrismaSpacing.sm) {
          ProgressView()
          Text(String(localized: "reader.reddit.loadingComments"))
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textSecondary)
        }
      } else if let errorMessage {
        Text(errorMessage)
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textSecondary)
      } else if comments.isEmpty {
        Text(String(localized: "reader.reddit.noComments"))
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textSecondary)
      } else {
        VStack(alignment: .leading, spacing: PrismaSpacing.md) {
          ForEach(comments) { comment in
            RedditCommentRow(comment: comment)
            if comment.id != comments.last?.id {
              Divider()
            }
          }
        }
      }
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
  }
}

private struct RedditCommentRow: View {
  let comment: RedditComment

  var body: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
      HStack(alignment: .firstTextBaseline, spacing: PrismaSpacing.xs) {
        Text("u/\(comment.author)")
          .font(PrismaTypography.caption(.semibold))
          .foregroundStyle(PrismaColors.textPrimary)
        if let createdAt = comment.createdAt {
          Text(createdAt, style: .relative)
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textTertiary)
        }
        Spacer()
        Label("\(comment.score)", systemImage: "arrow.up")
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textTertiary)
          .labelStyle(.titleAndIcon)
      }

      Text(commentBody)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      if !comment.replies.isEmpty {
        VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
          ForEach(comment.replies) { reply in
            RedditCommentRow(comment: reply)
              .padding(.leading, min(CGFloat(reply.depth) * 12, 48))
          }
        }
        .padding(.top, PrismaSpacing.xs)
      }
    }
  }

  private var commentBody: AttributedString {
    let decoded = decodeRedditEntities(comment.displayBody)
    if let attributed = try? AttributedString(markdown: decoded) {
      return attributed
    }
    return AttributedString(decoded)
  }

  private func decodeRedditEntities(_ text: String) -> String {
    text
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'")
  }
}
