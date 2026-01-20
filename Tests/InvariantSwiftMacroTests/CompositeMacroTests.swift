import XCTest
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class CompositeMacroTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "Composite": CompositeMacro.self
  ]

  // MARK: - Valid Expansion Tests

  /// Tests that a function with no #draw calls passes through unchanged.
  func testFunctionWithNoDrawCalls() throws {
    assertMacroExpansion(
      """
      @Composite
      func simpleGen() -> Gen<Int> {
          return Gen<Int>.int
      }
      """,
      expandedSource: """
        func simpleGen() -> Gen<Int> {
            return Gen<Int>.int
        }
        """,
      macros: testMacros
    )
  }

  // Note: BodyMacro is ONLY applied to functions by Swift's macro system.
  // Testing "mustBeFunction" diagnostic is not possible because the macro
  // role is function-specific - structs/classes never invoke BodyMacro.
}
