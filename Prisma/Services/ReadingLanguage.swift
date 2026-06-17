import Foundation

enum ReadingLanguage {
  static func resolved(preferences: UserPreference?) -> String {
    if let code = Locale.current.language.languageCode?.identifier, !code.isEmpty {
      return code.lowercased()
    }
    if let prefs = preferences {
      return prefs.homeCountry.primaryLanguageCode
    }
    return NewsCountry.detected.primaryLanguageCode
  }

  static func displayName(for code: String) -> String {
    Locale.current.localizedString(forLanguageCode: code) ?? code.uppercased()
  }
}

extension NewsCountry {
  var primaryLanguageCode: String {
    switch self {
    case .spain, .mexico, .argentina, .colombia, .chile, .peru:
      "es"
    case .usa, .uk:
      "en"
    case .france:
      "fr"
    case .germany:
      "de"
    case .italy:
      "it"
    case .portugal, .brazil:
      "pt"
    }
  }
}
