import SwiftUI

struct LoadingView: View {
  var message: String = String(localized: "loading.default")

  var body: some View {
    VStack(spacing: PrismaSpacing.md) {
      ProgressView()
        .controlSize(.large)
      Text(message)
        .font(PrismaTypography.callout())
        .foregroundStyle(PrismaColors.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(message)
  }
}
