import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

@Suite("PropertyTest Trait Macro Tests")
struct PropertyTestTraitMacroTests {
  private let testMacros: [String: Macro.Type] = [
    "PropertyTest": PropertyTestMacro.self
  ]

  @Test("@PropertyTest rejects enabledIf with disabledReason")
  func rejectsConflictingConditionTraits() {
    assertMacroExpansion(
      """
      @PropertyTest(enabledIf: true, disabledReason: "skip me")
      func testConflict(value: Int) {
        value > 0
      }
      """,
      expandedSource: """
        func testConflict(value: Int) {
          value > 0
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "`enabledIf` and `disabledReason` cannot both be set on the same property test",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  @Test("SwiftTestingTraitExtractor parses array-backed traits")
  func extractsTagsAndBugs() {
    let source: DeclSyntax = """
      @PropertyTest(
        tags: [.invariantSwiftPropertyReplay],
        bugs: [Bug.bug(id: "PBT-42")],
        serialized: true,
        timeLimit: .minutes(1),
        enabledIf: true
      )
      func test(value: Int) {}
      """

    guard
      let functionDecl = source.as(FunctionDeclSyntax.self),
      let attribute = functionDecl.attributes.first?.as(AttributeSyntax.self)
    else {
      Issue.record("Failed to parse property test attribute")
      return
    }

    let traits = SwiftTestingTraitExtractor.extract(from: attribute)
    #expect(traits.serialized == true)
    #expect(traits.tags.count == 1)
    #expect(traits.bugs.count == 1)
    #expect(traits.enabledCondition?.description == "true")
    #expect(traits.timeLimit?.description == ".minutes(1)")
  }
}
