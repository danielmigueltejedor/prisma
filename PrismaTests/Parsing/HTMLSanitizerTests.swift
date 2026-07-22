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

  func testDecodesNumericAndNamedEntitiesInPlainText() {
    let input = "expansi&oacute;n en pa&iacute;ses&#32;—&#32;compa&ntilde;&iacute;a"
    let result = HTMLSanitizer.normalizePlainText(input)
    XCTAssertEqual(result, "expansión en países — compañía")
  }

  func testDecodesHexNumericEntities() {
    let result = HTMLSanitizer.normalizePlainText("hola&#x20;mundo")
    XCTAssertEqual(result, "hola mundo")
  }
}
