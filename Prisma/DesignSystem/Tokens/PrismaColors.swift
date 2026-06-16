import SwiftUI

enum PrismaColors {
    static let accent = Color("Accent", bundle: nil)
    static let accentFallback = Color(red: 0.22, green: 0.45, blue: 0.95)

    static let plusBadge = Color(red: 0.55, green: 0.35, blue: 0.95)
    static let success = Color(red: 0.20, green: 0.72, blue: 0.45)
    static let warning = Color(red: 0.95, green: 0.65, blue: 0.15)
    static let danger = Color(red: 0.92, green: 0.30, blue: 0.28)

    static var background: Color { Color(.systemGroupedBackground) }
    static var surface: Color { Color(.secondarySystemGroupedBackground) }
    static var elevatedSurface: Color { Color(.tertiarySystemGroupedBackground) }
    static var textPrimary: Color { Color(.label) }
    static var textSecondary: Color { Color(.secondaryLabel) }
    static var textTertiary: Color { Color(.tertiaryLabel) }
    static var separator: Color { Color(.separator) }

    static var glassOverlay: Color {
        Color.primary.opacity(0.04)
    }
}
