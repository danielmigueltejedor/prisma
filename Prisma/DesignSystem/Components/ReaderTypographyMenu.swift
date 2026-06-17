import SwiftUI

struct ReaderTypographyMenu: View {
  @Bindable var viewModel: ArticleReaderViewModel

  private static let sizeSteps: [Double] = [0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6]

  var body: some View {
    Menu {
      Section(String(localized: "reader.typography.font")) {
        Picker(
          String(localized: "reader.typography.font"),
          selection: fontFamilyBinding
        ) {
          ForEach(ReaderFontFamily.allCases) { family in
            Text(family.displayName).tag(family)
          }
        }
      }

      Section(String(localized: "reader.typography.size")) {
        Button {
          adjustSize(by: -1)
        } label: {
          Label(String(localized: "reader.typography.decrease"), systemImage: "textformat.size.smaller")
        }
        .disabled(viewModel.readerFontSizeMultiplier <= Self.sizeSteps.first!)

        Button {
          adjustSize(by: 1)
        } label: {
          Label(String(localized: "reader.typography.increase"), systemImage: "textformat.size.larger")
        }
        .disabled(viewModel.readerFontSizeMultiplier >= Self.sizeSteps.last!)

        Text(currentSizeLabel)
      }
    } label: {
      Image(systemName: "textformat.size")
        .font(.system(size: ReaderTypographyMenuMetrics.iconSize, weight: .semibold))
        .foregroundStyle(PrismaColors.textPrimary)
        .frame(width: ReaderTypographyMenuMetrics.hitSize, height: ReaderTypographyMenuMetrics.hitSize)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(String(localized: "reader.typography.menu"))
  }

  private var fontFamilyBinding: Binding<ReaderFontFamily> {
    Binding(
      get: { viewModel.readerFontFamily },
      set: { viewModel.setReaderFontFamily($0) }
    )
  }

  private var currentSizeLabel: String {
    let percent = Int((viewModel.readerFontSizeMultiplier * 100).rounded())
    return String(localized: "reader.typography.sizeValue \(percent)")
  }

  private func adjustSize(by step: Int) {
    let current = viewModel.readerFontSizeMultiplier
    guard let index = Self.sizeSteps.firstIndex(where: { abs($0 - current) < 0.001 }) else {
      let nearest = Self.sizeSteps.min(by: { abs($0 - current) < abs($1 - current) }) ?? 1.0
      viewModel.setReaderFontSizeMultiplier(nearest)
      return
    }
    let nextIndex = index + step
    guard Self.sizeSteps.indices.contains(nextIndex) else { return }
    viewModel.setReaderFontSizeMultiplier(Self.sizeSteps[nextIndex])
  }
}

private enum ReaderTypographyMenuMetrics {
  static let iconSize: CGFloat = 17
  static let hitSize: CGFloat = 44
}
