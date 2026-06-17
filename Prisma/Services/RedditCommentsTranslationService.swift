import Foundation

@MainActor
final class RedditCommentsTranslationService {
  private static let maxCommentsPerBatch = 36

  private let repository: RedditCommentsTranslationRepository
  private let translationService: ArticleTranslationService
  private let aiService: AIService
  private var inFlightTasks: [String: Task<[RedditComment], Never>] = [:]

  init(
    repository: RedditCommentsTranslationRepository,
    translationService: ArticleTranslationService,
    aiService: AIService
  ) {
    self.repository = repository
    self.translationService = translationService
    self.aiService = aiService
  }

  func translatedComments(
    for article: Article,
    comments: [RedditComment]
  ) async -> [RedditComment] {
    guard translationService.needsTranslation(for: article) else { return comments }
    guard canTranslate else { return comments }
    guard !comments.isEmpty else { return comments }

    let key = RedditCommentsTranslation.cacheKey(
      articleId: article.id,
      targetLanguageCode: translationService.targetLanguageCode
    )

    if let cached = try? repository.find(
      articleId: article.id,
      targetLanguageCode: translationService.targetLanguageCode
    ),
      let payload = repository.payload(for: cached) {
      return apply(payload.bodiesByCommentId, to: comments)
    }

    if let existing = inFlightTasks[key] {
      return await existing.value
    }

    let task = Task<[RedditComment], Never>(priority: .utility) { [weak self] in
      guard let self else { return comments }
      return await self.translateAndCache(article: article, comments: comments)
    }
    inFlightTasks[key] = task
    defer { inFlightTasks[key] = nil }
    return await task.value
  }

  private func translateAndCache(
    article: Article,
    comments: [RedditComment]
  ) async -> [RedditComment] {
    let flattened = flatten(comments).prefix(Self.maxCommentsPerBatch)
    let bodies = flattened.map(\.comment.body)
    guard !bodies.isEmpty else { return comments }

    do {
      let sourceLanguage = ArticleLanguageDetector.detectLanguageCode(for: article)
      let translated = try await aiService.translatePlainTexts(
        bodies,
        to: translationService.targetLanguageCode,
        sourceLanguage: sourceLanguage
      )
      guard translated.count == bodies.count else { return comments }

      var map: [String: String] = [:]
      for (index, item) in flattened.enumerated() {
        map[item.comment.id] = translated[index]
      }

      let payload = RedditCommentTranslationPayload(bodiesByCommentId: map)
      try? repository.save(
        articleId: article.id,
        targetLanguageCode: translationService.targetLanguageCode,
        payload: payload
      )
      return apply(map, to: comments)
    } catch {
      return comments
    }
  }

  private func apply(_ map: [String: String], to comments: [RedditComment]) -> [RedditComment] {
    comments.map { apply(map, to: $0) }
  }

  private func apply(_ map: [String: String], to comment: RedditComment) -> RedditComment {
    RedditComment(
      id: comment.id,
      author: comment.author,
      body: comment.body,
      score: comment.score,
      createdAt: comment.createdAt,
      depth: comment.depth,
      replies: comment.replies.map { apply(map, to: $0) },
      translatedBody: map[comment.id]
    )
  }

  private struct FlatComment {
    let comment: RedditComment
  }

  private func flatten(_ comments: [RedditComment]) -> [FlatComment] {
    var result: [FlatComment] = []
    func walk(_ items: [RedditComment]) {
      for comment in items {
        result.append(FlatComment(comment: comment))
        if !comment.replies.isEmpty {
          walk(comment.replies)
        }
      }
    }
    walk(comments)
    return result
  }

  private var canTranslate: Bool {
    AIServiceFactory.hasFreeOnDeviceAI
  }
}
