import XCTest
@testable import Prisma

final class HTMLSanitizerTests: XCTestCase {
  func testStripsHTML() {
    let result = HTMLSanitizer.stripHTML("<p>Hello <b>world</b></p>")
    XCTAssertEqual(result, "Hello world")
  }

  func testRemovesScriptTags() {
    let result = HTMLSanitizer.sanitizeForDisplay("<p>Safe</p><script>alert('x')</script>")
    XCTAssertFalse(result?.contains("script") ?? true)
    XCTAssertTrue(result?.contains("Safe") ?? false)
  }
}
