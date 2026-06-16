import SwiftUI

struct CountrySelectionView: View {
  @Binding var selectedCountry: NewsCountry

  private let columns = [
    GridItem(.flexible(), spacing: PrismaSpacing.sm),
    GridItem(.flexible(), spacing: PrismaSpacing.sm),
  ]

  var body: some View {
    ScrollView {
      VStack(spacing: PrismaSpacing.lg) {
        VStack(spacing: PrismaSpacing.sm) {
          Image(systemName: "globe.europe.africa.fill")
            .font(.system(size: 56))
            .foregroundStyle(PrismaColors.accentFallback)
            .padding(.top, PrismaSpacing.xl)

          Text(String(localized: "onboarding.country.title"))
            .font(PrismaTypography.largeTitle())
            .multilineTextAlignment(.center)

          Text(String(localized: "onboarding.country.subtitle"))
            .font(PrismaTypography.body())
            .foregroundStyle(PrismaColors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, PrismaSpacing.lg)
        }

        LazyVGrid(columns: columns, spacing: PrismaSpacing.sm) {
          ForEach(NewsCountry.allCases) { country in
            countryButton(country)
          }
        }
        .padding(.horizontal, PrismaSpacing.md)
      }
      .padding(.bottom, PrismaSpacing.xl)
    }
  }

  private func countryButton(_ country: NewsCountry) -> some View {
    let isSelected = selectedCountry == country

    return Button {
      selectedCountry = country
    } label: {
      HStack(spacing: PrismaSpacing.sm) {
        Text(country.flag)
          .font(.title2)
        Text(country.displayName)
          .font(PrismaTypography.callout(.semibold))
          .foregroundStyle(PrismaColors.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer(minLength: 0)
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(PrismaColors.accentFallback)
        }
      }
      .padding(PrismaSpacing.md)
      .frame(maxWidth: .infinity)
      .background {
        RoundedRectangle(cornerRadius: PrismaRadius.md, style: .continuous)
          .fill(isSelected ? PrismaColors.accentFallback.opacity(0.12) : PrismaColors.surface)
          .overlay {
            RoundedRectangle(cornerRadius: PrismaRadius.md, style: .continuous)
              .strokeBorder(
                isSelected ? PrismaColors.accentFallback : PrismaColors.separator,
                lineWidth: isSelected ? 2 : 0.5
              )
          }
      }
    }
    .buttonStyle(.plain)
  }
}
