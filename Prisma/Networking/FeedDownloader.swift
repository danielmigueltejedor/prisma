import Foundation

struct FeedDownloader {
  let networkClient: NetworkClient

  func downloadFeed(from urlString: String) async throws -> Data {
    try await networkClient.fetchData(from: urlString)
  }
}
