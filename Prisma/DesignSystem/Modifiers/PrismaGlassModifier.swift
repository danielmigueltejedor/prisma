import SwiftUI

struct PrismaGlassModifier: ViewModifier {
  var cornerRadius: CGFloat = PrismaRadius.lg
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .background {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(.ultraThinMaterial)
          .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .strokeBorder(
                Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08),
                lineWidth: 0.5
              )
          }
      }
      .shadow(
        color: .black.opacity(colorScheme == .dark ? 0.35 : 0.06),
        radius: colorScheme == .dark ? 16 : 12,
        x: 0,
        y: colorScheme == .dark ? 6 : 4
      )
  }
}

extension View {
  func prismaGlass(cornerRadius: CGFloat = PrismaRadius.lg) -> some View {
    modifier(PrismaGlassModifier(cornerRadius: cornerRadius))
  }
}
