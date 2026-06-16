import SwiftUI

struct AddSourceView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var viewModel: SourcesViewModel

  @State private var name = ""
  @State private var url = ""

  var body: some View {
    NavigationStack {
      Form {
        Section(String(localized: "sources.add.manual")) {
          TextField(String(localized: "sources.field.name"), text: $name)
          TextField(String(localized: "sources.field.url"), text: $url)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .autocorrectionDisabled()
        }

        if viewModel.isSearching {
          recommendedSection(String(localized: "sources.search"), feeds: viewModel.filteredRecommended)
        } else {
          recommendedSection(
            String(localized: "sources.local \(viewModel.homeCountry.displayName)"),
            feeds: viewModel.localRecommended
          )
          recommendedSection(String(localized: "sources.international"), feeds: viewModel.internationalRecommended)

          if !viewModel.otherRecommended.isEmpty {
            DisclosureGroup(
              isExpanded: $viewModel.showOtherCountries,
              content: {
                ForEach(viewModel.otherRecommended) { feed in
                  recommendedRow(feed)
                }
              },
              label: {
                Text(String(localized: "sources.otherCountries"))
                  .font(PrismaTypography.callout(.semibold))
              }
            )
          }
        }
      }
      .searchable(text: $viewModel.searchText, prompt: String(localized: "sources.search"))
      .navigationTitle(String(localized: "sources.add"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "action.cancel")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "action.save")) {
            Task {
              await viewModel.addManual(name: name, url: url)
              dismiss()
            }
          }
          .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
  }

  @ViewBuilder
  private func recommendedSection(_ title: String, feeds: [RecommendedFeed]) -> some View {
    if !feeds.isEmpty {
      Section(title) {
        ForEach(feeds) { feed in
          recommendedRow(feed)
        }
      }
    }
  }

  private func recommendedRow(_ feed: RecommendedFeed) -> some View {
    HStack(spacing: PrismaSpacing.sm) {
      SourceIconView(siteURL: feed.siteURL, feedURL: feed.feedURL, size: 32)
      VStack(alignment: .leading) {
        Text(feed.name)
          .font(PrismaTypography.body(.medium))
        Text(feed.category)
          .font(PrismaTypography.caption())
          .foregroundStyle(PrismaColors.textSecondary)
      }
      Spacer()
      Button(String(localized: "action.add")) {
        Task { await viewModel.addRecommended(feed) }
      }
    }
  }
}
