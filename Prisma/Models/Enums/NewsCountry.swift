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
}
