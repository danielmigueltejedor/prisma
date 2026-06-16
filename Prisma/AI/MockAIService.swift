import Foundation

struct MockAIService: AIService {
  var simulatedDelay: Duration = .milliseconds(800)

  func summarizeArticle(_ article: Article) async throws -> SummaryDTO {
    try await Task.sleep(for: simulatedDelay)
    let body = HTMLSanitizer.stripHTML(article.content ?? article.summary) ?? article.title
    let excerpt = String(body.prefix(280))
    let summary = """
    Resumen Prisma+ (demo): \(article.title)

    \(excerpt)

    Publicado por \(article.sourceName). Con el backend conectado, Prisma+ sintetiza el contenido completo del feed y lo compara con otras fuentes.
    """
    return SummaryDTO(
      articleId: article.id,
      summary: summary,
      provider: "mock",
      generatedAt: .now
    )
  }

  func classifyArticle(_ article: Article) async throws -> [String] {
    try await Task.sleep(for: simulatedDelay)
    if article.categoryNames.isEmpty {
      return ["General"]
    }
    return article.categoryNames
  }

  func clusterArticles(_ articles: [Article]) async throws -> [ClusterDTO] {
    try await Task.sleep(for: simulatedDelay)
    guard !articles.isEmpty else { return [] }

    let groups = ArticleTopicMatcher.cluster(Array(articles.prefix(30)), minimumScore: 10)
    let multiSourceGroups = groups.filter { Set($0.map(\.sourceId)).count > 1 }

    let clusters = (multiSourceGroups.isEmpty ? groups : multiSourceGroups)
      .prefix(6)
      .map { group in
        let sources = Array(Set(group.map(\.sourceName))).sorted()
        let title = synthesizedTitle(for: group)
        let story = synthesizedStory(for: group, sources: sources)
        let comparison = comparisonPreview(for: group, sources: sources)

        return ClusterDTO(
          id: UUID().uuidString,
          title: title,
          summary: "Cobertura cruzada de \(sources.count) fuentes · \(group.count) artículos",
          articleIds: group.map(\.id),
          comparisonNote: comparison,
          synthesizedStory: story,
          sourceNames: sources
        )
      }

    return Array(clusters)
  }

  func compareSources(cluster: ClusterDTO, articles: [Article]) async throws -> String {
    try await Task.sleep(for: simulatedDelay)
    let matched = articles.filter { cluster.articleIds.contains($0.id) }
    let sources = Array(Set(matched.map(\.sourceName))).sorted()
    guard sources.count > 1 else {
      return "Se necesitan al menos dos fuentes distintas para comparar enfoques."
    }

    var lines = ["Comparación Prisma+ (demo):", ""]
    for article in matched.prefix(4) {
      let excerpt = HTMLSanitizer.stripHTML(article.summary ?? article.content) ?? article.title
      lines.append("• \(article.sourceName): \(article.title)")
      lines.append("  \(String(excerpt.prefix(160)))…")
      lines.append("")
    }
    lines.append("Las fuentes \(sources.joined(separator: ", ")) cubren «\(cluster.title)» con matices distintos de tono y énfasis.")
    return lines.joined(separator: "\n")
  }

  func generateDailyBriefing(articles: [Article], preferences: UserPreference) async throws -> DailyBriefingDTO {
    try await Task.sleep(for: simulatedDelay)
    let clusters = try await clusterArticles(Array(articles.prefix(20)))
    let sections: [BriefingSection]

    if clusters.isEmpty {
      sections = articles.prefix(5).map { article in
        BriefingSection(
          headline: article.title,
          summary: HTMLSanitizer.stripHTML(article.summary) ?? "Sin extracto disponible.",
          articleIds: [article.id]
        )
      }
    } else {
      sections = clusters.prefix(4).map { cluster in
        BriefingSection(
          headline: cluster.title,
          summary: cluster.synthesizedStory ?? cluster.summary ?? "",
          articleIds: cluster.articleIds
        )
      }
    }

    return DailyBriefingDTO(
      title: "Tu portada de hoy",
      sections: sections,
      generatedAt: .now
    )
  }

  func explainContext(article: Article) async throws -> ContextExplanationDTO {
    try await Task.sleep(for: simulatedDelay)
    return ContextExplanationDTO(
      articleId: article.id,
      explanation: """
      Contexto demo: «\(article.title)» fue publicado por \(article.sourceName). \
      Prisma+ puede explicar antecedentes, actores clave y por qué importa ahora cuando el backend esté conectado.
      """
    )
  }

  private func synthesizedTitle(for articles: [Article]) -> String {
    let keywords = articles
      .flatMap { ArticleTopicMatcher.keywords(from: $0.title) }
      .reduce(into: [String: Int]()) { counts, word in
        counts[word, default: 0] += 1
      }
      .sorted { $0.value > $1.value }
      .prefix(4)
      .map(\.key)

    if keywords.isEmpty {
      return articles.first?.title ?? "Tema del día"
    }
    return keywords.joined(separator: " ").capitalized
  }

  private func synthesizedStory(for articles: [Article], sources: [String]) -> String {
    let lead = articles.first
    let leadExcerpt = HTMLSanitizer.stripHTML(lead?.content ?? lead?.summary) ?? lead?.title ?? ""
    var paragraphs = [
      """
      Prisma+ ha detectado que \(sources.joined(separator: ", ")) están cubriendo la misma historia con enfoques complementarios.
      """,
      String(leadExcerpt.prefix(420)),
    ]

    for article in articles.dropFirst().prefix(3) {
      let excerpt = HTMLSanitizer.stripHTML(article.summary ?? article.content) ?? article.title
      paragraphs.append("\(article.sourceName) añade: \(String(excerpt.prefix(220)))…")
    }

    paragraphs.append(
      "Esta síntesis demo agrupa coberturas relacionadas. Con Prisma+ conectado al backend, el resumen se generará a partir del contenido completo de cada fuente."
    )
    return paragraphs.joined(separator: "\n\n")
  }

  private func comparisonPreview(for articles: [Article], sources: [String]) -> String {
    "Comparación entre \(sources.joined(separator: ", ")) sobre \(articles.count) artículos relacionados."
  }
}
