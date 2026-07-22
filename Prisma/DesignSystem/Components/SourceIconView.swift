import SwiftUI

struct SourceIconView: View {
  let siteURL: String?
  let feedURL: String
  var platform: FeedPlatform = .news
  var size: CGFloat = 32

  @State private var loadedImage: UIImage?

  private static let faviconDecodePixelSize: CGFloat = 128

  private var faviconURL: URL? {
    FaviconURLBuilder.url(siteURL: siteURL, feedURL: feedURL)
  }

  var body: some View {
    Group {
      if let asset = platform.assetName {
        Image(asset)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else if let loadedImage {
        Image(uiImage: loadedImage)
          .resizable()
          .interpolation(.high)
          .antialiased(true)
          .aspectRatio(contentMode: .fill)
      } else {
        placeholder
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        .strokeBorder(PrismaColors.separator.opacity(0.5), lineWidth: 0.5)
    }
    .accessibilityHidden(true)
    .task(id: faviconURL) {
      guard let faviconURL else {
        loadedImage = nil
        return
      }
      loadedImage = await ArticleImageLoader.image(
        for: faviconURL,
        maxPixelSize: Self.faviconDecodePixelSize
      )
    }
  }

  private var placeholder: some View {
    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
      .fill(PrismaColors.elevatedSurface)
      .overlay {
        Image(systemName: platform.systemImage)
          .font(.system(size: size * 0.4))
          .foregroundStyle(PrismaColors.textTertiary)
      }
  }
}

private extension FeedPlatform {
  var assetName: String? {
    switch self {
    case .reddit: "PlatformReddit"
    case .x: "PlatformX"
    case .news: nil
    }
  }
}

extension FeedSource {
  var faviconSiteURL: String? { siteURL ?? feedURL }

  /// Plataforma para UI (iconos, badges): no pierde X/Reddit por feeds fallback.
  var effectivePlatform: FeedPlatform {
    FeedPlatform.resolve(for: self)
  }
}

extension Article {
  var faviconSiteURL: String? { feedSource?.siteURL ?? feedSource?.faviconSiteURL }
}
