import SwiftUI

struct GlassBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  private var isDark: Bool { colorScheme == .dark }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          PrismaColors.accentFallback.opacity(isDark ? 0.18 : 0.08),
          PrismaColors.background,
          PrismaColors.plusBadge.opacity(isDark ? 0.10 : 0.04),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      Circle()
        .fill(PrismaColors.accentFallback.opacity(isDark ? 0.20 : 0.12))
        .frame(width: 280, height: 280)
        .blur(radius: 60)
        .offset(x: -120, y: -200)

      Circle()
        .fill(PrismaColors.plusBadge.opacity(isDark ? 0.16 : 0.10))
        .frame(width: 220, height: 220)
        .blur(radius: 50)
        .offset(x: 140, y: 300)
    }
  }
}
