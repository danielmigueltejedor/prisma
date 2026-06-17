import AVKit
import SwiftUI
import WebKit

struct ArticleDirectVideoPlayer: View {
  let url: URL
  @State private var player: AVPlayer?

  var body: some View {
    VideoPlayer(player: player)
      .onAppear {
        guard player == nil else { return }
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
      }
      .onDisappear {
        player?.pause()
        player = nil
      }
  }
}

struct ArticleEmbedVideoPlayer: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    if #available(iOS 26.0, *) {
      configuration.allowsPictureInPictureMediaPlayback = true
    }

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .black
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    guard context.coordinator.loadedURL != url else { return }
    context.coordinator.loadedURL = url
    let html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
      <style>
        html, body { margin: 0; padding: 0; background: #000; height: 100%; }
        iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
      </style>
    </head>
    <body>
      <iframe src="\(url.absoluteString)" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
    </body>
    </html>
    """
    webView.loadHTMLString(html, baseURL: url)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator {
    var loadedURL: URL?
  }
}

struct ArticleFullscreenVideoView: View {
  let url: URL

  var body: some View {
    Group {
      if ArticleMediaExtractor.isEmbeddableHost(url.host?.lowercased() ?? "") {
        ArticleEmbedVideoPlayer(url: url)
      } else {
        ArticleDirectVideoPlayer(url: url)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }
}
