import SwiftUI

struct PrismaCard<Content: View>: View {
  var cornerRadius: CGFloat = PrismaRadius.lg
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .padding(PrismaSpacing.md)
      .prismaGlass(cornerRadius: cornerRadius)
  }
}
