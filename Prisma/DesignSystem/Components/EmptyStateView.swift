import SwiftUI

struct EmptyStateView: View {
  let icon: String
  let title: String
  let message: String
  var actionTitle: String?
  var action: (() -> Void)?

  var body: some View {
    VStack(spacing: PrismaSpacing.md) {
      Image(systemName: icon)
        .font(.system(size: 44))
        .foregroundStyle(PrismaColors.textTertiary)
        .accessibilityHidden(true)

      Text(title)
        .font(PrismaTypography.title())
        .foregroundStyle(PrismaColors.textPrimary)
        .multilineTextAlignment(.center)

      Text(message)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
        .multilineTextAlignment(.center)

      if let actionTitle, let action {
        PrismaButton(title: actionTitle, style: .secondary, action: action)
          .padding(.top, PrismaSpacing.sm)
          .frame(maxWidth: 260)
      }
    }
    .padding(PrismaSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
