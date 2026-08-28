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

  @Test("CharacterizationTest generates a Swift Testing wrapper")
  func generatesWrapper() {
    assertMacroExpansion(
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

        private enum characterizeParser_CharacterizationTest {
          @Test("characterizeParser characterization")
          static func run() async throws {
            _ = try await characterize(
              CharacterizationConfiguration(
                name: "characterizeParser",
                fixture: "parser.json",
                inputs: [CharacterizationInput(id: "empty", value: "")],
              ),
              operation: { input in try characterizeParser(input) }
            )
          }
        }
        """,
      macros: ["CharacterizationTest": CharacterizationTestMacro.self],
      indentationWidth: .spaces(2)
    )
  }
}
