import SwiftUI

struct OfflineBanner: View {
  var body: some View {
    HStack(spacing: PrismaSpacing.sm) {
      Image(systemName: "wifi.slash")
        .font(PrismaTypography.caption(.semibold))
      Text(String(localized: "offline.banner.message"))
        .font(PrismaTypography.caption())
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, PrismaSpacing.md)
    .padding(.vertical, PrismaSpacing.sm)
    .background(Color.orange.opacity(0.92))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "offline.banner.message"))
  }
}
