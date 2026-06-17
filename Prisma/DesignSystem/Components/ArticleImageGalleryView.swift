import SwiftUI

struct ArticleMediaGalleryView: View {
  let mediaItems: [ArticleMediaItem]
  @Binding var selectedIndex: Int
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      TabView(selection: $selectedIndex) {
        ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, item in
          galleryPage(item)
            .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: mediaItems.count > 1 ? .automatic : .never))

      VStack {
        HStack {
          if mediaItems.count > 1 {
            Text("\(selectedIndex + 1) / \(mediaItems.count)")
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

  @ViewBuilder
  private func galleryPage(_ item: ArticleMediaItem) -> some View {
    switch item {
    case .image(let url):
      ZoomableGalleryImage(url: url)
    case .video(let url, _):
      ArticleFullscreenVideoView(url: url)
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

struct ArticleMediaCarousel: View {
  let mediaItems: [ArticleMediaItem]
  var onSelect: (Int) -> Void

  var body: some View {
    Group {
      if mediaItems.count == 1, let item = mediaItems.first {
        carouselItem(item, index: 0)
          .frame(maxHeight: 280)
      } else {
        TabView {
          ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, item in
            carouselItem(item, index: index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 280)
      }
    }
  }

  private func carouselItem(_ item: ArticleMediaItem, index: Int) -> some View {
    Button { onSelect(index) } label: {
      ZStack {
        mediaPreview(item)
        if item.isVideo {
          Image(systemName: "play.circle.fill")
            .font(.system(size: 52))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .black.opacity(0.35))
            .shadow(radius: 8)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(maxHeight: 280)
      .clipShape(RoundedRectangle(cornerRadius: PrismaRadius.lg, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: PrismaRadius.lg, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      item.isVideo
        ? String(localized: "reader.openVideo")
        : String(localized: "reader.openImage")
    )
    .accessibilityHint(
      mediaItems.count > 1
        ? String(localized: "reader.openMediaGalleryHint")
        : (item.isVideo
          ? String(localized: "reader.openVideoHint")
          : String(localized: "reader.openImageHint"))
    )
  }

  @ViewBuilder
  private func mediaPreview(_ item: ArticleMediaItem) -> some View {
    switch item {
    case .image(let url):
      ArticleRemoteImage(url: url, maxPixelSize: 560) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        mediaPlaceholder
      }
    case .video(_, let thumbnail):
      if let thumbnail {
        ArticleRemoteImage(url: thumbnail, maxPixelSize: 560) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          mediaPlaceholder
        }
      } else {
        mediaPlaceholder
          .overlay {
            Image(systemName: "video.fill")
              .font(.system(size: 36))
              .foregroundStyle(PrismaColors.textTertiary)
          }
      }
    }
  }

  private var mediaPlaceholder: some View {
    RoundedRectangle(cornerRadius: PrismaRadius.lg, style: .continuous)
      .fill(PrismaColors.surface)
      .overlay { ProgressView() }
  }
}

// Compatibilidad con vistas que aún usan solo imágenes.
struct ArticleImageGalleryView: View {
  let imageURLs: [URL]
  @Binding var selectedIndex: Int

  var body: some View {
    ArticleMediaGalleryView(
      mediaItems: imageURLs.map { .image($0) },
      selectedIndex: $selectedIndex
    )
  }
}

struct ArticleImageCarousel: View {
  let imageURLs: [URL]
  var onSelect: (Int) -> Void

  var body: some View {
    ArticleMediaCarousel(
      mediaItems: imageURLs.map { .image($0) },
      onSelect: onSelect
    )
  }
}
