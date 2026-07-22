import SwiftUI

struct OnboardingView: View {
  @Bindable var viewModel: OnboardingViewModel
  @FocusState private var searchFocused: Bool

  var body: some View {
    PrismaScreen {
      VStack(spacing: 0) {
        TabView(selection: $viewModel.currentPage) {
          welcomePage
            .tag(0)

          countryPage
            .tag(1)

          sourcesPage
            .tag(2)

          privacyPage
            .tag(3)

          aiPage
            .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.currentPage) { oldPage, newPage in
          if newPage == 2, oldPage != 2 {
            viewModel.prepareSourcesPage()
          }
        }

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
    VStack(spacing: PrismaSpacing.sm) {
      VStack(spacing: PrismaSpacing.xxs) {
        Text(String(localized: "onboarding.sources.title"))
          .font(PrismaTypography.title(.semibold))
          .multilineTextAlignment(.center)

        Text(String(localized: "onboarding.sources.subtitle"))
          .font(PrismaTypography.callout())
          .foregroundStyle(PrismaColors.textSecondary)
          .multilineTextAlignment(.center)

        Text(viewModel.selectedCountLabel)
          .font(PrismaTypography.caption(.semibold))
          .foregroundStyle(PrismaColors.accentFallback)
      }
      .padding(.horizontal, PrismaSpacing.lg)
      .padding(.top, PrismaSpacing.md)

      sourcesSearchField
        .padding(.horizontal, PrismaSpacing.lg)

      StyleFilterBar(
        filters: viewModel.styleFilters,
        selection: $viewModel.selectedStyle
      )

      if viewModel.displayedFeeds.isEmpty {
        Spacer(minLength: PrismaSpacing.md)
        EmptyStateView(
          icon: "magnifyingglass",
          title: String(localized: "search.noResults.title"),
          message: viewModel.isSearching
            ? String(localized: "search.noResults.message")
            : String(localized: "onboarding.sources.emptyFilter")
        )
        .padding(.horizontal, PrismaSpacing.lg)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: PrismaSpacing.sm) {
            ForEach(viewModel.displayedFeeds) { feed in
              onboardingFeedRow(feed)
            }
          }
          .padding(.horizontal, PrismaSpacing.lg)
          .padding(.bottom, PrismaSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      viewModel.prepareSourcesPage()
    }
  }

  private var sourcesSearchField: some View {
    HStack(spacing: PrismaSpacing.sm) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(PrismaColors.textTertiary)

      TextField(String(localized: "sources.search"), text: $viewModel.searchText)
        .font(PrismaTypography.body())
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($searchFocused)

      if !viewModel.searchText.isEmpty {
        Button {
          viewModel.searchText = ""
          searchFocused = false
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(PrismaColors.textTertiary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, PrismaSpacing.md)
    .padding(.vertical, PrismaSpacing.sm)
    .prismaGlass(cornerRadius: PrismaRadius.md)
  }

  private func onboardingFeedRow(_ feed: RecommendedFeed) -> some View {
    let isSelected = viewModel.isFeedSelected(feed.id)
    return Button {
      viewModel.toggleFeed(feed.id)
      HapticFeedback.light()
    } label: {
      HStack(spacing: PrismaSpacing.md) {
        SourceIconView(
          siteURL: feed.siteURL,
          feedURL: feed.feedURL,
          platform: feed.feedPlatform,
          size: 28
        )

        VStack(alignment: .leading, spacing: 2) {
          Text(feed.name)
            .font(PrismaTypography.callout(.semibold))
            .foregroundStyle(PrismaColors.textPrimary)
            .lineLimit(1)
          HStack(spacing: PrismaSpacing.xs) {
            Text(ContentStyleFilter.style(for: feed))
              .font(PrismaTypography.caption2(.semibold))
              .foregroundStyle(PrismaColors.accentFallback)
            if let country = NewsCountry.from(code: feed.countryCode) {
              Text(country.displayName)
                .font(PrismaTypography.caption2())
                .foregroundStyle(PrismaColors.textTertiary)
                .lineLimit(1)
            }
          }
          if let description = feed.description {
            Text(description)
              .font(PrismaTypography.caption2())
              .foregroundStyle(PrismaColors.textSecondary)
              .lineLimit(2)
          }
        }

        Spacer(minLength: PrismaSpacing.sm)

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? PrismaColors.accentFallback : PrismaColors.separator)
      }
      .padding(PrismaSpacing.md)
      .prismaGlass(cornerRadius: PrismaRadius.md)
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: PrismaRadius.md, style: .continuous)
            .stroke(PrismaColors.accentFallback.opacity(0.35), lineWidth: 1)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(feed.name)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var privacyPage: some View {
    onboardingPage(
      icon: "hand.raised.fill",
      title: String(localized: "onboarding.privacy.title"),
      subtitle: String(localized: "onboarding.privacy.subtitle"),
      body: String(localized: "onboarding.privacy.body")
    )
  }

  private var aiPage: some View {
    VStack(spacing: PrismaSpacing.lg) {
      onboardingPage(
        icon: "apple.intelligence",
        title: String(localized: "onboarding.ai.title"),
        subtitle: String(localized: "onboarding.ai.subtitle"),
        body: String(localized: "onboarding.ai.body")
      )

      if AIServiceFactory.hasFreeOnDeviceAI {
        LocalAIBadge()
      }

      PrismaButton(title: String(localized: "onboarding.start")) {
        finish()
      }
      .padding(.horizontal, PrismaSpacing.lg)
      .padding(.bottom, PrismaSpacing.lg)
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
