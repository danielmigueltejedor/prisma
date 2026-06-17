import SwiftUI

struct SavedLibraryFilterBar: View {
  @Binding var selection: SavedViewModel.SavedFilter

  private let filters = SavedViewModel.SavedFilter.allCases

  var body: some View {
    HStack(spacing: PrismaSpacing.xs) {
      ForEach(filters) { filter in
        filterChip(filter)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func filterChip(_ filter: SavedViewModel.SavedFilter) -> some View {
    let isSelected = selection == filter
    Button {
      selection = filter
    } label: {
      HStack(spacing: PrismaSpacing.xxs) {
        Image(systemName: filter == .saved ? "bookmark.fill" : "heart.fill")
          .font(.system(size: 12, weight: .semibold))
        Text(filter.title)
          .font(PrismaTypography.caption(.semibold))
      }
      .padding(.horizontal, PrismaSpacing.sm)
      .padding(.vertical, PrismaSpacing.xs)
      .foregroundStyle(
        isSelected ? PrismaColors.accentFallback : PrismaColors.textSecondary
      )
    }
    .buttonStyle(.plain)
    .modifier(SavedLibraryChipGlass(isSelected: isSelected))
  }
}

private struct SavedLibraryChipGlass: ViewModifier {
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
