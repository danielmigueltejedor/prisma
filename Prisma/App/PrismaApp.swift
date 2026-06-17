import SwiftUI
import SwiftData

@main
struct PrismaApp: App {
  private let dependencies: AppDependencies

  init() {
    let container: ModelContainer
    do {
      container = try PrismaModelContainer.make()
    } catch {
      PrismaModelContainer.resetPersistentStore()
      do {
        container = try PrismaModelContainer.make()
      } catch {
        do {
          container = try PrismaModelContainer.make(inMemory: true)
        } catch {
          fatalError("Failed to create any ModelContainer: \(error)")
        }
      }
    }
    dependencies = AppDependencies(modelContainer: container)
    NewsSpeechBridge.dependencies = dependencies
  }

  var body: some Scene {
    WindowGroup {
      RootView(dependencies: dependencies)
    }
    .modelContainer(dependencies.modelContainer)
  }
}
