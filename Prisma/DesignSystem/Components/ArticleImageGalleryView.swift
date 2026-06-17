import SwiftUI

struct ArticleImageGalleryView: View {
  let imageURLs: [URL]
  @Binding var selectedIndex: Int
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      TabView(selection: $selectedIndex) {
        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
          ZoomableGalleryImage(url: url)
            .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .automatic : .never))

      VStack {
        HStack {
          if imageURLs.count > 1 {
            Text("\(selectedIndex + 1) / \(imageURLs.count)")
              .font(PrismaTypography.caption(.semibold))
              .foregroundStyle(.white.opacity(0.9))
              .padding(.horizontal, PrismaSpacing.sm)
              .padding(.vertical, PrismaSpacing.xxs)
              .background(.black.opacity(0.45), in: Capsule())
          }
          Spacer()
          Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 28))
              .symbolRenderingMode(.palette)
              .foregroundStyle(.white, .white.opacity(0.35))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(String(localized: "action.close"))
        }
        .padding(PrismaSpacing.md)
        Spacer()
      }
    }
  }
}

private struct ZoomableGalleryImage: View {
  let url: URL
  @State private var scale: CGFloat = 1
  @State private var lastScale: CGFloat = 1

  var body: some View {
    GeometryReader { proxy in
      ArticleRemoteImage(url: url, maxPixelSize: 560) { image in
        image
          .resizable()
          .scaledToFit()
          .frame(width: proxy.size.width, height: proxy.size.height)
          .scaleEffect(scale)
          .gesture(magnificationGesture)
          .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
              if scale > 1.01 {
                scale = 1
                lastScale = 1
              } else {
                scale = 2.5
                lastScale = 2.5
              }
            }
          }
      } placeholder: {
        ProgressView()
          .tint(.white)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private var magnificationGesture: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        scale = min(max(lastScale * value, 1), 4)
      }
      .onEnded { _ in
        lastScale = scale
        if scale < 1.05 {
          scale = 1
          lastScale = 1
        }
      }
  }
}

struct ArticleImageCarousel: View {
  let imageURLs: [URL]
  var onSelect: (Int) -> Void

  var body: some View {
    Group {
      if imageURLs.count == 1, let url = imageURLs.first {
        carouselImage(url, index: 0)
          .frame(maxHeight: 280)
      } else {
        TabView {
          ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
            carouselImage(url, index: index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 280)
      }
    }
  }

  private func carouselImage(_ url: URL, index: Int) -> some View {
    Button { onSelect(index) } label: {
      ArticleRemoteImage(url: url, maxPixelSize: 560) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        RoundedRectangle(cornerRadius: PrismaRadius.lg, style: .continuous)
          .fill(PrismaColors.surface)
          .overlay { ProgressView() }
      }
      .frame(maxWidth: .infinity)
      .frame(maxHeight: 280)
      .clipShape(RoundedRectangle(cornerRadius: PrismaRadius.lg, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: PrismaRadius.lg, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(String(localized: "reader.openImage"))
    .accessibilityHint(
      imageURLs.count > 1
        ? String(localized: "reader.openImageGalleryHint")
        : String(localized: "reader.openImageHint")
    )
  }
}
