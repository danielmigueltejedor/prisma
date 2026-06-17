import ImageIO
import Foundation
import SwiftUI
import UIKit

enum ArticleImageLoader {
  private static let cache = NSCache<NSString, UIImage>()
  private static var didConfigureCache = false
  private static let imageSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = URLCache(
      memoryCapacity: 24_000_000,
      diskCapacity: 120_000_000
    )
    configuration.requestCachePolicy = .returnCacheDataElseLoad
    configuration.waitsForConnectivity = false
    configuration.timeoutIntervalForRequest = 25
    configuration.timeoutIntervalForResource = 60
    configuration.httpMaximumConnectionsPerHost = 4
    return URLSession(configuration: configuration)
  }()

  static func image(for url: URL, maxPixelSize: CGFloat? = nil) async -> UIImage? {
    configureCacheLimitsOnce()

    let resolved = ArticleImageURLResolver.resolve(url)
    guard SafeURL.isAllowedHTTPScheme(resolved) else { return nil }

    let cacheKey = cacheKey(for: resolved, maxPixelSize: maxPixelSize)
    if let cached = cache.object(forKey: cacheKey) {
      return cached
    }

    var request = URLRequest(url: resolved)
    request.cachePolicy = .returnCacheDataElseLoad
    request.setValue("image/*", forHTTPHeaderField: "Accept")

    do {
      let (data, response) = try await imageSession.data(for: request)
      guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
        return nil
      }
      guard data.count <= NetworkClient.maxImageResponseBytes else { return nil }

      let image = await Task.detached(priority: .utility) {
        decodedImage(from: data, maxPixelSize: maxPixelSize)
      }.value
      guard let image else { return nil }

      let cost = Int(image.size.width * image.size.height * image.scale * image.scale)
      cache.setObject(image, forKey: cacheKey, cost: cost)
      return image
    } catch {
      return nil
    }
  }

  private static func configureCacheLimitsOnce() {
    guard !didConfigureCache else { return }
    didConfigureCache = true
    cache.countLimit = 120
    cache.totalCostLimit = 48_000_000
  }

  private static func cacheKey(for url: URL, maxPixelSize: CGFloat?) -> NSString {
    if let maxPixelSize {
      return "\(url.absoluteString)|\(Int(maxPixelSize))" as NSString
    }
    return url.absoluteString as NSString
  }

  private static func decodedImage(from data: Data, maxPixelSize: CGFloat?) -> UIImage? {
    guard let maxPixelSize, maxPixelSize > 0 else {
      return UIImage(data: data, scale: 1.0)
    }

    let options: [CFString: Any] = [
      kCGImageSourceShouldCache: false,
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else {
      return UIImage(data: data, scale: 1.0)
    }
    return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
  }
}

struct ArticleRemoteImage<Content: View, Placeholder: View>: View {
  let url: URL
  var maxPixelSize: CGFloat?
  @ViewBuilder var content: (Image) -> Content
  @ViewBuilder var placeholder: () -> Placeholder

  @State private var loadedImage: UIImage?

  var body: some View {
    Group {
      if let loadedImage {
        content(
          Image(uiImage: loadedImage)
            .interpolation(.high)
            .antialiased(true)
        )
      } else {
        placeholder()
      }
    }
    .task(id: taskID) {
      loadedImage = await ArticleImageLoader.image(for: url, maxPixelSize: maxPixelSize)
    }
  }

  private var taskID: String {
    if let maxPixelSize {
      return "\(url.absoluteString)|\(Int(maxPixelSize))"
    }
    return url.absoluteString
  }
}
