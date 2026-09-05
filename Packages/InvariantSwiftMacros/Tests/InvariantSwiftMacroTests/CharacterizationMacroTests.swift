import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

private let parseSource = """
  @CharacterizationTest(
    fixture: "parser.json",
    inputs: [CharacterizationInput(id: "empty", value: "")]
  )
  func parse(_ input: String) throws -> Int {
    input.count
  }
  """

private let expectedParseExpansion = """
  func parse(_ input: String) throws -> Int {
    input.count
  }

  private enum __macro_local_43parse_efc6cae9b2a58279_CharacterizationTestfMu_ {
    @Test("parse characterization")
    static func run() async throws {
      _ = try await InvariantSwiftTesting.CharacterizationTestRuntime.run(
        name: "parse",
        fixture: "parser.json",
        inputs: [CharacterizationInput(id: "empty", value: "")],
        operation: { input in
          try parse(input)
        },
        sourceFile: "test.swift"
      )
    }
  }
  """

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
      parseSource,
      expandedSource: expectedParseExpansion
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

  @Test("CharacterizationTest rejects zero parameters at parameter clauses")
  func rejectsZeroParameters() {
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
  }

  @Test("CharacterizationTest rejects two parameters at parameter clauses")
  func rejectsTwoParameters() {
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
