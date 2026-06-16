import Foundation

/// Selecciona el proveedor de IA: Apple Intelligence on-device → Mock.
enum AIServiceFactory {
  @MainActor
  static func makePrimary() -> AIService {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *), FoundationModelsAIService.isSupported {
      return FoundationModelsAIService()
    }
    #endif
    return MockAIService()
  }

  /// IA local gratuita disponible (sin Prisma+ ni backend).
  static var hasFreeOnDeviceAI: Bool {
    AppleIntelligenceAvailability.current.isReady
  }
}
