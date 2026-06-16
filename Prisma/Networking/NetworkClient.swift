import Foundation

struct NetworkClient {
  var session: URLSession = .shared
  var timeout: TimeInterval = 30

  func fetchData(from urlString: String) async throws -> Data {
    guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      throw NetworkError.invalidURL
    }
    return try await fetchData(from: url)
  }

  func fetchData(from url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    request.setValue("Prisma/1.0 RSS Reader", forHTTPHeaderField: "User-Agent")

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
    return data
  }
}
