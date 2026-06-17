import AVFoundation
import Combine
import Foundation

struct ArticleSpeechContent: Sendable, Equatable {
  let id: String
  let title: String
  let sourceName: String
  let body: String

  init(article: Article) {
    id = article.id
    title = article.title
    sourceName = article.sourceName
    if let plain = article.plainSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !plain.isEmpty {
      body = plain
    } else if let summary = HTMLSanitizer.stripHTML(article.summary ?? article.content ?? "") {
      body = summary
    } else {
      body = article.title
    }
  }
}

@MainActor
final class ArticleSpeechReader: NSObject, ObservableObject {
  static let shared = ArticleSpeechReader()

  @Published private(set) var isSpeaking = false
  @Published private(set) var currentArticleID: String?

  private let synthesizer = AVSpeechSynthesizer()
  private var queuedArticles: [ArticleSpeechContent] = []
  private var queueIndex = 0

  override private init() {
    super.init()
    synthesizer.delegate = self
  }

  func speak(_ content: ArticleSpeechContent) {
    stop()
    queuedArticles = [content]
    queueIndex = 0
    speakCurrent()
  }

  func speakQueue(_ contents: [ArticleSpeechContent]) {
    stop()
    queuedArticles = contents
    queueIndex = 0
    guard !queuedArticles.isEmpty else { return }
    speakCurrent()
  }

  func toggleSpeech(for content: ArticleSpeechContent) {
    if isSpeaking, currentArticleID == content.id {
      stop()
    } else {
      speak(content)
    }
  }

  func stop() {
    synthesizer.stopSpeaking(at: .immediate)
    queuedArticles = []
    queueIndex = 0
    isSpeaking = false
    currentArticleID = nil
  }

  private func speakCurrent() {
    guard queueIndex < queuedArticles.count else {
      stop()
      return
    }

    let content = queuedArticles[queueIndex]
    currentArticleID = content.id
    isSpeaking = true

    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
    try? session.setActive(true)

    let intro = "\(content.sourceName). \(content.title)."
    let text = content.body.count > 40 ? "\(intro) \(content.body)" : intro

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: preferredLanguageCode)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
    utterance.preUtteranceDelay = 0.05
    synthesizer.speak(utterance)
  }

  private var preferredLanguageCode: String {
    let prefs = Locale.preferredLanguages.first ?? "es-ES"
    if prefs.hasPrefix("es") { return "es-ES" }
    if prefs.hasPrefix("en") { return "en-US" }
    return prefs
  }
}

extension ArticleSpeechReader: AVSpeechSynthesizerDelegate {
  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    Task { @MainActor in
      queueIndex += 1
      if queueIndex < queuedArticles.count {
        speakCurrent()
      } else {
        isSpeaking = false
        currentArticleID = nil
        queuedArticles = []
        queueIndex = 0
      }
    }
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    Task { @MainActor in
      isSpeaking = false
      currentArticleID = nil
      queuedArticles = []
      queueIndex = 0
    }
  }
}
