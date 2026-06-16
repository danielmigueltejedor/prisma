import Foundation

struct SummaryDTO: Codable, Sendable {
  let articleId: String
  let summary: String
  let provider: String
  let generatedAt: Date
}

struct ClusterDTO: Codable, Sendable {
  let id: String
  let title: String
  let summary: String?
  let articleIds: [String]
  let comparisonNote: String?
  let synthesizedStory: String?
  let sourceNames: [String]?

  init(
    id: String,
    title: String,
    summary: String?,
    articleIds: [String],
    comparisonNote: String?,
    synthesizedStory: String? = nil,
    sourceNames: [String]? = nil
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.articleIds = articleIds
    self.comparisonNote = comparisonNote
    self.synthesizedStory = synthesizedStory
    self.sourceNames = sourceNames
  }
}

struct DailyBriefingDTO: Codable, Sendable {
  let title: String
  let sections: [BriefingSection]
  let generatedAt: Date
}

struct BriefingSection: Codable, Sendable {
  let headline: String
  let summary: String
  let articleIds: [String]
}

struct ContextExplanationDTO: Codable, Sendable {
  let articleId: String
  let explanation: String
}
