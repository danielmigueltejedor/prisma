import SwiftUI

private enum ReaderToolbarMetrics {
  static let iconSize: CGFloat = 20
  static let hitSize: CGFloat = 44
}

/// Agrupa acciones del lector en una cápsula liquid glass (fondo no interactivo).
struct LiquidGlassToolbarGroup<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    HStack(spacing: PrismaSpacing.xxs) {
      content()
    }
    .padding(.horizontal, PrismaSpacing.xs)
    .padding(.vertical, PrismaSpacing.xxs)
    .modifier(ReaderToolbarCapsuleBackground())
  }
}

/// Botón táctil del chip del lector (área mínima 44×44).
struct ReaderToolbarIconButton: View {
  let systemName: String
  var isActive = false
  let accessibilityLabel: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: ReaderToolbarMetrics.iconSize, weight: .semibold))
        .foregroundStyle(isActive ? PrismaColors.accentFallback : .primary)
        .frame(width: ReaderToolbarMetrics.hitSize, height: ReaderToolbarMetrics.hitSize)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }
}

private struct ReaderToolbarCapsuleBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content
        .glassEffect(.regular, in: .capsule)
    } else {
      content
        .prismaGlass(cornerRadius: 999)
    }
  }
}
