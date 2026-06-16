import Foundation

enum SubscriptionProducts {
  static let monthly = "com.prisma.plus.monthly"
  static let yearly = "com.prisma.plus.yearly"
  static let all = [monthly, yearly]

  static let monthlyPriceDisplay = "1,99 €"
  static let yearlyPriceDisplay = "19,99 €"
  static let trialDays = 7
}
