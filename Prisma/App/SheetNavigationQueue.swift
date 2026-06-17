import Foundation

/// Navegación diferida entre sheets (sin `asyncAfter`).
enum DeferredSheetNavigation: Equatable {
  case article(Article)
  case source(FeedSource)
  case author(String)
}
