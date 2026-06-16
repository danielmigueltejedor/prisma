import SwiftUI

struct SubscriptionManagementView: View {
  var subscriptionService: SubscriptionServiceProtocol
  var showPaywall: () -> Void

  var body: some View {
    Section {
      HStack {
        VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
          Text("Prisma+")
            .font(PrismaTypography.headline())
          Text(statusText)
            .font(PrismaTypography.caption())
            .foregroundStyle(PrismaColors.textSecondary)
        }
        Spacer()
        if subscriptionService.isPlusActive {
          PrismaBadge(text: String(localized: "plus.active"), isPlus: true)
        }
      }

      if subscriptionService.isPlusActive {
        Link(String(localized: "plus.manageSubscription"), destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
      } else {
        Button(String(localized: "plus.activate")) {
          showPaywall()
        }
      }

      Button(String(localized: "paywall.restore")) {
        Task { try? await subscriptionService.restorePurchases() }
      }

      #if DEBUG
      if let mock = subscriptionService as? MockSubscriptionService {
        Button("Toggle Prisma+ (Debug)") {
          mock.togglePlusForTesting()
        }
      }
      #endif
    }
  }

  private var statusText: String {
    if subscriptionService.isPlusActive {
      if subscriptionService.isInTrial {
        return String(localized: "plus.status.trial")
      }
      return String(localized: "plus.status.active")
    }
    return String(localized: "plus.status.free")
  }
}
