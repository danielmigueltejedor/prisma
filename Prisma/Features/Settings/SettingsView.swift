import SwiftUI

struct SettingsView: View {
  @Bindable var viewModel: SettingsViewModel

  var body: some View {
    NavigationStack {
      PrismaScreen {
        Form {
          AppleIntelligenceSettingsSection()

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

          Section(String(localized: "settings.experiments")) {
            VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
              Label(String(localized: "settings.siriReading"), systemImage: "speaker.wave.2.fill")
                .font(PrismaTypography.body())
              Text(String(localized: "settings.siriReading.hint"))
                .font(PrismaTypography.caption())
                .foregroundStyle(PrismaColors.textSecondary)
            }
            .padding(.vertical, PrismaSpacing.xxs)
          }

          Section(String(localized: "settings.general")) {
            Picker(selection: homeCountryBinding) {
              ForEach(NewsCountry.allCases) { country in
                Text(country.displayName)
                  .tag(country)
              }
            } label: {
              Label(String(localized: "settings.homeCountry"), systemImage: "globe")
            }

            VStack(alignment: .leading, spacing: PrismaSpacing.xxs) {
              TextField(String(localized: "settings.weatherLocation"), text: weatherLocationBinding)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
              weatherLocationStatusView
              if viewModel.weatherLocationLookup == .idle {
                Text(String(localized: "settings.weatherLocationHint"))
                  .font(PrismaTypography.caption())
                  .foregroundStyle(PrismaColors.textSecondary)
              }
            }

            NavigationLink(String(localized: "settings.appearance")) {
              AppearanceSettingsView(viewModel: viewModel)
            }
            NavigationLink(String(localized: "settings.privacy")) {
              PrivacyView()
            }
          }

          Section(String(localized: "settings.localCorpus")) {
            Picker(selection: localCorpusLimitBinding) {
              Text(String(localized: "settings.localCorpus.off")).tag(0)
              Text(String(localized: "settings.localCorpus.128mb")).tag(128)
              Text(String(localized: "settings.localCorpus.256mb")).tag(256)
              Text(String(localized: "settings.localCorpus.512mb")).tag(512)
              Text(String(localized: "settings.localCorpus.1024mb")).tag(1024)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "settings.localCorpus.title"))
                Text(String(localized: "settings.localCorpus.hint"))
                  .font(PrismaTypography.caption())
                  .foregroundStyle(PrismaColors.textSecondary)
              }
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
            Link(String(localized: "settings.terms"), destination: AppConfiguration.termsURL)
          }
        }
        .scrollContentBackground(.hidden)
      }
      .navigationTitle(String(localized: "tab.settings"))
      .onAppear { viewModel.load() }
    }
  }

  private var localCorpusLimitBinding: Binding<Int> {
    Binding(
      get: { viewModel.preferences?.localCorpusLimitMB ?? UserPreference.defaultLocalCorpusLimitMB },
      set: { viewModel.setLocalCorpusLimitMB($0) }
    )
  }

  private var homeCountryBinding: Binding<NewsCountry> {
    Binding(
      get: { viewModel.preferences?.homeCountry ?? .detected },
      set: { viewModel.setHomeCountry($0) }
    )
  }

  private var weatherLocationBinding: Binding<String> {
    Binding(
      get: { viewModel.preferences?.weatherLocationQuery ?? "" },
      set: { viewModel.setWeatherLocation($0) }
    )
  }

  @ViewBuilder
  private var weatherLocationStatusView: some View {
    switch viewModel.weatherLocationLookup {
    case .idle:
      EmptyView()
    case .searching:
      HStack(spacing: PrismaSpacing.xxs) {
        ProgressView()
          .controlSize(.small)
        Text(String(localized: "settings.weatherLocationSearching"))
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textSecondary)
      }
    case .resolved(let match):
      Label {
        Text(String(localized: "settings.weatherLocationFound \(match.shortLabel)"))
          .font(PrismaTypography.caption())
      } icon: {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
      }
    case .notFound:
      Label {
        Text(String(localized: "settings.weatherLocationNotFound"))
          .font(PrismaTypography.caption())
      } icon: {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
      }
    }
  }
}
