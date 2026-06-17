import SwiftUI
import SwiftData

struct RootView: View {
  let dependencies: AppDependencies
  @Query private var preferences: [UserPreference]

  @State private var isBootstrapped = false
  @State private var onboardingViewModel: OnboardingViewModel?
  @AppStorage("prisma.hasCompletedOnboarding") private var onboardingCompletedFallback = false

  private var hasCompletedOnboarding: Bool {
    preferences.first?.hasCompletedOnboarding == true || onboardingCompletedFallback
  }

  var body: some View {
    Group {
      if !isBootstrapped {
        PrismaScreen {
          LoadingView(message: String(localized: "app.loading"))
        }
      } else if !hasCompletedOnboarding, let onboardingViewModel {
        OnboardingView(viewModel: onboardingViewModel)
      } else if !hasCompletedOnboarding {
        PrismaScreen {
          LoadingView(message: String(localized: "app.loading"))
        }
        .task {
          if onboardingViewModel == nil {
            onboardingViewModel = OnboardingViewModel(
              preferenceRepository: dependencies.preferenceRepository,
              feedSourceRepository: dependencies.feedSourceRepository
            )
          }
        }
      } else {
        MainTabView(dependencies: dependencies)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .preferredColorScheme(colorScheme)
    .task {
      await bootstrap()
    }
  }

  private var colorScheme: ColorScheme? {
    preferences.first?.appearanceMode.colorScheme
  }

  private func bootstrap() async {
    do {
      try await dependencies.bootstrap()
      isBootstrapped = true
    } catch {
      isBootstrapped = true
    }
  }
}
