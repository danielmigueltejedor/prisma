import Foundation

struct WeatherLocationMatch: Equatable {
  let name: String
  let admin1: String?
  let admin2: String?
  let country: String
  let latitude: Double
  let longitude: Double

  var shortLabel: String {
    if let admin2 {
      let province = admin2
        .replacingOccurrences(of: "Provincia de ", with: "")
        .replacingOccurrences(of: "Province of ", with: "")
      return "\(name), \(province)"
    }
    if let admin1 {
      return "\(name), \(admin1)"
    }
    return "\(name), \(country)"
  }
}

enum WeatherLocationSource: Equatable {
  case countryDefault(NewsCountry)
  case custom(WeatherLocationMatch)

  var displayLabel: String {
    switch self {
    case .countryDefault(let country):
      String(localized: "weather.location.default \(country.weatherDefaultLocality)")
    case .custom(let match):
      match.shortLabel
    }
  }
}

struct WeatherSnapshot: Equatable {
  let temperature: Int
  let weatherCode: Int
  let usesFahrenheit: Bool
  let locationSource: WeatherLocationSource

  var symbolName: String {
    WeatherConditionSymbol.name(for: weatherCode)
  }

  var formattedTemperature: String {
    "\(temperature)°"
  }
}

enum WeatherConditionSymbol {
  static func name(for code: Int) -> String {
    switch code {
    case 0:
      return "sun.max.fill"
    case 1, 2, 3:
      return "cloud.sun.fill"
    case 45, 48:
      return "cloud.fog.fill"
    case 51, 53, 55, 56, 57:
      return "cloud.drizzle.fill"
    case 61, 63, 65, 66, 67:
      return "cloud.rain.fill"
    case 71, 73, 75, 77:
      return "cloud.snow.fill"
    case 80, 81, 82:
      return "cloud.heavyrain.fill"
    case 85, 86:
      return "cloud.snow.fill"
    case 95, 96, 99:
      return "cloud.bolt.rain.fill"
    default:
      return "cloud.fill"
    }
  }
}

enum WeatherLocationLookupState: Equatable {
  case idle
  case searching
  case resolved(WeatherLocationMatch)
  case notFound
}
