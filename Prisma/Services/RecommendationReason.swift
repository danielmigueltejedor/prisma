import Foundation

enum RecommendationReason: Equatable {
  case favoriteSource
  case savedTopic
  case recentInterest
  case exploring
  case fresh

  var localized: String {
    switch self {
    case .favoriteSource:
      String(localized: "foryou.reason.favoriteSource")
    case .savedTopic:
      String(localized: "foryou.reason.savedTopic")
    case .recentInterest:
      String(localized: "foryou.reason.recentInterest")
    case .exploring:
      String(localized: "foryou.reason.exploring")
    case .fresh:
      String(localized: "foryou.reason.fresh")
    }
  }
}

enum RecommendationReasonBuilder {
  static func reason(
    for article: Article,
    rankIndex: Int,
    favoriteSourceIds: Set<UUID>,
    savedCategoryNames: Set<String>,
    interest: ReadingInterestProfile
  ) -> RecommendationReason? {
    if favoriteSourceIds.contains(article.sourceId) {
      return .favoriteSource
    }

    let loweredCategories = Set(article.categoryNames.map { $0.lowercased() })
    if !loweredCategories.intersection(savedCategoryNames.map { $0.lowercased() }).isEmpty {
      return .savedTopic
    }

    if !interest.isEmpty {
      let sourceWeight = interest.sourceWeights[article.sourceId] ?? 0
      let categoryWeight = loweredCategories
        .compactMap { interest.categoryWeights[$0] }
        .max() ?? 0
      if sourceWeight > 0.4 || categoryWeight > 0.35 {
        return .recentInterest
      }
    }

    if interest.strength >= 0.25, [5, 11, 18].contains(rankIndex) {
      return .exploring
    }

    if let published = article.publishedAt,
       Date().timeIntervalSince(published) < 6 * 3_600,
       !article.isRead {
      return .fresh
    }

    return nil
  }
}
