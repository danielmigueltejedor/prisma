import SwiftUI
import WebKit

struct ArticleHTMLView: View {
  let html: String
  var baseURL: URL?
  var fontFamily: ReaderFontFamily = .serif
  var fontSizeMultiplier: Double = 1.0
  var suppressInlineImages: Bool = false
  var onOpenExternalURL: ((URL) -> Void)?

  @Environment(\.colorScheme) private var colorScheme
  @State private var contentHeight: CGFloat = 1
  @State private var renderedDocument = ""
  @State private var renderToken = ""
  @State private var documentTask: Task<Void, Never>?

  private var documentToken: String {
    [
      html.hashValue.description,
      fontFamily.rawValue,
      String(format: "%.2f", fontSizeMultiplier),
      colorScheme == .dark ? "dark" : "light",
      suppressInlineImages ? "noimg" : "img",
    ].joined(separator: "|")
  }

  var body: some View {
    ArticleWebView(
      htmlDocument: renderedDocument,
      baseURL: baseURL,
      contentHeight: $contentHeight,
      onOpenExternalURL: onOpenExternalURL
    )
    .frame(height: max(contentHeight, 1))
    .onAppear { refreshDocumentIfNeeded() }
    .onChange(of: documentToken) { _, _ in refreshDocumentIfNeeded() }
    .onDisappear { documentTask?.cancel() }
  }

  private func refreshDocumentIfNeeded() {
    guard renderToken != documentToken else { return }
    let token = documentToken
    renderToken = token

    let htmlCopy = html
    let scheme = colorScheme
    let family = fontFamily
    let multiplier = fontSizeMultiplier
    let suppressImages = suppressInlineImages

    documentTask?.cancel()
    documentTask = Task {
      let document = await Task.detached(priority: .userInitiated) {
        HTMLSanitizer.readerDocument(
          from: htmlCopy,
          colorScheme: scheme,
          fontFamily: family,
          fontSizeMultiplier: multiplier,
          suppressInlineImages: suppressImages
        )
      }.value

      guard !Task.isCancelled, renderToken == token else { return }
      renderedDocument = document
    }
  }
}

private struct ArticleWebView: UIViewRepresentable {
  let htmlDocument: String
  let baseURL: URL?
  @Binding var contentHeight: CGFloat
  var onOpenExternalURL: ((URL) -> Void)?

  func makeCoordinator() -> Coordinator {
    Coordinator(contentHeight: $contentHeight, onOpenExternalURL: onOpenExternalURL)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.navigationDelegate = context.coordinator
    context.coordinator.attach(webView)
    if !htmlDocument.isEmpty {
      webView.loadHTMLString(htmlDocument, baseURL: baseURL)
    }
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    context.coordinator.onOpenExternalURL = onOpenExternalURL
    context.coordinator.attach(webView)
    guard context.coordinator.lastHTML != htmlDocument else { return }
    context.coordinator.lastHTML = htmlDocument
    if htmlDocument.isEmpty {
      contentHeight = 1
      return
    }
    webView.loadHTMLString(htmlDocument, baseURL: baseURL)
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    @Binding var contentHeight: CGFloat
    var onOpenExternalURL: ((URL) -> Void)?
    var lastHTML: String?
    private weak var webView: WKWebView?

    init(contentHeight: Binding<CGFloat>, onOpenExternalURL: ((URL) -> Void)?) {
      _contentHeight = contentHeight
      self.onOpenExternalURL = onOpenExternalURL
    }

    func attach(_ webView: WKWebView) {
      self.webView = webView
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard navigationAction.navigationType == .linkActivated,
            let url = navigationAction.request.url else {
        decisionHandler(.allow)
        return
      }

      let scheme = url.scheme?.lowercased() ?? ""
      if scheme.isEmpty || scheme == "about" {
        decisionHandler(.allow)
        return
      }

      if scheme == "http" || scheme == "https" {
        onOpenExternalURL?(url)
        decisionHandler(.cancel)
        return
      }

      decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      injectReadMoreHandler(in: webView)
      scheduleHeightMeasurement(for: webView)
    }

    private func injectReadMoreHandler(in webView: WKWebView) {
      let script = """
      (function() {
        if (window.__prismaReadMoreInstalled) return;
        window.__prismaReadMoreInstalled = true;
        document.addEventListener('click', function(event) {
          var link = event.target.closest('a');
          if (!link) return;
          var href = (link.getAttribute('href') || '').trim();
          if (!href || href.startsWith('http') || href.startsWith('//')) return;
          if (!href.startsWith('#')) return;
          event.preventDefault();
          var target = document.querySelector(href);
          if (target) {
            target.style.display = 'block';
            target.hidden = false;
            target.classList.remove('hidden', 'prisma-hidden');
          }
          var hidden = document.querySelector('.content-hidden, .read-more-content, .article-body--full, [data-read-more]');
          if (hidden) {
            hidden.style.display = 'block';
            hidden.hidden = false;
            hidden.classList.remove('hidden', 'prisma-hidden');
          }
          link.style.display = 'none';
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChanged) {
            window.webkit.messageHandlers.heightChanged.postMessage('changed');
          }
        }, true);
      })();
      """
      webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func scheduleHeightMeasurement(for webView: WKWebView) {
      measureHeight(in: webView)
      for delay in [0.12, 0.28, 0.55] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
          guard let self, let webView else { return }
          self.measureHeight(in: webView)
        }
      }
    }

    private func measureHeight(in webView: WKWebView) {
      let script = """
      (function() {
        document.querySelectorAll('[hidden], .hidden, .prisma-hidden, [style*="display:none"], [style*="display: none"]').forEach(function(node) {
          node.remove();
        });
        var body = document.body;
        var html = document.documentElement;
        return Math.max(
          body.scrollHeight,
          body.offsetHeight,
          body.getBoundingClientRect().height,
          html.scrollHeight,
          html.offsetHeight,
          html.clientHeight
        );
      })();
      """
      webView.evaluateJavaScript(script) { [weak self] result, _ in
        guard let self, let height = Self.parseHeight(result), height > 0 else { return }
        DispatchQueue.main.async {
          let padded = ceil(height) + 8
          if abs(padded - self.contentHeight) > 1 {
            self.contentHeight = padded
          }
        }
      }
    }

    private static func parseHeight(_ result: Any?) -> CGFloat? {
      if let number = result as? NSNumber {
        return CGFloat(truncating: number)
      }
      if let double = result as? Double {
        return CGFloat(double)
      }
      if let int = result as? Int {
        return CGFloat(int)
      }
      return nil
    }
  }
}
