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
      fatalError("Failed to create ModelContainer: \(error)")
    }
    dependencies = AppDependencies(modelContainer: container)
  }

  var body: some Scene {
    WindowGroup {
      RootView(dependencies: dependencies)
    }
    .modelContainer(dependencies.modelContainer)
  }
}
