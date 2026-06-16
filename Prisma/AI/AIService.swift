import Foundation

protocol AIService: Sendable {
  func summarizeArticle(_ article: Article) async throws -> SummaryDTO
  func classifyArticle(_ article: Article) async throws -> [String]
  func clusterArticles(_ articles: [Article]) async throws -> [ClusterDTO]
  func compareSources(cluster: ClusterDTO, articles: [Article]) async throws -> String
  func generateDailyBriefing(articles: [Article], preferences: UserPreference) async throws -> DailyBriefingDTO
  func explainContext(article: Article) async throws -> ContextExplanationDTO
}

enum AIServiceError: LocalizedError {
  case notAvailable
  case quotaExceeded
  case backendUnavailable

  var errorDescription: String? {
    switch self {
    case .notAvailable: String(localized: "error.ai.notAvailable")
    case .quotaExceeded: String(localized: "error.ai.quota")
    case .backendUnavailable: String(localized: "error.ai.backend")
    }
  }
}
