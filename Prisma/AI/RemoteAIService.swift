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

  func filterSameStoryArticleIDs(anchor: Article, candidates: [Article]) async throws -> [String] {
    struct Response: Decodable { let articleIds: [String] }
    struct Body: Encodable {
      let anchor: ArticlePayload
      let candidates: [ArticlePayload]
    }
    let response: Response = try await post(
      path: "/v1/filter-same-story",
      body: Body(anchor: ArticlePayload(article: anchor), candidates: candidates.map(ArticlePayload.init))
    )
    return response.articleIds
  }

  func compareSameStory(anchor: Article, relatedArticles: [Article]) async throws -> SameStoryComparisonDTO {
    struct Response: Decodable {
      let comparison: String
      let unifiedStory: String?
    }
    struct Body: Encodable {
      let anchor: ArticlePayload
      let related: [ArticlePayload]
    }
    let response: Response = try await post(
      path: "/v1/compare-story",
      body: Body(anchor: ArticlePayload(article: anchor), related: relatedArticles.map(ArticlePayload.init))
    )
    return SameStoryComparisonDTO(
      comparisonText: response.comparison,
      unifiedStory: response.unifiedStory ?? response.comparison
    )
  }

  func rankSimilarArticles(anchor: Article, candidates: [Article], limit: Int) async throws -> [String] {
    struct Response: Decodable { let articleIds: [String] }
    struct Body: Encodable {
      let anchor: ArticlePayload
      let candidates: [ArticlePayload]
      let limit: Int
    }
    let response: Response = try await post(
      path: "/v1/similar",
      body: Body(
        anchor: ArticlePayload(article: anchor),
        candidates: candidates.map(ArticlePayload.init),
        limit: limit
      )
    )
    return response.articleIds
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

  func translateArticle(
    _ article: Article,
    to targetLanguageCode: String,
    sourceLanguage: String?
  ) async throws -> TranslationDTO {
    struct Body: Encodable {
      let article: ArticlePayload
      let targetLanguageCode: String
      let sourceLanguageCode: String?
    }
    return try await post(
      path: "/v1/translate",
      body: Body(
        article: ArticlePayload(article: article),
        targetLanguageCode: targetLanguageCode,
        sourceLanguageCode: sourceLanguage
      )
    )
  }

  func translatePlainTexts(
    _ texts: [String],
    to targetLanguageCode: String,
    sourceLanguage: String?
  ) async throws -> [String] {
    struct Body: Encodable {
      let texts: [String]
      let targetLanguageCode: String
      let sourceLanguageCode: String?
    }
    struct Response: Decodable { let translations: [String] }
    let response: Response = try await post(
      path: "/v1/translate-texts",
      body: Body(
        texts: texts,
        targetLanguageCode: targetLanguageCode,
        sourceLanguageCode: sourceLanguage
      )
    )
    return response.translations
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
