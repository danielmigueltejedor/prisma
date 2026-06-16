import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// IA on-device vía Apple Intelligence. Gratis, sin API key, sin red.
@available(iOS 26.0, *)
struct FoundationModelsAIService: AIService {
  private let generalModel = SystemLanguageModel.default
  private let taggingModel = SystemLanguageModel(useCase: .contentTagging)

  static var isSupported: Bool {
    AppleIntelligenceAvailability.current.isReady
  }

  func summarizeArticle(_ article: Article) async throws -> SummaryDTO {
    try ensureAvailable()
    let body = articleBody(for: article)
    let prompt = """
    Eres un asistente de lectura de noticias. Resume el siguiente artículo de \(article.sourceName) \
    en español claro y neutral. Incluye los hechos principales sin opinión.

    Título: \(article.title)

    Contenido:
    \(body.prefix(6000))
    """

    let session = LanguageModelSession(model: generalModel)
    let text = try await session.respond(to: prompt).content
    return SummaryDTO(
      articleId: article.id,
      summary: text,
      provider: "apple-intelligence-on-device",
      generatedAt: .now
    )
  }

  func classifyArticle(_ article: Article) async throws -> [String] {
    try ensureAvailable()
    let prompt = """
    Clasifica este titular de noticia en 1-3 categorías cortas (ej: Política, Tecnología, Economía). \
    Responde solo con las categorías separadas por comas.

    \(article.title)
    """
    let session = LanguageModelSession(model: taggingModel)
    let text = try await session.respond(to: prompt).content
    return text
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  func clusterArticles(_ articles: [Article]) async throws -> [ClusterDTO] {
    // Clustering profundo mejor en backend; agrupación local por similitud + resumen breve
    let groups = ArticleTopicMatcher.cluster(Array(articles.prefix(15)), minimumScore: 10)
    var clusters: [ClusterDTO] = []

    for group in groups.prefix(5) {
      let sources = Array(Set(group.map(\.sourceName))).sorted()
      let titles = group.prefix(4).map(\.title).joined(separator: "\n- ")
      let prompt = """
      Estas noticias de distintas fuentes (\(sources.joined(separator: ", "))) parecen cubrir el mismo tema:
      - \(titles)

      Escribe un titular unificado y un párrafo de síntesis en español.
      """
      let session = LanguageModelSession(model: generalModel)
      let synthesis = try await session.respond(to: prompt).content
      let headline = synthesis.components(separatedBy: "\n").first ?? "Tema del día"

      clusters.append(
        ClusterDTO(
          id: UUID().uuidString,
          title: headline,
          summary: synthesis,
          articleIds: group.map(\.id),
          comparisonNote: nil,
          synthesizedStory: synthesis,
          sourceNames: sources
        )
      )
    }
    return clusters
  }

  func compareSources(cluster: ClusterDTO, articles: [Article]) async throws -> String {
    try ensureAvailable()
    let matched = articles.filter { cluster.articleIds.contains($0.id) }
    let sources = Set(matched.map(\.sourceName))
    guard sources.count > 1 else {
      throw AIServiceError.notAvailable
    }

    var blocks: [String] = []
    for article in matched.prefix(4) {
      let excerpt = HTMLSanitizer.stripHTML(article.summary ?? article.content) ?? article.title
      blocks.append("[\(article.sourceName)] \(article.title)\n\(String(excerpt.prefix(800)))")
    }

    let prompt = """
    Compara cómo cubren estas fuentes el mismo tema. Señala coincidencias y diferencias de enfoque. \
    Responde en español.

    \(blocks.joined(separator: "\n\n"))
    """
    let session = LanguageModelSession(model: generalModel)
    return try await session.respond(to: prompt).content
  }

  func generateDailyBriefing(articles: [Article], preferences: UserPreference) async throws -> DailyBriefingDTO {
    let clusters = try await clusterArticles(Array(articles.prefix(12)))
    let sections = clusters.prefix(4).map { cluster in
      BriefingSection(
        headline: cluster.title,
        summary: cluster.synthesizedStory ?? cluster.summary ?? "",
        articleIds: cluster.articleIds
      )
    }
    return DailyBriefingDTO(
      title: "Tu portada de hoy",
      sections: Array(sections),
      generatedAt: .now
    )
  }

  func explainContext(article: Article) async throws -> ContextExplanationDTO {
    try ensureAvailable()
    let body = articleBody(for: article)
    let prompt = """
    Explica el contexto de esta noticia para alguien que no sigue el tema: antecedentes, \
    actores clave y por qué importa ahora. Español, tono claro.

    Título: \(article.title)
    Fuente: \(article.sourceName)
    Texto: \(body.prefix(4000))
    """
    let session = LanguageModelSession(model: generalModel)
    let text = try await session.respond(to: prompt).content
    return ContextExplanationDTO(articleId: article.id, explanation: text)
  }

  private func ensureAvailable() throws {
    guard Self.isSupported else { throw AIServiceError.notAvailable }
  }

  private func articleBody(for article: Article) -> String {
    HTMLSanitizer.stripHTML(article.content ?? article.summary) ?? article.title
  }
}
#endif
