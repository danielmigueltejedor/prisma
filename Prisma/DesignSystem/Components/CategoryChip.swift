import SwiftUI

struct CategoryChip: View {
  let title: String
  var isSelected: Bool = false
  var action: (() -> Void)?

  var body: some View {
  Group {
    if let action {
      Button(action: action) { chipContent }
        .buttonStyle(.plain)
    } else {
      chipContent
    }
  }
  }

  private var chipContent: some View {
    Text(title)
      .font(PrismaTypography.caption())
      .padding(.horizontal, PrismaSpacing.sm)
      .padding(.vertical, PrismaSpacing.xs)
      .background(isSelected ? PrismaColors.accentFallback.opacity(0.15) : PrismaColors.elevatedSurface)
      .foregroundStyle(isSelected ? PrismaColors.accentFallback : PrismaColors.textSecondary)
      .clipShape(Capsule())
      .overlay {
        Capsule()
          .strokeBorder(PrismaColors.separator.opacity(0.5), lineWidth: 0.5)
      }
  }
}
