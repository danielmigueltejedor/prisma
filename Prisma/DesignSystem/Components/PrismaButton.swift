import SwiftUI

enum PrismaButtonStyle {
  case primary
  case secondary
  case ghost
}

struct PrismaButton: View {
  let title: String
  var style: PrismaButtonStyle = .primary
  var isLoading: Bool = false
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: PrismaSpacing.xs) {
        if isLoading {
          ProgressView()
            .tint(foregroundColor)
        }
        Text(title)
          .font(PrismaTypography.headline())
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, PrismaSpacing.sm + 2)
      .padding(.horizontal, PrismaSpacing.md)
      .background(background)
      .foregroundStyle(foregroundColor)
      .clipShape(RoundedRectangle(cornerRadius: PrismaRadius.md, style: .continuous))
      .overlay {
        if style == .secondary {
          RoundedRectangle(cornerRadius: PrismaRadius.md, style: .continuous)
            .strokeBorder(PrismaColors.separator, lineWidth: 1)
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(isLoading)
    .accessibilityAddTraits(.isButton)
  }

  @ViewBuilder
  private var background: some View {
    switch style {
    case .primary:
      PrismaColors.accentFallback
    case .secondary:
      PrismaColors.surface
    case .ghost:
      Color.clear
    }
  }

  private var foregroundColor: Color {
    switch style {
    case .primary:
      .white
    case .secondary, .ghost:
      PrismaColors.textPrimary
    }
  }
}
