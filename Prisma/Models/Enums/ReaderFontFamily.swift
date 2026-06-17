import Foundation
import SwiftUI

enum ReaderFontFamily: String, Codable, CaseIterable, Identifiable {
  case system
  case serif
  case rounded

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system: String(localized: "reader.font.system")
    case .serif: String(localized: "reader.font.serif")
    case .rounded: String(localized: "reader.font.rounded")
    }
  }

  var fontDesign: Font.Design {
    switch self {
    case .system: .default
    case .serif: .serif
    case .rounded: .rounded
    }
  }

  var cssStack: String {
    switch self {
    case .system:
      "-apple-system-ui, -apple-system, BlinkMacSystemFont, sans-serif"
    case .serif:
      "Georgia, 'Iowan Old Style', 'Palatino Linotype', Palatino, serif"
    case .rounded:
      "ui-rounded, -apple-system-ui, -apple-system, BlinkMacSystemFont, sans-serif"
    }
  }
}
