import SwiftUI

struct SourceIconView: View {
  let siteURL: String?
  let feedURL: String
  var size: CGFloat = 32

  var body: some View {
    Group {
      if let url = FaviconURLBuilder.url(siteURL: siteURL, feedURL: feedURL) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          default:
            placeholder
          }
        }
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
  }

  private var placeholder: some View {
    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
      .fill(PrismaColors.elevatedSurface)
      .overlay {
        Image(systemName: "newspaper.fill")
          .font(.system(size: size * 0.4))
          .foregroundStyle(PrismaColors.textTertiary)
      }
  }
}

extension FeedSource {
  var faviconSiteURL: String? { siteURL ?? feedURL }
}

extension Article {
  var faviconSiteURL: String? { originalFeedUrl }
}
