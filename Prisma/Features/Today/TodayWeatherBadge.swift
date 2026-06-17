import SwiftUI

struct TodayWeatherBadge: View {
  let weather: WeatherSnapshot?

  var body: some View {
    Group {
      if let weather {
        HStack(spacing: PrismaSpacing.xxs) {
          Image(systemName: weather.symbolName)
            .symbolRenderingMode(.multicolor)
            .font(.system(size: 16, weight: .semibold))
          Text(weather.formattedTemperature)
            .font(PrismaTypography.callout(.semibold))
            .foregroundStyle(PrismaColors.textPrimary)
        }
        .padding(.horizontal, PrismaSpacing.sm)
        .padding(.vertical, PrismaSpacing.xxs)
        .modifier(WeatherBadgeGlassBackground())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          String(
            localized: "today.weather.accessibility.location \(weather.formattedTemperature) \(weather.locationSource.displayLabel)"
          )
        )
      }
    }
  }
}

private struct WeatherBadgeGlassBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: .capsule)
    } else {
      content.prismaGlass(cornerRadius: 999)
    }
  }
}
