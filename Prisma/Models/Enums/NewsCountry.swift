import Foundation

enum NewsCountry: String, CaseIterable, Identifiable, Codable {
  case spain = "ES"
  case mexico = "MX"
  case argentina = "AR"
  case colombia = "CO"
  case chile = "CL"
  case peru = "PE"
  case usa = "US"
  case uk = "GB"
  case france = "FR"
  case germany = "DE"
  case italy = "IT"
  case portugal = "PT"
  case brazil = "BR"

  var id: String { rawValue }

  var code: String { rawValue }

  var displayName: String {
    switch self {
    case .spain: String(localized: "country.ES")
    case .mexico: String(localized: "country.MX")
    case .argentina: String(localized: "country.AR")
    case .colombia: String(localized: "country.CO")
    case .chile: String(localized: "country.CL")
    case .peru: String(localized: "country.PE")
    case .usa: String(localized: "country.US")
    case .uk: String(localized: "country.GB")
    case .france: String(localized: "country.FR")
    case .germany: String(localized: "country.DE")
    case .italy: String(localized: "country.IT")
    case .portugal: String(localized: "country.PT")
    case .brazil: String(localized: "country.BR")
    }
  }

  var flag: String {
    code
      .uppercased()
      .unicodeScalars
      .compactMap { UnicodeScalar(127_397 + $0.value) }
      .map { String($0) }
      .joined()
  }

  static func from(code: String?) -> NewsCountry? {
    guard let code else { return nil }
    return NewsCountry(rawValue: code.uppercased())
  }

  static var detected: NewsCountry {
    if let region = Locale.current.region?.identifier,
       let country = NewsCountry(rawValue: region.uppercased()) {
      return country
    }
    if Locale.current.language.languageCode?.identifier == "es" {
      return .spain
    }
    return .usa
  }

  var usesFahrenheit: Bool {
    self == .usa
  }

  /// City shown when no custom weather location is set.
  var weatherDefaultLocality: String {
    switch self {
    case .spain: "Madrid"
    case .mexico: "Ciudad de México"
    case .argentina: "Buenos Aires"
    case .colombia: "Bogotá"
    case .chile: "Santiago"
    case .peru: "Lima"
    case .usa: "New York"
    case .uk: "London"
    case .france: "Paris"
    case .germany: "Berlin"
    case .italy: "Rome"
    case .portugal: "Lisbon"
    case .brazil: "São Paulo"
    }
  }

  /// Representative coordinates for weather (capital or major city).
  var weatherCoordinates: (latitude: Double, longitude: Double) {
    switch self {
    case .spain: (40.4168, -3.7038)
    case .mexico: (19.4326, -99.1332)
    case .argentina: (-34.6037, -58.3816)
    case .colombia: (4.711, -74.0721)
    case .chile: (-33.4489, -70.6693)
    case .peru: (-12.0464, -77.0428)
    case .usa: (40.7128, -74.0060)
    case .uk: (51.5074, -0.1278)
    case .france: (48.8566, 2.3522)
    case .germany: (52.5200, 13.4050)
    case .italy: (41.9028, 12.4964)
    case .portugal: (38.7223, -9.1393)
    case .brazil: (-23.5505, -46.6333)
    }
  }
}
