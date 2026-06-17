import Foundation

enum AppConfiguration {
  static let appName = "Prisma"
  static let tagline = String(localized: "app.tagline")
  static let bundleIdentifier = "com.danielmigueltejedor.prisma"
  /// Versión mínima de iOS (Foundation Models / Apple Intelligence).
  static let minimumIOSVersion = "26.0"
  static let supportEmail = "support@prisma.app"
  static let privacyPolicyURL = URL(string: "https://prisma.app/privacy")!
  static let termsURL = URL(string: "https://prisma.app/terms")!
  static let buyMeACoffeeURL = URL(string: "https://buymeacoffee.com/danielmigueltejedor")!

  /// Optional Reddit "installed app" client ID from https://www.reddit.com/prefs/apps
  /// When set, comments load from the official API; otherwise a public mirror is used.
  static let redditClientID: String? = nil
}
