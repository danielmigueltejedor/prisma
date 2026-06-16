import Foundation

protocol FeedParserProtocol {
  func parse(data: Data) throws -> ParsedFeed
}
