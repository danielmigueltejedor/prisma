import Foundation

enum NetworkError: LocalizedError {
  case invalidURL
  case invalidResponse
  case httpStatus(Int)
  case noData
  case decodingFailed
  case responseTooLarge

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      String(localized: "error.network.invalidURL")
    case .invalidResponse:
      String(localized: "error.network.invalidResponse")
    case .httpStatus(let code):
      String(localized: "error.network.http \(code)")
    case .noData:
      String(localized: "error.network.noData")
    case .decodingFailed:
      String(localized: "error.network.decoding")
    case .responseTooLarge:
      String(localized: "error.network.responseTooLarge")
    }
  }
}
