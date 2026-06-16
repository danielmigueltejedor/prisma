import SwiftUI
import WebKit

struct ArticleHTMLView: View {
  let html: String
  var readerMode: Bool = false
  var fontSizeMultiplier: Double = 1.0

  @Environment(\.colorScheme) private var colorScheme
  @State private var contentHeight: CGFloat = 200

  private var htmlDocument: String {
    HTMLSanitizer.readerDocument(
      from: html,
      colorScheme: colorScheme,
      readerMode: readerMode,
      fontSizeMultiplier: fontSizeMultiplier
    )
  }

  var body: some View {
    ArticleWebView(
      htmlDocument: htmlDocument,
      contentHeight: $contentHeight
    )
    .frame(height: contentHeight)
    .animation(.easeInOut(duration: 0.2), value: readerMode)
  }
}

private struct ArticleWebView: UIViewRepresentable {
  let htmlDocument: String
  @Binding var contentHeight: CGFloat

  func makeCoordinator() -> Coordinator {
    Coordinator(contentHeight: $contentHeight)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    webView.navigationDelegate = context.coordinator
    webView.loadHTMLString(htmlDocument, baseURL: nil)
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    if context.coordinator.lastHTML != htmlDocument {
      context.coordinator.lastHTML = htmlDocument
      contentHeight = 200
      webView.loadHTMLString(htmlDocument, baseURL: nil)
    }
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    @Binding var contentHeight: CGFloat
    var lastHTML: String?

    init(contentHeight: Binding<CGFloat>) {
      _contentHeight = contentHeight
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
        guard let self, let height = result as? CGFloat, height > 0 else { return }
        DispatchQueue.main.async {
          self.contentHeight = height + 8
        }
      }
    }
  }
}
