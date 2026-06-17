import Foundation

struct NetworkClient {
  static let maxFeedResponseBytes = 10 * 1024 * 1024
  static let maxImageResponseBytes = 15 * 1024 * 1024

  private static let sharedSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = URLCache(
      memoryCapacity: 20_000_000,
      diskCapacity: 100_000_000
    )
    configuration.requestCachePolicy = .useProtocolCachePolicy
    configuration.waitsForConnectivity = false
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 120
    configuration.httpMaximumConnectionsPerHost = 4
    return URLSession(configuration: configuration)
  }()

  var session: URLSession = NetworkClient.sharedSession
  var timeout: TimeInterval = 30

  func fetchData(from urlString: String, platform: FeedPlatform = .news) async throws -> Data {
    guard let url = SafeURL.httpURL(from: urlString) else {
      throw NetworkError.invalidURL
    }
    return try await fetchData(from: url, platform: platform, maxBytes: Self.maxFeedResponseBytes)
  }

  func fetchData(from url: URL, platform: FeedPlatform = .news) async throws -> Data {
    try await fetchData(from: url, platform: platform, maxBytes: Self.maxFeedResponseBytes)
  }

  private func fetchData(from url: URL, platform: FeedPlatform, maxBytes: Int) async throws -> Data {
    guard SafeURL.isAllowedHTTPScheme(url) else {
      throw NetworkError.invalidURL
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    request.cachePolicy = .useProtocolCachePolicy
    request.setValue(userAgent(for: platform), forHTTPHeaderField: "User-Agent")

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw NetworkError.invalidResponse
    }
    guard (200 ... 299).contains(http.statusCode) else {
      throw NetworkError.httpStatus(http.statusCode)
    }
    guard !data.isEmpty else {
      throw NetworkError.noData
    }
    guard data.count <= maxBytes else {
      throw NetworkError.responseTooLarge
    }
    return data
  }

  private func userAgent(for platform: FeedPlatform) -> String {
    switch platform {
    case .reddit:
      "iOS:\(AppConfiguration.bundleIdentifier):1.0 (by /u/prisma_reader)"
    case .x:
      "Mozilla/5.0 (compatible; PrismaRSS/1.0; +https://prisma.app)"
    case .news:
      "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
    }
  }
}
