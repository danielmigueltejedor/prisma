import SwiftUI

struct ErrorStateView: View {
  let title: String
  let message: String
  var retryTitle: String = String(localized: "action.retry")
  var onRetry: (() -> Void)?

  var body: some View {
    VStack(spacing: PrismaSpacing.md) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 40))
        .foregroundStyle(PrismaColors.warning)
        .accessibilityHidden(true)

      Text(title)
        .font(PrismaTypography.title())
        .foregroundStyle(PrismaColors.textPrimary)

      Text(message)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
        .multilineTextAlignment(.center)

      if let onRetry {
        PrismaButton(title: retryTitle, style: .secondary, action: onRetry)
          .frame(maxWidth: 200)
      }
    }
    .padding(PrismaSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
