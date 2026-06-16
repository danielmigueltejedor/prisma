import Foundation

enum AppConfiguration {
  static let appName = "Prisma"
  static let tagline = String(localized: "app.tagline")
  static let bundleIdentifier = "com.danielmigueltejedor.prisma"
  static let supportEmail = "support@prisma.app"
  static let privacyPolicyURL = URL(string: "https://prisma.app/privacy")!
  static let termsURL = URL(string: "https://prisma.app/terms")!

  #if DEBUG
  static let useMockSubscription = true
  #else
  static let useMockSubscription = false
  #endif
}
