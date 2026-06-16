import SwiftUI

/// Full-screen layout with glass background. Content respects safe areas (nav bar, tab bar).
struct PrismaScreen<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background {
        GlassBackground()
      }
  }
}
