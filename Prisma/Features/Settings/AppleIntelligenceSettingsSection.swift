import SwiftUI

struct AppleIntelligenceSettingsSection: View {
  var body: some View {
    Section(String(localized: "settings.ai.section")) {
      HStack(spacing: PrismaSpacing.sm) {
        Image(systemName: "apple.intelligence")
          .foregroundStyle(PrismaColors.accentFallback)
        VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
          Text(String(localized: "settings.ai.title"))
            .font(PrismaTypography.body(.medium))
          Text(statusMessage)
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textSecondary)
        }
      }
    }
  }

  private var statusMessage: String {
    if AIServiceFactory.hasFreeOnDeviceAI {
      return String(localized: "settings.ai.active")
    }
    if let key = AppleIntelligenceAvailability.current.userMessageKey {
      return String(localized: String.LocalizationValue(key))
    }
    return String(localized: "settings.ai.unavailable")
  }
}
