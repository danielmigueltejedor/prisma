import Foundation

/// Application-only OAuth for Reddit's official API (installed app grant).
actor RedditOAuthClient {
  private let clientID: String
  private let userAgent: String
  private let session: URLSession
  private let deviceID: String

  private var accessToken: String?
  private var tokenExpiresAt: Date?

  init(clientID: String, session: URLSession = .shared) {
    self.clientID = clientID
    self.session = session
    self.userAgent = "iOS:\(AppConfiguration.bundleIdentifier):1.0 (by /u/prisma_reader)"
    self.deviceID = Self.persistedDeviceID()
  }

  func authorizedRequest(url: URL) async throws -> URLRequest {
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
    return request
  }

  private func accessToken() async throws -> String {
    if let accessToken, let tokenExpiresAt, tokenExpiresAt > Date().addingTimeInterval(120) {
      return accessToken
    }

    guard let url = URL(string: "https://www.reddit.com/api/v1/access_token") else {
      throw NetworkError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue(
      "Basic \(Data("\(clientID):".utf8).base64EncodedString())",
      forHTTPHeaderField: "Authorization"
    )

    let body = "grant_type=https://oauth.reddit.com/grants/installed_client&device_id=\(deviceID)"
    request.httpBody = Data(body.utf8)

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw NetworkError.invalidResponse
    }
    guard (200 ... 299).contains(http.statusCode) else {
      throw NetworkError.httpStatus(http.statusCode)
    }

    guard
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let token = json["access_token"] as? String,
      let expiresIn = json["expires_in"] as? Double
    else {
      throw NetworkError.decodingFailed
    }

    accessToken = token
    tokenExpiresAt = Date().addingTimeInterval(expiresIn)
    return token
  }

  private static func persistedDeviceID() -> String {
    let key = "reddit_oauth_device_id"
    if let existing = UserDefaults.standard.string(forKey: key), existing.count >= 20 {
      return existing
    }
    let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(22)
    let value = "prisma_\(generated)"
    UserDefaults.standard.set(value, forKey: key)
    return value
  }
}
