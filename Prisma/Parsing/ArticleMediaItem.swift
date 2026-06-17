import Foundation

enum ArticleMediaItem: Identifiable, Equatable {
  case image(URL)
  case video(URL, thumbnail: URL?)

  var id: String {
    switch self {
    case .image(let url):
      return "image:\(url.absoluteString)"
    case .video(let url, let thumbnail):
      return "video:\(url.absoluteString):\(thumbnail?.absoluteString ?? "")"
    }
  }

  var isVideo: Bool {
    if case .video = self { return true }
    return false
  }

  var previewURL: URL? {
    switch self {
    case .image(let url):
      return url
    case .video(_, let thumbnail):
      return thumbnail
    }
  }
}
