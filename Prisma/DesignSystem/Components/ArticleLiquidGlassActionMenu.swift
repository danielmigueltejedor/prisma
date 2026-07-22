import SwiftUI

struct ArticleActionMenuOverlay: View {
  let article: Article
  let collections: [Collection]
  let isInCollection: (Collection) -> Bool
  let onToggleLike: () -> Void
  let onToggleSave: () -> Void
  let onShare: () -> Void
  let onAddToCollection: (Collection) -> Void
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.22)
        .ignoresSafeArea()
        .onTapGesture(perform: onDismiss)

      ArticleLiquidGlassActionMenu(
        article: article,
        collections: collections,
        isInCollection: isInCollection,
        onToggleLike: onToggleLike,
        onToggleSave: onToggleSave,
        onShare: onShare,
        onAddToCollection: onAddToCollection
      )
      .transition(.scale(scale: 0.92, anchor: .center).combined(with: .opacity))
    }
    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: article.id)
  }
}

private struct ArticleLiquidGlassActionMenu: View {
  let article: Article
  let collections: [Collection]
  let isInCollection: (Collection) -> Bool
  let onToggleLike: () -> Void
  let onToggleSave: () -> Void
  let onShare: () -> Void
  let onAddToCollection: (Collection) -> Void

  var body: some View {
    VStack(spacing: 0) {
      Text(article.title)
        .font(PrismaTypography.caption(.semibold))
        .foregroundStyle(PrismaColors.textSecondary)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PrismaSpacing.md)
        .padding(.top, PrismaSpacing.sm)
        .padding(.bottom, PrismaSpacing.xs)

      ArticleLiquidGlassMenuButton(
        icon: article.isFavorite ? "heart.fill" : "heart",
        title: String(localized: "action.favorite"),
        isActive: article.isFavorite,
        action: onToggleLike
      )
      menuDivider
      ArticleLiquidGlassMenuButton(
        icon: article.isSaved ? "bookmark.fill" : "bookmark",
        title: String(localized: "action.save"),
        isActive: article.isSaved,
        action: onToggleSave
      )
      menuDivider
      ArticleLiquidGlassMenuButton(
        icon: "square.and.arrow.up",
        title: String(localized: "action.share"),
        action: onShare
      )

      if !collections.isEmpty {
        menuDivider
        Text(String(localized: "article.saveToCollection"))
          .font(PrismaTypography.caption2(.semibold))
          .foregroundStyle(PrismaColors.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, PrismaSpacing.md)
          .padding(.top, PrismaSpacing.xs)
          .padding(.bottom, PrismaSpacing.xxs)

        ForEach(collections, id: \.id) { collection in
          ArticleLiquidGlassMenuButton(
            icon: isInCollection(collection) ? "folder.fill" : "folder",
            title: collection.name,
            isActive: isInCollection(collection),
            action: { onAddToCollection(collection) }
          )
        }
      }
    }
    .frame(minWidth: 248, maxWidth: 300)
    .modifier(ArticleLiquidGlassMenuSurface())
    .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
  }

  private var menuDivider: some View {
    Divider()
      .overlay(PrismaColors.textTertiary.opacity(0.25))
      .padding(.horizontal, PrismaSpacing.sm)
  }
}

private struct ArticleLiquidGlassMenuButton: View {
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
          .lineLimit(1)
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

private struct ArticleLiquidGlassMenuSurface: ViewModifier {
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
