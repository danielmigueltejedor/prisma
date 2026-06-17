import AppIntents
import Foundation

struct ReadNewsIntent: AppIntent {
  static var title: LocalizedStringResource = "intent.readNews.title"
  static var description = IntentDescription("intent.readNews.description")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    NewsSpeechBridge.speakRecommendedArticles()
    return .result(dialog: IntentDialog(LocalizedStringResource("intent.readNews.dialog")))
  }
}

struct StopReadingNewsIntent: AppIntent {
  static var title: LocalizedStringResource = "intent.stopReading.title"
  static var description = IntentDescription("intent.stopReading.description")

  @MainActor
  func perform() async throws -> some IntentResult {
    ArticleSpeechReader.shared.stop()
    return .result()
  }
}

struct PrismaAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: ReadNewsIntent(),
      phrases: [
        "Leer noticias en \(.applicationName)",
        "Leer mis noticias con \(.applicationName)",
        "¿Qué hay de nuevo en \(.applicationName)?",
        "Read my news in \(.applicationName)",
      ],
      shortTitle: LocalizedStringResource("intent.readNews.shortTitle"),
      systemImageName: "speaker.wave.2.fill"
    )
    AppShortcut(
      intent: StopReadingNewsIntent(),
      phrases: [
        "Detener lectura en \(.applicationName)",
        "Stop reading in \(.applicationName)",
      ],
      shortTitle: LocalizedStringResource("intent.stopReading.shortTitle"),
      systemImageName: "stop.fill"
    )
  }
}
