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
    Resume este artículo de \(article.sourceName) en español claro y factual.
    Reglas:
    - Solo hechos del texto, sin opinión ni relleno.
    - 4-6 viñetas breves o 2 párrafos cortos.
    - Incluye cifras, lugares y actores si aparecen.

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
    let groups = Array(ArticleTopicMatcher.cluster(Array(articles.prefix(15)), minimumScore: 10).prefix(3))
    guard !groups.isEmpty else { return [] }

    if groups.count == 1 {
      return [try await synthesizeCluster(for: groups[0])]
    }

    var blocks: [String] = []
    for (index, group) in groups.enumerated() {
      let sources = Array(Set(group.map(\.sourceName))).sorted()
      let titles = group.prefix(3).map(\.title).joined(separator: " | ")
      blocks.append("GRUPO \(index + 1) [\(sources.joined(separator: ", "))]: \(titles)")
    }

    let prompt = """
    Estos grupos de titulares cubren temas distintos del día.
    Para CADA grupo escribe un titular unificado y un párrafo de síntesis en español.
    Usa exactamente este formato por grupo:

    GRUPO N
    TITULAR: ...
    SÍNTESIS: ...

    \(blocks.joined(separator: "\n\n"))
    """

    let session = LanguageModelSession(model: generalModel)
    let synthesis = try await session.respond(to: prompt).content
    let parsed = Self.parseBatchedClusterResponse(synthesis, groups: groups)
    if !parsed.isEmpty { return parsed }

    var fallback: [ClusterDTO] = []
    for group in groups {
      fallback.append(try await synthesizeCluster(for: group, session: session))
    }
    return fallback
  }

  private func synthesizeCluster(
    for group: [Article],
    session: LanguageModelSession? = nil
  ) async throws -> ClusterDTO {
    let sources = Array(Set(group.map(\.sourceName))).sorted()
    let titles = group.prefix(4).map(\.title).joined(separator: "\n- ")
    let prompt = """
    Estas noticias de distintas fuentes (\(sources.joined(separator: ", "))) parecen cubrir el mismo tema:
    - \(titles)

    Escribe un titular unificado y un párrafo de síntesis en español.
    """
    let activeSession = session ?? LanguageModelSession(model: generalModel)
    let synthesis = try await activeSession.respond(to: prompt).content
    let headline = synthesis.components(separatedBy: "\n").first ?? "Tema del día"

    return ClusterDTO(
      id: UUID().uuidString,
      title: headline,
      summary: synthesis,
      articleIds: group.map(\.id),
      comparisonNote: nil,
      synthesizedStory: synthesis,
      sourceNames: sources
    )
  }

  private static func parseBatchedClusterResponse(_ text: String, groups: [[Article]]) -> [ClusterDTO] {
    var clusters: [ClusterDTO] = []
    clusters.reserveCapacity(groups.count)

    for (index, group) in groups.enumerated() {
      let marker = "GRUPO \(index + 1)"
      guard let range = text.range(of: marker, options: .caseInsensitive) else { continue }

      let slice: String
      if index + 1 < groups.count,
         let nextRange = text.range(of: "GRUPO \(index + 2)", options: .caseInsensitive, range: range.upperBound ..< text.endIndex)
      {
        slice = String(text[range.lowerBound ..< nextRange.lowerBound])
      } else {
        slice = String(text[range.lowerBound...])
      }

      let title = value(in: slice, key: "TITULAR") ?? group.first?.title ?? "Tema del día"
      let summary = value(in: slice, key: "SÍNTESIS") ?? slice
      let sources = Array(Set(group.map(\.sourceName))).sorted()

      clusters.append(
        ClusterDTO(
          id: UUID().uuidString,
          title: title,
          summary: summary,
          articleIds: group.map(\.id),
          comparisonNote: nil,
          synthesizedStory: summary,
          sourceNames: sources
        )
      )
    }

    return clusters
  }

  private static func value(in text: String, key: String) -> String? {
    guard let range = text.range(of: "\(key):", options: .caseInsensitive) else { return nil }
    let remainder = text[range.upperBound...]
    let line = remainder.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first
    let cleaned = line?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return cleaned.isEmpty ? nil : cleaned
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

  func filterSameStoryArticleIDs(anchor: Article, candidates: [Article]) async throws -> [String] {
    try ensureAvailable()
    guard !candidates.isEmpty else { return [] }

    let anchorExcerpt = String(
      (HTMLSanitizer.stripHTML(anchor.content ?? anchor.summary) ?? anchor.title).prefix(500)
    )
    let lines = candidates.prefix(8).map { article in
      let excerpt = String((HTMLSanitizer.stripHTML(article.summary ?? article.content) ?? article.title).prefix(280))
      return "\(article.id) | \(article.sourceName) | \(article.title) | \(excerpt)"
    }

    let prompt = """
    Artículo principal (ID: \(anchor.id)):
    \(anchor.title)
    \(anchorExcerpt)

    Candidatos de otras fuentes (algunos pueden ser NOTICIAS DISTINTAS aunque compartan tema):
    \(lines.joined(separator: "\n"))

    Devuelve SOLO los IDs de candidatos que cubren el MISMO hecho noticioso concreto que el principal \
    (mismo incidente, decisión, persona+acción o anuncio). Compartir ámbito general NO basta.
    Si un candidato habla de otra cosa, exclúyelo aunque aparezca en agregadores como Meneame.
    Si ninguno coincide, responde exactamente: NONE
    Un ID por línea, sin otro texto.
    """
    let session = LanguageModelSession(model: generalModel)
    let response = try await session.respond(to: prompt).content
    let validIDs = Set(candidates.map(\.id))
    return SameStoryResponseParser.parseVerifiedIDs(response, validIDs: validIDs)
  }

  func compareSameStory(anchor: Article, relatedArticles: [Article]) async throws -> SameStoryComparisonDTO {
    try ensureAvailable()
    guard !relatedArticles.isEmpty else { throw AIServiceError.notAvailable }

    var blocks: [String] = []
    let anchorExcerpt = HTMLSanitizer.stripHTML(anchor.content ?? anchor.summary) ?? anchor.title
    blocks.append("ID: \(anchor.id) | [\(anchor.sourceName)] \(anchor.title)\n\(String(anchorExcerpt.prefix(900)))")

    for article in relatedArticles.prefix(4) {
      let excerpt = HTMLSanitizer.stripHTML(article.content ?? article.summary) ?? article.title
      blocks.append("ID: \(article.id) | [\(article.sourceName)] \(article.title)\n\(String(excerpt.prefix(900)))")
    }

    let prompt = """
    Todas estas fuentes cubren la MISMA noticia concreta. Responde en español con esta estructura exacta:

    HECHOS COMPARTIDOS:
    (síntesis de lo que coincide entre fuentes)

    DIFERENCIAS POR FUENTE:
    (para cada fuente: matiz, dato extra u omisión relevante)

    NOTICIA UNIFICADA:
    (relato único y completo que integra todos los datos verificados de todas las fuentes)

    LECTURA RÁPIDA:
    (1-2 frases sobre qué fuente aporta más y qué conviene contrastar)

    \(blocks.joined(separator: "\n\n"))
    """
    let session = LanguageModelSession(model: generalModel)
    let response = try await session.respond(to: prompt).content
    return SameStoryResponseParser.parse(response)
  }

  func rankSimilarArticles(anchor: Article, candidates: [Article], limit: Int) async throws -> [String] {
    try ensureAvailable()
    guard !candidates.isEmpty else { return [] }

    let shortlist = Array(candidates.prefix(24))
    let lines = shortlist.map { article in
      let excerpt = String((HTMLSanitizer.stripHTML(article.summary) ?? article.title).prefix(120))
      return "\(article.id) | \(article.sourceName) | \(article.title) | \(excerpt)"
    }

    let prompt = """
    El lector está leyendo este artículo:
    \(anchor.title)
    Fuente: \(anchor.sourceName)

    De la lista siguiente, elige hasta \(limit) artículos TEMÁTICAMENTE relacionados \
    (mismo ámbito, intereses o subtema), pero NO la misma noticia exacta ya cubierta por otra fuente.
    Responde SOLO con los IDs elegidos, uno por línea, sin texto extra.

    CANDIDATOS:
    \(lines.joined(separator: "\n"))
    """

    let session = LanguageModelSession(model: generalModel)
    let response = try await session.respond(to: prompt).content
    let validIDs = Set(shortlist.map(\.id))
    return response
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { validIDs.contains($0) }
      .prefix(limit)
      .map { $0 }
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

  func translateArticle(
    _ article: Article,
    to targetLanguageCode: String,
    sourceLanguage: String?
  ) async throws -> TranslationDTO {
    try ensureAvailable()
    let body = articleBody(for: article)
    let languageName = ReadingLanguage.displayName(for: targetLanguageCode)
    let prompt = """
    Translate this text to \(languageName) with maximum fidelity.
    This is a strict translation task, not a rewriting task.
    Rules:
    - Do NOT summarize.
    - Do NOT paraphrase or reinterpret.
    - Preserve meaning, tone, and point of view (first person stays first person).
    - Keep names, numbers, quotes, slang, and uncertainty markers as faithfully as possible.
    - Keep paragraph order.
    - If a fragment is ambiguous, translate literally rather than inventing context.
    Use exactly this format:

    TITLE: [translated headline]
    BODY:
    [translated article as plain text paragraphs]

    TITLE: \(article.title)

    BODY:
    \(body.prefix(8000))
  """
    let session = LanguageModelSession(model: generalModel)
    let response = try await session.respond(to: prompt).content
    let parsed = TranslationResponseParser.parse(response, fallbackTitle: article.title)
    return TranslationDTO(
      articleId: article.id,
      targetLanguageCode: targetLanguageCode,
      sourceLanguageCode: sourceLanguage,
      translatedTitle: parsed.title.trimmingCharacters(in: .whitespacesAndNewlines),
      translatedBody: parsed.body.trimmingCharacters(in: .whitespacesAndNewlines),
      provider: "apple-intelligence-on-device",
      generatedAt: .now
    )
  }

  func translatePlainTexts(
    _ texts: [String],
    to targetLanguageCode: String,
    sourceLanguage: String?
  ) async throws -> [String] {
    try ensureAvailable()
    guard !texts.isEmpty else { return [] }

    let languageName = ReadingLanguage.displayName(for: targetLanguageCode)
    let numbered = texts.enumerated().map { index, text in
      "\(index + 1). \(text)"
    }.joined(separator: "\n")

    let prompt = """
    Translate each numbered item below to \(languageName).
    Rules:
    - Keep the same numbering (1., 2., 3., ...).
    - One translated item per numbered line.
    - Preserve Reddit markdown, links, and tone.
    - Do not merge or skip items.

    \(numbered.prefix(12_000))
    """
    let session = LanguageModelSession(model: generalModel)
    let response = try await session.respond(to: prompt).content
    let parsed = PlainTextBatchTranslationParser.parse(response, expectedCount: texts.count)
    if parsed.allSatisfy(\.isEmpty) {
      throw AIServiceError.notAvailable
    }
    return parsed
  }

  private func ensureAvailable() throws {
    guard Self.isSupported else { throw AIServiceError.notAvailable }
  }

  private func articleBody(for article: Article) -> String {
    HTMLSanitizer.stripHTML(article.content ?? article.summary) ?? article.title
  }
}
#endif
