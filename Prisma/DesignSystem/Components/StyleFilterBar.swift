import SwiftUI

struct StyleFilterBar: View {
  let filters: [String]
  @Binding var selection: String

  /// Margen interno para que el glass interactivo no se recorte en los bordes.
  private let glassBleed: CGFloat = 10
  private let horizontalInset: CGFloat = PrismaSpacing.md

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: PrismaSpacing.xs) {
        ForEach(filters, id: \.self) { filter in
          filterChip(filter)
        }
      }
      .padding(.horizontal, horizontalInset)
      .padding(.vertical, glassBleed)
    }
    .scrollClipDisabled()
    .padding(.horizontal, -horizontalInset)
  }

  @ViewBuilder
  private func filterChip(_ filter: String) -> some View {
    let isSelected = selection == filter
    Button(filter) {
      selection = filter
    }
    .font(PrismaTypography.caption(.semibold))
    .padding(.horizontal, PrismaSpacing.sm)
    .padding(.vertical, PrismaSpacing.xs)
    .foregroundStyle(
      isSelected ? PrismaColors.accentFallback : PrismaColors.textSecondary
    )
    .modifier(LiquidGlassChipModifier(isSelected: isSelected))
  }
}

private struct LiquidGlassChipModifier: ViewModifier {
  let isSelected: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content
        .glassEffect(
          isSelected
            ? .regular.tint(PrismaColors.accentFallback.opacity(0.35)).interactive()
            : .regular.interactive(),
          in: .capsule
        )
    } else {
      content
        .prismaGlass(cornerRadius: 999)
        .overlay {
          if isSelected {
            Capsule()
              .stroke(PrismaColors.accentFallback.opacity(0.35), lineWidth: 1)
          }
        }
    }
  }
}
