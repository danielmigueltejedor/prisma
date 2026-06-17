import Foundation

struct PersistedAICache: Codable {
  let signature: String
  let clusters: [ClusterDTO]
  let briefing: DailyBriefingDTO?
  let generatedAt: Date
}

enum AIContentCacheStore {
  private static let refreshInterval: TimeInterval = 2 * 60 * 60

  static func load() -> PersistedAICache? {
    guard let data = try? Data(contentsOf: cacheURL),
          let cache = try? JSONDecoder().decode(PersistedAICache.self, from: data)
    else {
      return nil
    }
    return cache
  }

  static func save(_ cache: PersistedAICache) {
    guard let data = try? JSONEncoder().encode(cache) else { return }
    try? data.write(to: cacheURL, options: .atomic)
  }

  static func shouldRefresh(cache: PersistedAICache, signature: String) -> Bool {
    if cache.signature != signature { return true }
    return Date().timeIntervalSince(cache.generatedAt) > refreshInterval
  }

  static func clear() {
    try? FileManager.default.removeItem(at: cacheURL)
  }

  private static var cacheURL: URL {
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      .appendingPathComponent("Prisma", isDirectory: true)
    if !FileManager.default.fileExists(atPath: directory.path) {
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    return directory.appendingPathComponent("ai-content-cache.json")
  }
}
