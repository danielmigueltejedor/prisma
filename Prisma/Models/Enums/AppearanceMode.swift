import Foundation
import SwiftUI

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system: String(localized: "appearance.system")
    case .light: String(localized: "appearance.light")
    case .dark: String(localized: "appearance.dark")
    }
  }

  var iconName: String {
    switch self {
    case .system: "circle.lefthalf.filled"
    case .light: "sun.max.fill"
    case .dark: "moon.fill"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}
