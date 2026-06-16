import SwiftUI
import StoreKit

struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  var subscriptionService: SubscriptionServiceProtocol
  var onContinueFree: (() -> Void)? = nil

  @State private var isPurchasing = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      PrismaScreen {
        ScrollView {
          VStack(alignment: .leading, spacing: PrismaSpacing.lg) {
            VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
              PrismaPlusBadge()
              Text("Prisma+")
                .font(PrismaTypography.largeTitle())
              Text(String(localized: "paywall.subtitle"))
                .font(PrismaTypography.body())
                .foregroundStyle(PrismaColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
              featureRow("sparkles", String(localized: "plus.feature.summary"))
              featureRow("rectangle.3.group", String(localized: "plus.feature.clustering"))
              featureRow("arrow.left.arrow.right", String(localized: "plus.feature.compare"))
              featureRow("newspaper", String(localized: "plus.feature.briefing"))
              featureRow("brain.head.profile", String(localized: "plus.feature.smartFeed"))
            }
            .padding(PrismaSpacing.md)
            .prismaGlass()

            Text("Prueba gratis de \(SubscriptionProducts.trialDays) días")
              .font(PrismaTypography.callout())
              .foregroundStyle(PrismaColors.textSecondary)

            if subscriptionService.products.isEmpty {
              VStack(spacing: PrismaSpacing.sm) {
                PrismaButton(
                  title: String(localized: "paywall.startTrial"),
                  isLoading: isPurchasing,
                  action: { Task { await purchaseMockOrFirst() } }
                )
                Text("\(SubscriptionProducts.monthlyPriceDisplay)/mes · \(SubscriptionProducts.yearlyPriceDisplay)/año")
                  .font(PrismaTypography.caption())
                  .foregroundStyle(PrismaColors.textTertiary)
                  .frame(maxWidth: .infinity)
              }
            } else {
              ForEach(subscriptionService.products, id: \.id) { product in
                PrismaButton(
                  title: product.displayName,
                  isLoading: isPurchasing,
                  action: { Task { await purchase(product) } }
                )
              }
            }

            PrismaButton(
              title: String(localized: "paywall.continueFree"),
              style: .secondary
            ) {
              continueFree()
            }

            PrismaButton(
              title: String(localized: "paywall.restore"),
              style: .ghost
            ) {
              Task { await restore() }
            }

            if let errorMessage {
              Text(errorMessage)
                .font(PrismaTypography.caption())
                .foregroundStyle(PrismaColors.danger)
            }

            Text(String(localized: "paywall.legal"))
              .font(PrismaTypography.caption2())
              .foregroundStyle(PrismaColors.textTertiary)
          }
          .padding(PrismaSpacing.lg)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(String(localized: "action.close")) { dismiss() }
        }
      }
      .task {
        await subscriptionService.loadProducts()
      }
    }
  }

  private func continueFree() {
    if let onContinueFree {
      onContinueFree()
    } else {
      dismiss()
    }
  }

  private func featureRow(_ icon: String, _ text: String) -> some View {
    HStack(spacing: PrismaSpacing.sm) {
      Image(systemName: icon)
        .foregroundStyle(PrismaColors.plusBadge)
        .frame(width: 24)
      Text(text)
        .font(PrismaTypography.body())
    }
  }

  private func purchase(_ product: Product) async {
    isPurchasing = true
    defer { isPurchasing = false }
    do {
      try await subscriptionService.purchase(product)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func purchaseMockOrFirst() async {
    if let product = subscriptionService.products.first {
      await purchase(product)
      return
    }
    if let mock = subscriptionService as? MockSubscriptionService {
      isPurchasing = true
      mock.togglePlusForTesting()
      isPurchasing = false
      dismiss()
    }
  }

  private func restore() async {
    do {
      try await subscriptionService.restorePurchases()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
