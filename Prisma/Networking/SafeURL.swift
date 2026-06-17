import Foundation

enum SafeURL {
  static func httpURL(from raw: String) -> URL? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let decoded = (trimmed.removingPercentEncoding ?? trimmed)
      .replacingOccurrences(of: "&amp;", with: "&")
    let candidate = decoded.contains("://") ? decoded : "https://\(decoded)"

    guard let components = URLComponents(string: candidate),
          let scheme = components.scheme?.lowercased(),
          scheme == "https" || scheme == "http",
          let host = components.host,
          !host.isEmpty,
          let url = components.url
    else {
      return nil
    }

    return url
  }

  static func isAllowedHTTPScheme(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    return scheme == "https" || scheme == "http"
  }
}
