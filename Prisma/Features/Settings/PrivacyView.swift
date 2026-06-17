import SwiftUI

struct PrivacyView: View {
  @Environment(\.openURL) private var openURL

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
          title: String(localized: "privacy.ai.title"),
          body: String(localized: "privacy.ai.body")
        )
        privacySection(
          title: String(localized: "privacy.data.title"),
          body: String(localized: "privacy.data.body")
        )
        privacySection(
          title: String(localized: "privacy.ads.title"),
          body: String(localized: "privacy.ads.body")
        )

        VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
          privacySection(
            title: String(localized: "privacy.support.title"),
            body: String(localized: "privacy.support.body")
          )

          PrismaButton(
            title: String(localized: "privacy.support.donate"),
            style: .secondary
          ) {
            openURL(AppConfiguration.buyMeACoffeeURL)
          }
        }
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
