import Foundation
import Testing

@Suite("Characterization Macro Compile Tests")
struct CharacterizationMacroCompileTests {
  @Test("typed characterization forms compile in a separate module")
  func validTypedFormsCompile() throws {
    let package = try MacroRuntimeFixtureSupport.makePackage(source: validFixtureSource())
    defer { try? FileManager.default.removeItem(at: package.directory) }

    let result = try MacroRuntimeFixtureSupport.buildTests(in: package)
    #expect(result.terminationStatus == 0, Comment(rawValue: result.output))
  }

  @Test("scalar and invalid element constraints are compiler-owned")
  func invalidDeclarationInputsFailCompilation() throws {
    let package = try MacroRuntimeFixtureSupport.makePackage(
      source: invalidDeclarationFixtureSource()
    )
    defer { try? FileManager.default.removeItem(at: package.directory) }

    let result = try MacroRuntimeFixtureSupport.buildTests(in: package)
    #expect(result.terminationStatus != 0, "Invalid macro arguments should not compile")
    #expect(result.output.contains("ScalarInput"), Comment(rawValue: result.output))
    #expect(result.output.contains("ReferenceInput"), Comment(rawValue: result.output))
    #expect(result.output.contains("NonCodableInput"), Comment(rawValue: result.output))
  }

  @Test("carrier and function input mismatch is compiler-owned")
  func mismatchedCarrierFailsCompilation() throws {
    let package = try MacroRuntimeFixtureSupport.makePackage(source: mismatchFixtureSource())
    defer { try? FileManager.default.removeItem(at: package.directory) }

    let result = try MacroRuntimeFixtureSupport.buildTests(in: package)
    #expect(result.terminationStatus != 0, "Mismatched generated runtime call should not compile")
    #expect(result.output.contains("MismatchInput"), Comment(rawValue: result.output))
  }
}

private extension CharacterizationMacroCompileTests {
  func validFixtureSource() -> String {
    """
    import InvariantSwiftMacroAPI
    import InvariantSwiftTesting
    import Testing

    struct CompileInput: Codable, Sendable {
      let value: Int
    }

    enum CompileFailure: Error {
      case sample
    }

    let typedInputs = [
      CharacterizationInput(id: "one", value: CompileInput(value: 1))
    ]
    let typedEmptyInputs: [CharacterizationInput<CompileInput>] = []

    @CharacterizationTest(fixture: "sync.json", inputs: typedInputs)
    func syncFixture(_ input: CompileInput) -> Int {
      input.value
    }

    @CharacterizationTest(fixture: "async.json", inputs: typedEmptyInputs)
    func asyncThrowingFixture(_ input: CompileInput) async throws -> String {
      if input.value < 0 { throw CompileFailure.sample }
      return String(input.value)
    }

    @CharacterizationTest(fixture: "labeled.json", inputs: typedInputs)
    func labeledFixture(value input: CompileInput) throws -> Int {
      input.value
    }

    @CharacterizationTest(fixture: "overload-int.json", inputs: typedInputs)
    func overloadedFixture(_ input: CompileInput) -> Int {
      input.value
    }

    @CharacterizationTest(fixture: "overload-string.json", inputs: typedEmptyInputs)
    func overloadedFixture(value input: CompileInput) async -> String {
      String(input.value)
    }
    """
  }

  func invalidDeclarationFixtureSource() -> String {
    """
    import InvariantSwiftMacroAPI
    import InvariantSwiftTesting

    final class ReferenceInput: Codable {
      let value: Int

      init(value: Int) {
        self.value = value
      }
    }

    struct NonCodableInput: Sendable {
      let value: Int
    }

    @CharacterizationTest(fixture: "scalar.json", inputs: 1)
    func ScalarInput(_ input: Int) -> Int { input }

    @CharacterizationTest(
      fixture: "non-sendable.json",
      inputs: [ReferenceInput(value: 1)]
    )
    func ReferenceInputFixture(_ input: ReferenceInput) -> Int { input.value }

    @CharacterizationTest(
      fixture: "non-codable.json",
      inputs: [NonCodableInput(value: 1)]
    )
    func NonCodableInputFixture(_ input: NonCodableInput) -> Int { input.value }
    """
  }

  func mismatchFixtureSource() -> String {
    """
    import InvariantSwiftMacroAPI
    import InvariantSwiftTesting

    let mismatchedInputs = [CharacterizationInput(id: "text", value: "value")]

    @CharacterizationTest(fixture: "mismatch.json", inputs: mismatchedInputs)
    func MismatchInput(_ input: Int) -> Int { input }
    """
  }
}
