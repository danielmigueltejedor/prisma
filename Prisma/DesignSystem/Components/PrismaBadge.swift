import SwiftUI

struct PrismaBadge: View {
  let text: String
  var isPlus: Bool = false

  var body: some View {
    Text(text)
      .font(PrismaTypography.caption2(.semibold))
      .padding(.horizontal, PrismaSpacing.xs)
      .padding(.vertical, PrismaSpacing.xxs)
      .background(isPlus ? PrismaColors.plusBadge.opacity(0.15) : PrismaColors.accentFallback.opacity(0.12))
      .foregroundStyle(isPlus ? PrismaColors.plusBadge : PrismaColors.accentFallback)
      .clipShape(Capsule())
      .accessibilityLabel(isPlus ? "Prisma Plus: \(text)" : text)
  }
}

struct PrismaPlusBadge: View {
  var body: some View {
    PrismaBadge(text: "Prisma+", isPlus: true)
  }
}
