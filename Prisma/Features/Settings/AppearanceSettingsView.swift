import SwiftUI

struct AppearanceSettingsView: View {
  @Bindable var viewModel: SettingsViewModel

  var body: some View {
    Form {
      Section {
        themePreview
      }

      Section(String(localized: "settings.theme")) {
        Picker(String(localized: "settings.theme"), selection: appearanceBinding) {
          ForEach(AppearanceMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
      }

      Section(String(localized: "settings.reader")) {
        Picker(String(localized: "reader.typography.font"), selection: fontFamilyBinding) {
          ForEach(ReaderFontFamily.allCases) { family in
            Text(family.displayName).tag(family)
          }
        }

        VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
          Text(String(localized: "settings.fontSize"))
          Slider(
            value: Binding(
              get: { viewModel.preferences?.readerFontSizeMultiplier ?? 1.0 },
              set: { viewModel.setFontMultiplier($0) }
            ),
            in: 0.8 ... 1.6,
            step: 0.1
          )
          Text(String(localized: "settings.fontPreview"))
            .font(PrismaTypography.readerBody(
              sizeMultiplier: viewModel.preferences?.readerFontSizeMultiplier ?? 1,
              family: viewModel.preferences?.readerFontFamily ?? .serif
            ))
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background { GlassBackground() }
    .navigationTitle(String(localized: "settings.appearance"))
  }

  private var appearanceBinding: Binding<AppearanceMode> {
    Binding(
      get: { viewModel.preferences?.appearanceMode ?? .system },
      set: { viewModel.setAppearance($0) }
    )
  }

  private var fontFamilyBinding: Binding<ReaderFontFamily> {
    Binding(
      get: { viewModel.preferences?.readerFontFamily ?? .serif },
      set: { viewModel.setReaderFontFamily($0) }
    )
  }

  private var themePreview: some View {
    VStack(alignment: .leading, spacing: PrismaSpacing.sm) {
      Text(currentMode.displayName)
        .font(PrismaTypography.headline())
      Text(String(localized: "settings.themePreview"))
        .font(PrismaTypography.callout())
        .foregroundStyle(PrismaColors.textSecondary)
    }
    .padding(PrismaSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .prismaGlass()
    .listRowBackground(Color.clear)
    .listRowInsets(EdgeInsets())
  }

  private var currentMode: AppearanceMode {
    viewModel.preferences?.appearanceMode ?? .system
  }
}
