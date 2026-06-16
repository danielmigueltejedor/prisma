import SwiftUI

struct OnboardingView: View {
  @Bindable var viewModel: OnboardingViewModel
  var subscriptionService: SubscriptionServiceProtocol

  @State private var showPaywall = false

  var body: some View {
    PrismaScreen {
      VStack(spacing: 0) {
        Group {
          switch viewModel.currentPage {
          case 0: welcomePage
          case 1: countryPage
          case 2: sourcesPage
          case 3: privacyPage
          case 4: plusPage
          default: welcomePage
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentPage)

        pageIndicator
          .padding(.bottom, PrismaSpacing.sm)

        if viewModel.currentPage < viewModel.totalPages - 1 {
          PrismaButton(title: String(localized: "onboarding.continue")) {
            viewModel.next()
          }
          .padding(.horizontal, PrismaSpacing.lg)
          .padding(.bottom, PrismaSpacing.lg)
        }
      }
    }
    .sheet(isPresented: $showPaywall) {
      PaywallView(
        subscriptionService: subscriptionService,
        onContinueFree: {
          showPaywall = false
          finish()
        }
      )
    }
  }

  private var pageIndicator: some View {
    HStack(spacing: PrismaSpacing.xs) {
      ForEach(0 ..< viewModel.totalPages, id: \.self) { index in
        Circle()
          .fill(index == viewModel.currentPage ? PrismaColors.accentFallback : PrismaColors.separator)
          .frame(width: index == viewModel.currentPage ? 8 : 6, height: index == viewModel.currentPage ? 8 : 6)
      }
    }
  }

  private var welcomePage: some View {
    onboardingPage(
      icon: "newspaper.fill",
      title: AppConfiguration.appName,
      subtitle: AppConfiguration.tagline,
      body: String(localized: "onboarding.welcome.body")
    )
  }

  private var countryPage: some View {
    CountrySelectionView(selectedCountry: $viewModel.selectedCountry)
  }

  private var sourcesPage: some View {
    onboardingPage(
      icon: "antenna.radiowaves.left.and.right",
      title: String(localized: "onboarding.sources.title"),
      subtitle: String(localized: "onboarding.sources.subtitle"),
      body: String(localized: "onboarding.sources.body")
    )
  }

  private var privacyPage: some View {
    onboardingPage(
      icon: "hand.raised.fill",
      title: String(localized: "onboarding.privacy.title"),
      subtitle: String(localized: "onboarding.privacy.subtitle"),
      body: String(localized: "onboarding.privacy.body")
    )
  }

  private var plusPage: some View {
    VStack(spacing: PrismaSpacing.lg) {
      onboardingPage(
        icon: "sparkles",
        title: "Prisma+",
        subtitle: String(localized: "onboarding.plus.subtitle"),
        body: String(localized: "onboarding.plus.body")
      )

      VStack(spacing: PrismaSpacing.sm) {
        PrismaButton(title: String(localized: "paywall.startTrial")) {
          showPaywall = true
        }
        PrismaButton(title: String(localized: "paywall.continueFree"), style: .secondary) {
          finish()
        }
      }
      .padding(.horizontal, PrismaSpacing.lg)
    }
  }

  private func onboardingPage(icon: String, title: String, subtitle: String, body: String) -> some View {
    VStack(spacing: PrismaSpacing.md) {
      Image(systemName: icon)
        .font(.system(size: 56))
        .foregroundStyle(PrismaColors.accentFallback)
        .padding(.top, PrismaSpacing.xxl)

      Text(title)
        .font(PrismaTypography.largeTitle())
        .multilineTextAlignment(.center)

      Text(subtitle)
        .font(PrismaTypography.title(.regular))
        .foregroundStyle(PrismaColors.textSecondary)
        .multilineTextAlignment(.center)

      Text(body)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, PrismaSpacing.xl)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func finish() {
    _ = viewModel.completeOnboarding()
    UserDefaults.standard.set(true, forKey: "prisma.hasCompletedOnboarding")
  }
}
