import Foundation

/// Future implementation that calls the Prisma+ backend API.
struct RemoteAIService: AIService {
  let baseURL: URL
  let networkClient: NetworkClient
  let apiToken: String?

  func summarizeArticle(_ article: Article) async throws -> SummaryDTO {
    try await post(path: "/v1/summarize", body: ArticlePayload(article: article))
  }

  func classifyArticle(_ article: Article) async throws -> [String] {
    struct Response: Decodable { let categories: [String] }
    let response: Response = try await post(path: "/v1/classify", body: ArticlePayload(article: article))
    return response.categories
  }

  func clusterArticles(_ articles: [Article]) async throws -> [ClusterDTO] {
    struct Response: Decodable { let clusters: [ClusterDTO] }
    let response: Response = try await post(
      path: "/v1/cluster",
      body: ArticlesPayload(articles: articles.map(ArticlePayload.init))
    )
    return response.clusters
  }

  func compareSources(cluster: ClusterDTO, articles: [Article]) async throws -> String {
    struct Response: Decodable { let comparison: String }
    struct Body: Encodable {
      let cluster: ClusterDTO
      let articles: [ArticlePayload]
    }
    let response: Response = try await post(
      path: "/v1/compare",
      body: Body(cluster: cluster, articles: articles.map(ArticlePayload.init))
    )
    return response.comparison
  }

  func generateDailyBriefing(articles: [Article], preferences: UserPreference) async throws -> DailyBriefingDTO {
    struct Body: Encodable {
      let articles: [ArticlePayload]
      let blockedKeywords: [String]
    }
    return try await post(
      path: "/v1/briefing",
      body: Body(articles: articles.map(ArticlePayload.init), blockedKeywords: preferences.blockedKeywords)
    )
  }

  func explainContext(article: Article) async throws -> ContextExplanationDTO {
    try await post(path: "/v1/context", body: ArticlePayload(article: article))
  }

  private func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
    guard let url = URL(string: path, relativeTo: baseURL) else {
      throw NetworkError.invalidURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let apiToken {
      request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await networkClient.session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
      throw AIServiceError.backendUnavailable
    }
    return try JSONDecoder().decode(T.self, from: data)
  }
}

private struct ArticlePayload: Encodable {
  let id: String
  let title: String
  let url: String
  let sourceName: String
  let summary: String?
  let author: String?

  init(article: Article) {
    id = article.id
    title = article.title
    url = article.url
    sourceName = article.sourceName
    summary = HTMLSanitizer.stripHTML(article.summary ?? article.content)
    author = article.authorName
  }
}

private struct ArticlesPayload: Encodable {
  let articles: [ArticlePayload]
}
