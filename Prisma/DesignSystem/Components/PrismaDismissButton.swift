import SwiftUI

private enum DismissButtonMetrics {
  static let iconSize: CGFloat = 17
  static let hitSize: CGFloat = 44
}

/// Botón de cierre flotante con liquid glass (sin fondo sólido del toolbar del sistema).
struct PrismaDismissButton: View {
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      dismissGlyph
    }
    .buttonStyle(.plain)
    .accessibilityLabel(String(localized: "action.close"))
  }

  @ViewBuilder
  private var dismissGlyph: some View {
    if #available(iOS 26.0, *) {
      Image(systemName: "xmark")
        .font(.system(size: DismissButtonMetrics.iconSize, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: DismissButtonMetrics.hitSize, height: DismissButtonMetrics.hitSize)
        .contentShape(Circle())
        .glassEffect(.regular.interactive(), in: .circle)
    } else {
      Image(systemName: "xmark")
        .font(.system(size: DismissButtonMetrics.iconSize, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: DismissButtonMetrics.hitSize, height: DismissButtonMetrics.hitSize)
        .contentShape(Circle())
        .prismaGlass(cornerRadius: DismissButtonMetrics.hitSize / 2)
    }
  }
}
