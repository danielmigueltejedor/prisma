import SwiftUI

struct SettingsView: View {
  @Bindable var viewModel: SettingsViewModel
  var subscriptionService: SubscriptionServiceProtocol
  var onShowPaywall: () -> Void

  var body: some View {
    NavigationStack {
      PrismaScreen {
        Form {
          SubscriptionManagementView(
            subscriptionService: subscriptionService,
            showPaywall: onShowPaywall
          )

          Section(String(localized: "settings.blocked")) {
            HStack {
              TextField(String(localized: "settings.blockedPlaceholder"), text: $viewModel.blockedKeywordInput)
              Button(String(localized: "action.add")) {
                viewModel.addBlockedKeyword()
              }
            }
            if let keywords = viewModel.preferences?.blockedKeywords {
              ForEach(keywords, id: \.self) { keyword in
                HStack {
                  Text(keyword)
                  Spacer()
                  Button(role: .destructive) {
                    viewModel.removeBlockedKeyword(keyword)
                  } label: {
                    Image(systemName: "xmark.circle.fill")
                  }
                }
              }
            }
          }

          Section(String(localized: "settings.general")) {
            Picker(selection: homeCountryBinding) {
              ForEach(NewsCountry.allCases) { country in
                Label {
                  Text(country.displayName)
                } icon: {
                  Text(country.flag)
                }
                .tag(country)
              }
            } label: {
              Label(String(localized: "settings.homeCountry"), systemImage: "globe")
            }

            Picker(selection: appearanceBinding) {
              ForEach(AppearanceMode.allCases) { mode in
                Label(mode.displayName, systemImage: mode.iconName)
                  .tag(mode)
              }
            } label: {
              Label(String(localized: "settings.theme"), systemImage: "moon.fill")
            }

            NavigationLink(String(localized: "settings.appearance")) {
              AppearanceSettingsView(viewModel: viewModel)
            }
            NavigationLink(String(localized: "settings.privacy")) {
              PrivacyView()
            }
          }

          Section(String(localized: "settings.data")) {
            Button(String(localized: "settings.clearData"), role: .destructive) {
              viewModel.clearAllData()
            }
          }

          Section(String(localized: "settings.about")) {
            LabeledContent(String(localized: "settings.version"), value: "1.0.0")
            Link(String(localized: "settings.privacyPolicy"), destination: AppConfiguration.privacyPolicyURL)
          }
        }
        .scrollContentBackground(.hidden)
      }
      .navigationTitle(String(localized: "tab.settings"))
      .onAppear { viewModel.load() }
    }
  }

  private var appearanceBinding: Binding<AppearanceMode> {
    Binding(
      get: { viewModel.preferences?.appearanceMode ?? .system },
      set: { viewModel.setAppearance($0) }
    )
  }

  private var homeCountryBinding: Binding<NewsCountry> {
    Binding(
      get: { viewModel.preferences?.homeCountry ?? .detected },
      set: { viewModel.setHomeCountry($0) }
    )
  }
}
