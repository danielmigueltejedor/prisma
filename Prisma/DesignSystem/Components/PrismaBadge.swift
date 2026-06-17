import SwiftUI

struct PrismaBadge: View {
  let text: String

  var body: some View {
    Text(text)
      .font(PrismaTypography.caption2(.semibold))
      .padding(.horizontal, PrismaSpacing.xs)
      .padding(.vertical, PrismaSpacing.xxs)
      .background(PrismaColors.accentFallback.opacity(0.12))
      .foregroundStyle(PrismaColors.accentFallback)
      .clipShape(Capsule())
      .accessibilityLabel(text)
  }
}

struct AppleIntelligenceBanner: View {
  var body: some View {
    HStack(spacing: PrismaSpacing.sm) {
      Image(systemName: "apple.intelligence")
        .foregroundStyle(PrismaColors.accentFallback)
      Text(String(localized: "ai.appleIntelligence"))
        .font(PrismaTypography.callout(.semibold))
      Spacer()
      Text(String(localized: "foryou.ai.personalized"))
        .font(PrismaTypography.caption())
        .foregroundStyle(PrismaColors.textSecondary)
        .multilineTextAlignment(.trailing)
    }
    .padding(PrismaSpacing.md)
    .prismaGlass()
    .accessibilityElement(children: .combine)
  }
}

struct LocalAIBadge: View {
  var body: some View {
    HStack(spacing: PrismaSpacing.xxs) {
      Image(systemName: "apple.intelligence")
      Text(String(localized: "ai.onDeviceFree"))
    }
    .font(PrismaTypography.caption2(.semibold))
    .padding(.horizontal, PrismaSpacing.xs)
    .padding(.vertical, PrismaSpacing.xxs)
    .background(PrismaColors.accentFallback.opacity(0.12))
    .foregroundStyle(PrismaColors.accentFallback)
    .clipShape(Capsule())
    .accessibilityLabel(String(localized: "ai.onDeviceFree"))
  }
}
