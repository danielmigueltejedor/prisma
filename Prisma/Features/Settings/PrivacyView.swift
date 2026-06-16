import SwiftUI

struct PrivacyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: PrismaSpacing.lg) {
        Text(String(localized: "privacy.title"))
          .font(PrismaTypography.largeTitle())

        privacySection(
          title: String(localized: "privacy.local.title"),
          body: String(localized: "privacy.local.body")
        )
        privacySection(
          title: String(localized: "privacy.plus.title"),
          body: String(localized: "privacy.plus.body")
        )
        privacySection(
          title: String(localized: "privacy.data.title"),
          body: String(localized: "privacy.data.body")
        )
        privacySection(
          title: String(localized: "privacy.ads.title"),
          body: String(localized: "privacy.ads.body")
        )
      }
      .padding(PrismaSpacing.lg)
    }
    .navigationTitle(String(localized: "settings.privacy"))
    .navigationBarTitleDisplayMode(.inline)
  }

  private func privacySection(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
      Text(title)
        .font(PrismaTypography.headline())
      Text(body)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
    }
    .padding(PrismaSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .prismaGlass()
  }
}
