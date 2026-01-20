import XCTest
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import InvariantSwiftMacros

final class RuleBasedTestMacroTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "RuleBasedTest": RuleBasedTestMacro.self
  ]

  // MARK: - Diagnostic Tests

  func testRuleBasedTestMustBeStruct() throws {
    assertMacroExpansion(
      """
      @RuleBasedTest
      class NotAStruct {
          var value: Int = 0
      }
      """,
      expandedSource: """
        class NotAStruct {
            var value: Int = 0
        }

        extension NotAStruct: RuleBasedStateMachine {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@RuleBasedTest can only be applied to structs",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }
}
