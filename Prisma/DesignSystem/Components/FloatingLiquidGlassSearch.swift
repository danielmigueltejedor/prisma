import SwiftUI

private enum FloatingSearchMetrics {
  static let collapseThreshold: CGFloat = 18
  static let fieldIconSize: CGFloat = 19
  static let toolbarIconSize: CGFloat = 22
  static let toolbarHitSize: CGFloat = 48
  static let expandedFieldVerticalPadding: CGFloat = 11
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

struct ScrollOffsetReader: View {
  let coordinateSpace: String

  var body: some View {
    GeometryReader { proxy in
      Color.clear
        .preference(
          key: ScrollOffsetPreferenceKey.self,
          value: proxy.frame(in: .named(coordinateSpace)).minY
        )
    }
    .frame(height: 1)
    .opacity(0.001)
  }
}

struct LiquidGlassSearchToolbarButton: View {
  let accessibilityLabel: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      searchGlyph
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }

  @ViewBuilder
  private var searchGlyph: some View {
    if #available(iOS 26.0, *) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: FloatingSearchMetrics.toolbarIconSize, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: FloatingSearchMetrics.toolbarHitSize, height: FloatingSearchMetrics.toolbarHitSize)
        .contentShape(Circle())
        .glassEffect(.regular.interactive(), in: .circle)
    } else {
      Image(systemName: "magnifyingglass")
        .font(.system(size: FloatingSearchMetrics.toolbarIconSize, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: FloatingSearchMetrics.toolbarHitSize, height: FloatingSearchMetrics.toolbarHitSize)
        .contentShape(Circle())
        .prismaGlass(cornerRadius: FloatingSearchMetrics.toolbarHitSize / 2)
    }
  }
}

struct LiquidGlassCloseToolbarButton: View {
  let accessibilityLabel: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      if #available(iOS 26.0, *) {
        Image(systemName: "xmark")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.primary)
          .frame(width: FloatingSearchMetrics.toolbarHitSize, height: FloatingSearchMetrics.toolbarHitSize)
          .contentShape(Circle())
          .glassEffect(.regular.interactive(), in: .circle)
      } else {
        Image(systemName: "xmark")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.primary)
          .frame(width: FloatingSearchMetrics.toolbarHitSize, height: FloatingSearchMetrics.toolbarHitSize)
          .contentShape(Circle())
          .prismaGlass(cornerRadius: FloatingSearchMetrics.toolbarHitSize / 2)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }
}

/// Fondo translúcido bajo la barra de navegación custom, con borde inferior recto (estilo GitHub).
struct PrismaNavigationHeaderChrome<Content: View>: View {
  var scrollOffset: CGFloat = 0
  @ViewBuilder var content: () -> Content

  private var isScrolled: Bool {
    scrollOffset > 4
  }

  var body: some View {
    VStack(spacing: 0) {
      content()

      Rectangle()
        .fill(PrismaColors.separator)
        .frame(height: 0.5)
        .opacity(isScrolled ? 0.9 : 0.45)
    }
    .background {
      NavigationHeaderChromeBackground(isScrolled: isScrolled)
    }
    .animation(.easeOut(duration: 0.22), value: isScrolled)
  }
}

private struct NavigationHeaderChromeBackground: View {
  let isScrolled: Bool

  var body: some View {
    ZStack {
      if #available(iOS 26.0, *) {
        Rectangle()
          .fill(.bar)
          .opacity(isScrolled ? 0.96 : 0.82)
      } else {
        Rectangle()
          .fill(.ultraThinMaterial)
          .opacity(isScrolled ? 1 : 0.9)
      }

      if isScrolled {
        Rectangle()
          .fill(Color.black.opacity(0.06))
      }
    }
    .ignoresSafeArea(edges: .top)
    .animation(.easeOut(duration: 0.22), value: isScrolled)
  }
}

/// Barra superior con búsqueda morphing (círculo → cápsula) fuera del toolbar del sistema
/// para evitar doble capa de glass y usar `glassEffectID` nativo.
struct MorphingLiquidGlassNavigationBar<Trailing: View>: View {
  @Namespace private var glassNamespace

  @Binding var isExpanded: Bool
  @Binding var searchText: String
  let title: String
  let prompt: String
  var onTextChange: () -> Void
  var focus: FocusState<Bool>.Binding
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack(spacing: PrismaSpacing.sm) {
      searchCluster
        .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)

      if !isExpanded {
        Text(title)
          .font(PrismaTypography.headline())
          .foregroundStyle(PrismaColors.textPrimary)
          .lineLimit(1)
          .frame(maxWidth: .infinity)
          .transition(.blurReplace)

        trailing()
          .transition(.blurReplace)
      }
    }
    .animation(.bouncy(duration: 0.42), value: isExpanded)
    .padding(.horizontal, PrismaSpacing.md)
    .frame(minHeight: FloatingSearchMetrics.toolbarHitSize)
    .padding(.top, PrismaSpacing.xxs)
    .padding(.bottom, PrismaSpacing.sm)
  }

  @ViewBuilder
  private var searchCluster: some View {
    if #available(iOS 26.0, *) {
      ios26SearchCluster
    } else {
      legacySearchCluster
    }
  }

  @available(iOS 26.0, *)
  @ViewBuilder
  private var ios26SearchCluster: some View {
    GlassEffectContainer(spacing: 12) {
      HStack(spacing: 8) {
        if isExpanded {
          Button(action: collapseSearch) {
            Image(systemName: "xmark")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.primary)
              .frame(
                width: FloatingSearchMetrics.toolbarHitSize,
                height: FloatingSearchMetrics.toolbarHitSize
              )
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .glassEffect(.regular.interactive(), in: .circle)
          .glassEffectID("search-close", in: glassNamespace)
          .glassEffectTransition(.materialize)
          .accessibilityLabel(String(localized: "action.cancel"))
        }

        Group {
          if isExpanded {
            morphingSearchFieldContent
              .padding(.horizontal, PrismaSpacing.md)
              .padding(.vertical, FloatingSearchMetrics.expandedFieldVerticalPadding)
              .frame(maxWidth: .infinity, alignment: .leading)
              .glassEffect(.regular.interactive(), in: .capsule)
          } else {
            Button(action: expandSearch) {
              Image(systemName: "magnifyingglass")
                .font(.system(size: FloatingSearchMetrics.toolbarIconSize, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(
                  width: FloatingSearchMetrics.toolbarHitSize,
                  height: FloatingSearchMetrics.toolbarHitSize
                )
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(prompt)
          }
        }
        .glassEffectID("search", in: glassNamespace)
      }
    }
    .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
  }

  @ViewBuilder
  private var legacySearchCluster: some View {
    HStack(spacing: 8) {
      if isExpanded {
        LiquidGlassCloseToolbarButton(accessibilityLabel: String(localized: "action.cancel")) {
          collapseSearch()
        }
      }

      if isExpanded {
        LiquidGlassSearchField(
          text: $searchText,
          prompt: prompt,
          placement: .toolbar,
          showCancel: false,
          onTextChange: onTextChange,
          onCancel: collapseSearch,
          focus: focus
        )
        .frame(maxWidth: .infinity)
      } else {
        LiquidGlassSearchToolbarButton(accessibilityLabel: prompt, action: expandSearch)
      }
    }
    .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
  }

  private var morphingSearchFieldContent: some View {
    HStack(spacing: PrismaSpacing.sm) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: FloatingSearchMetrics.fieldIconSize, weight: .medium))
        .foregroundStyle(PrismaColors.textTertiary)

      TextField(prompt, text: $searchText)
        .font(PrismaTypography.body())
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused(focus)

      if !searchText.isEmpty {
        Button {
          searchText = ""
          onTextChange()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(PrismaColors.textTertiary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .onChange(of: searchText) { _, _ in
      onTextChange()
    }
  }

  private func expandSearch() {
    withAnimation(.bouncy(duration: 0.42)) {
      isExpanded = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      focus.wrappedValue = true
    }
  }

  private func collapseSearch() {
    searchText = ""
    focus.wrappedValue = false
    onTextChange()
    withAnimation(.bouncy(duration: 0.42)) {
      isExpanded = false
    }
  }
}

enum LiquidGlassSearchFieldPlacement {
  case inset
  case toolbar
}

struct LiquidGlassSearchField: View {
  @Binding var text: String
  let prompt: String
  var placement: LiquidGlassSearchFieldPlacement = .inset
  var showCancel: Bool
  var onTextChange: () -> Void
  var onCancel: () -> Void
  var focus: FocusState<Bool>.Binding

  var body: some View {
    HStack(spacing: PrismaSpacing.sm) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: FloatingSearchMetrics.fieldIconSize, weight: .medium))
        .foregroundStyle(PrismaColors.textTertiary)

      TextField(prompt, text: $text)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused(focus)

      if !text.isEmpty {
        Button {
          text = ""
          onTextChange()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(PrismaColors.textTertiary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      if showCancel {
        Button(String(localized: "action.cancel"), action: onCancel)
          .font(PrismaTypography.callout(.semibold))
          .foregroundStyle(PrismaColors.accentFallback)
      }
    }
    .padding(.horizontal, PrismaSpacing.md)
    .padding(.vertical, placement == .toolbar ? PrismaSpacing.xs : PrismaSpacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      if placement == .inset {
        LiquidGlassSearchCapsuleBackground()
      } else {
        LiquidGlassSearchCapsuleBackground()
      }
    }
    .onChange(of: text) { _, _ in
      onTextChange()
    }
  }
}

struct ScrollAwareLiquidGlassSearchLayout<Content: View>: View {
  @Binding var searchText: String
  @Binding var showsToolbarSearchButton: Bool
  @Binding var scrollToTopToken: Int
  var externalScrollOffset: CGFloat?
  let prompt: String
  var onTextChange: () -> Void
  var focus: FocusState<Bool>.Binding
  @ViewBuilder var content: () -> Content

  @State private var baselineOffset: CGFloat?
  @State private var isCollapsed = false

  private var isScrolledDown: Bool {
    isCollapsed
  }

  private var showsTopInsetSearch: Bool {
    if !searchText.isEmpty { return true }
    return !isScrolledDown
  }

  var body: some View {
    content()
      .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
        guard externalScrollOffset == nil else { return }
        applyScrollOffset(value)
      }
      .safeAreaInset(edge: .top, spacing: 0) {
        if showsTopInsetSearch {
          LiquidGlassSearchField(
            text: $searchText,
            prompt: prompt,
            placement: .inset,
            showCancel: false,
            onTextChange: onTextChange,
            onCancel: cancelSearch,
            focus: focus
          )
          .padding(.horizontal, PrismaSpacing.md)
          .padding(.bottom, PrismaSpacing.xs)
        }
      }
      .onChange(of: searchText) { _, _ in
        onTextChange()
        updateToolbarButtonVisibility()
      }
      .onChange(of: scrollToTopToken) { _, _ in
        isCollapsed = false
        baselineOffset = nil
        updateToolbarButtonVisibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
          focus.wrappedValue = true
        }
      }
      .onChange(of: externalScrollOffset) { _, value in
        guard let value else { return }
        applyScrollOffset(value)
      }
      .onAppear {
        if let externalScrollOffset {
          applyScrollOffset(externalScrollOffset)
        }
        updateToolbarButtonVisibility()
      }
  }

  private func cancelSearch() {
    searchText = ""
    focus.wrappedValue = false
    onTextChange()
  }

  private func applyScrollOffset(_ value: CGFloat) {
    if baselineOffset == nil {
      baselineOffset = value
    }
    let baseline = baselineOffset ?? value
    let delta = value - baseline

    let collapsed = delta > FloatingSearchMetrics.collapseThreshold
    if collapsed != isCollapsed {
      isCollapsed = collapsed
    }
    updateToolbarButtonVisibility()
  }

  private func updateToolbarButtonVisibility() {
    showsToolbarSearchButton = isScrolledDown && searchText.isEmpty
  }
}

extension View {
  @ViewBuilder
  func captureNativeScrollOffset(_ offset: Binding<CGFloat>) -> some View {
    if #available(iOS 18.0, *) {
      self.onScrollGeometryChange(for: CGFloat.self) { geometry in
        geometry.contentOffset.y
      } action: { _, newValue in
        offset.wrappedValue = newValue
      }
    } else {
      self
    }
  }
}

private struct LiquidGlassSearchCapsuleBackground: View {
  var body: some View {
    if #available(iOS 26.0, *) {
      Capsule()
        .glassEffect(.regular, in: .capsule)
    } else {
      Capsule()
        .fill(.ultraThinMaterial)
        .overlay {
          Capsule()
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }
  }
}

extension ToolbarContent {
  @ToolbarContentBuilder
  func prismaHidingSharedToolbarBackground() -> some ToolbarContent {
    if #available(iOS 26.0, *) {
      sharedBackgroundVisibility(.hidden)
    } else {
      self
    }
  }
}

/// Pantalla dedicada de búsqueda: resultados desde arriba, separada del scroll del feed.
struct LiquidGlassSearchModeShell<Filters: View, Results: View>: View {
  let hasQuery: Bool
  let hasResults: Bool
  let emptyTitle: String
  let emptyMessage: String
  let noResultsTitle: String
  let noResultsMessage: String
  var scrollOffset: Binding<CGFloat>? = nil
  @ViewBuilder var filters: () -> Filters
  @ViewBuilder var results: () -> Results

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: PrismaSpacing.md) {
        filters()

        if !hasQuery {
          searchPlaceholder(title: emptyTitle, message: emptyMessage)
        } else if !hasResults {
          searchPlaceholder(title: noResultsTitle, message: noResultsMessage)
        } else {
          results()
        }
      }
      .padding(PrismaSpacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .modifier(ScrollOffsetCaptureModifier(scrollOffset: scrollOffset))
  }

  private func searchPlaceholder(title: String, message: String) -> some View {
    VStack(spacing: PrismaSpacing.sm) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 36, weight: .medium))
        .foregroundStyle(PrismaColors.textTertiary)
      Text(title)
        .font(PrismaTypography.headline())
        .foregroundStyle(PrismaColors.textPrimary)
      Text(message)
        .font(PrismaTypography.body())
        .foregroundStyle(PrismaColors.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, PrismaSpacing.xxl)
  }
}

private struct ScrollOffsetCaptureModifier: ViewModifier {
  let scrollOffset: Binding<CGFloat>?

  func body(content: Content) -> some View {
    if let scrollOffset {
      content.captureNativeScrollOffset(scrollOffset)
    } else {
      content
    }
  }
}
