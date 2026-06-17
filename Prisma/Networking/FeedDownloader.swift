import Foundation

struct FeedDownloader {
  let networkClient: NetworkClient

  func downloadFeed(
    from urlString: String,
    platform: FeedPlatform = .news,
    alternateURLs: [URL] = []
  ) async throws -> Data {
    let candidates = candidateURLs(
      primary: urlString,
      platform: platform,
      alternateURLs: alternateURLs
    )
    guard !candidates.isEmpty else { throw NetworkError.invalidURL }

    var lastError: Error = NetworkError.invalidURL
    for url in candidates {
      do {
        let data = try await networkClient.fetchData(from: url, platform: platform)
        if FeedJunkFilter.looksLikeBlockedPlaceholderPayload(data) {
          lastError = NetworkError.noData
          continue
        }
        return data
      } catch {
        lastError = error
      }
    }
    throw lastError
  }

  func downloadFeed(
    for source: FeedSource
  ) async throws -> (data: Data, resolvedURL: String) {
    let alternates = FeedURLCatalog.alternateURLs(matching: source)
    let candidates = candidateURLs(
      primary: source.feedURL,
      platform: source.platform,
      alternateURLs: alternates
    )
    guard !candidates.isEmpty else { throw NetworkError.invalidURL }

    var lastError: Error = NetworkError.invalidURL
    for url in candidates {
      do {
        let data = try await networkClient.fetchData(from: url, platform: source.platform)
        if FeedJunkFilter.looksLikeBlockedPlaceholderPayload(data) {
          lastError = NetworkError.noData
          continue
        }
        return (data, url.absoluteString)
      } catch {
        lastError = error
      }
    }
    throw lastError
  }

  private func candidateURLs(
    primary: String,
    platform: FeedPlatform,
    alternateURLs: [URL]
  ) -> [URL] {
    var urls = SocialFeedURLResolver.candidateURLs(for: primary, platform: platform)
    urls.append(contentsOf: alternateURLs)

    var seen = Set<String>()
    return urls.compactMap { url in
      guard seen.insert(url.absoluteString).inserted else { return nil }
      return url
    }
  }
}
