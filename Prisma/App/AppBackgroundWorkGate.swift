import Foundation

/// Pausa prefetch/IA/red pesada mientras el lector, la cascada Para ti u otra UI crítica está activa.
@MainActor
@Observable
final class AppBackgroundWorkGate {
  private(set) var isReaderActive = false

  var shouldDeferHeavyWork: Bool { isReaderActive }

  func setReaderActive(_ active: Bool) {
    isReaderActive = active
  }
}
