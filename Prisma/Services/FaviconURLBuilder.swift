import Foundation

enum FaviconURLBuilder {
  static func url(siteURL: String?, feedURL: String) -> URL? {
    let host = host(from: siteURL) ?? host(from: feedURL)
    guard let host, !host.isEmpty else { return nil }
    return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128")
  }

  private static func host(from urlString: String?) -> String? {
    guard let urlString, let url = URL(string: urlString), let host = url.host else { return nil }
    return host
  }
}
