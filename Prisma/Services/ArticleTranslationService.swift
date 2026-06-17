import Foundation

@MainActor
final class ArticleTranslationService {
  private let translationRepository: ArticleTranslationRepository
  private let preferenceRepository: PreferenceRepository
  private let aiService: AIService
  private var inFlightTasks: [String: Task<String?, Never>] = [:]

  init(
    translationRepository: ArticleTranslationRepository,
    preferenceRepository: PreferenceRepository,
    aiService: AIService
  ) {
    self.translationRepository = translationRepository
    self.preferenceRepository = preferenceRepository
    self.aiService = aiService
  }

  var targetLanguageCode: String {
    let prefs = try? preferenceRepository.getOrCreate()
    return ReadingLanguage.resolved(preferences: prefs)
  }

  func cachedTranslation(for article: Article) -> ArticleTranslation? {
    try? translationRepository.find(
      articleId: article.id,
      targetLanguageCode: targetLanguageCode
    )
  }

  func needsTranslation(for article: Article) -> Bool {
    ArticleLanguageDetector.needsTranslation(
      article: article,
      targetLanguageCode: targetLanguageCode
    )
  }

  func cachedTranslations(for articles: [Article]) -> [String: ArticleTranslation] {
    let ids = articles.map(\.id)
    guard let records = try? translationRepository.findAll(
      articleIds: ids,
      targetLanguageCode: targetLanguageCode
    ) else {
      return [:]
    }
    return Dictionary(uniqueKeysWithValues: records.map { ($0.articleId, $0) })
  }

  func previewDisplay(
    for article: Article,
    cache: [String: ArticleTranslation]
  ) -> ArticlePreviewText {
    if needsTranslation(for: article), let translation = cache[article.id] {
      return ArticlePreviewText(
        title: translation.translatedTitle,
        summary: previewSummary(from: translation, fallback: article.displaySummary)
      )
    }
    return ArticlePreviewText(title: article.title, summary: article.displaySummary)
  }

  @discardableResult
  func ensureTranslation(for article: Article) async -> ArticleTranslation? {
    guard needsTranslation(for: article) else { return nil }
    guard canTranslate else { return nil }

    let key = ArticleTranslation.cacheKey(
      articleId: article.id,
      targetLanguageCode: targetLanguageCode
    )

    if let cached = try? translationRepository.find(
      articleId: article.id,
      targetLanguageCode: targetLanguageCode
    ) {
      return cached
    }

    if let existing = inFlightTasks[key] {
      _ = await existing.value
      return try? translationRepository.find(
        articleId: article.id,
        targetLanguageCode: targetLanguageCode
      )
    }

    let articleId = article.id
    let language = targetLanguageCode
    let task = Task { @MainActor () -> String? in
      do {
        let sourceLanguage = ArticleLanguageDetector.detectLanguageCode(for: article)
        let dto = try await aiService.translateArticle(
          article,
          to: language,
          sourceLanguage: sourceLanguage
        )
        _ = try translationRepository.save(dto)
        return articleId
      } catch {
        return nil
      }
    }

    inFlightTasks[key] = task
    defer { inFlightTasks[key] = nil }
    guard await task.value != nil else { return nil }
    return try? translationRepository.find(
      articleId: articleId,
      targetLanguageCode: language
    )
  }

  private var canTranslate: Bool {
    AIServiceFactory.hasFreeOnDeviceAI
  }

  private func previewSummary(
    from translation: ArticleTranslation,
    fallback: String?
  ) -> String? {
    let body = translation.translatedBody.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty else { return fallback }
    let paragraph = body.components(separatedBy: "\n\n").first ?? body
    let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return fallback }
    if trimmed.count <= 180 { return trimmed }
    return String(trimmed.prefix(177)) + "…"
  }
}
