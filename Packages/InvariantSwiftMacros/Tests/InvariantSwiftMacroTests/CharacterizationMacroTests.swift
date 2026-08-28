import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

@Suite("Characterization Macro Tests")
struct CharacterizationMacroTests {
  @Test("CharacterizationTestMacro is registered")
  func macroIsRegistered() {
    let macroTypeName = String(describing: CharacterizationTestMacro.self)
    #expect(macroTypeName.contains("CharacterizationTestMacro"))
  }

  @Test("CharacterizationTest generates one stable runtime call")
  func generatesStableRuntimeCall() {
    assertCharacterizationMacroExpansion(
      """
      @CharacterizationTest(
        fixture: "parser.json",
        inputs: [CharacterizationInput(id: "empty", value: "")]
      )
      func characterizeParser(_ input: String) throws -> Int {
        input.count
      }
      """,
      expandedSource: """
        func characterizeParser(_ input: String) throws -> Int {
          input.count
        }

        private enum __macro_local_56characterizeParser_efc6cae9b2a58279_CharacterizationTestfMu_ {
          @Test("characterizeParser characterization")
          static func run() async throws {
            _ = try await InvariantSwiftTesting.CharacterizationTestRuntime.run(
              name: "characterizeParser",
              fixture: "parser.json",
              inputs: [CharacterizationInput(id: "empty", value: "")],
              operation: { input in
                try characterizeParser(input)
              }
            )
          }
        }
        """
    )
  }

  @Test("CharacterizationTest rejects non-functions at the attribute")
  func rejectsNonFunction() {
    assertCharacterizationMacroExpansion(
      """
      @CharacterizationTest(fixture: "value.json", inputs: [1])
      let value = 1
      """,
      expandedSource: """
        let value = 1
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@CharacterizationTest can only annotate a function",
          line: 1,
          column: 1
        )
      ]
    )
  }

  @Test("CharacterizationTest rejects zero and two parameters at parameter clauses")
  func rejectsWrongArity() {
    assertCharacterizationMacroExpansion(
      """
      @CharacterizationTest(fixture: "none.json", inputs: [1])
      func noInputs() {}
      """,
      expandedSource: """
        func noInputs() {}
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@CharacterizationTest requires one input parameter",
          line: 2,
          column: 14
        )
      ]
    )

    assertCharacterizationMacroExpansion(
      """
      @CharacterizationTest(fixture: "two.json", inputs: [1])
      func twoInputs(_ first: Int, _ second: Int) {}
      """,
      expandedSource: """
        func twoInputs(_ first: Int, _ second: Int) {}
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@CharacterizationTest requires one input parameter",
          line: 2,
          column: 15
        )
      ]
    )
  }
}

private func assertCharacterizationMacroExpansion(
  _ originalSource: String,
  expandedSource: String,
  diagnostics: [DiagnosticSpec] = []
) {
  var failures: [String] = []
  SwiftSyntaxMacrosGenericTestSupport.assertMacroExpansion(
    originalSource,
    expandedSource: expandedSource,
    diagnostics: diagnostics,
    macroSpecs: [
      "CharacterizationTest": MacroSpec(type: CharacterizationTestMacro.self)
    ],
    indentationWidth: .spaces(2),
    failureHandler: { failures.append($0.message) }
  )
  #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
}
