import SwiftUI

struct AddSourceView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var viewModel: SourcesViewModel

  @State private var name = ""
  @State private var url = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          StyleFilterBar(
            filters: viewModel.recommendedStyleFilters,
            selection: $viewModel.selectedStyle
          )
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
        }

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
          recommendedSection(String(localized: "sources.reddit"), feeds: viewModel.redditRecommended)
          recommendedSection(String(localized: "sources.social"), feeds: viewModel.socialRecommended)

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
          PrismaDismissButton { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "action.save")) {
            Task {
              let added = await viewModel.addManual(name: name, url: url)
              if added { dismiss() }
            }
          }
          .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isRefreshing)
        }
      }
    }
  }

  @ViewBuilder
  private func recommendedSection(_ title: String, feeds: [RecommendedFeed]) -> some View {
    if !feeds.isEmpty {
      Section(title) {
        ForEach(groupedByCategory(feeds), id: \.key) { group in
          VStack(alignment: .leading, spacing: PrismaSpacing.xs) {
            Text(group.key)
              .font(PrismaTypography.caption(.semibold))
              .foregroundStyle(PrismaColors.textTertiary)
            ForEach(group.value) { feed in
              recommendedRow(feed)
            }
          }
          .padding(.vertical, PrismaSpacing.xxs)
        }
      }
    }
  }

  private func groupedByCategory(_ feeds: [RecommendedFeed]) -> [(key: String, value: [RecommendedFeed])] {
    Dictionary(grouping: feeds, by: \.category)
      .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
      .sorted { $0.key < $1.key }
  }

  private func recommendedRow(_ feed: RecommendedFeed) -> some View {
    HStack(spacing: PrismaSpacing.sm) {
      SourceIconView(
        siteURL: feed.siteURL,
        feedURL: feed.feedURL,
        platform: feed.feedPlatform,
        size: 32
      )
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
      .disabled(viewModel.isRefreshing)
    }
  }
}
