import Foundation

/// Estado de Apple Intelligence / Foundation Models en este dispositivo.
enum AppleIntelligenceAvailability: Equatable, Sendable {
  case available
  case deviceNotEligible
  case notEnabled
  case modelDownloading
  case frameworkUnavailable
  case unknown

  var isReady: Bool {
    self == .available
  }

  var userMessageKey: String? {
    switch self {
    case .available, .frameworkUnavailable: nil
    case .deviceNotEligible: "ai.availability.deviceNotEligible"
    case .notEnabled: "ai.availability.notEnabled"
    case .modelDownloading: "ai.availability.modelDownloading"
    case .unknown: "ai.availability.unknown"
    }
  }

  static var current: AppleIntelligenceAvailability {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      return FoundationModelsAvailabilityChecker.check()
    }
    #endif
    return .frameworkUnavailable
  }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
private enum FoundationModelsAvailabilityChecker {
  static func check() -> AppleIntelligenceAvailability {
    switch SystemLanguageModel.default.availability {
    case .available:
      return .available
    case .unavailable(.deviceNotEligible):
      return .deviceNotEligible
    case .unavailable(.appleIntelligenceNotEnabled):
      return .notEnabled
    case .unavailable(.modelNotReady):
      return .modelDownloading
    case .unavailable:
      return .unknown
    @unknown default:
      return .unknown
    }
  }
}
#endif
