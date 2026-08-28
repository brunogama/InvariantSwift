import InvariantSwift
import InvariantSwiftAdvanced
import InvariantSwiftCore

/// Captures and verifies current behavior for explicit Codable inputs.
///
/// The generated Swift Testing wrapper delegates execution to
/// `InvariantSwiftTesting.CharacterizationTestRuntime`.
/// Use the record mode command to create or update the checked-in JSON fixture.
///
/// ```swift
/// @CharacterizationTest(
///   fixture: "Tests/ParserTests/Fixtures/Characterization",
///   inputs: [CharacterizationInput(id: "empty", value: "")]
/// )
/// func parser(_ input: String) throws -> Int {
///   input.count
/// }
/// ```
@attached(peer)
public macro CharacterizationTest<C>(
  fixture: String,
  inputs: C
) = #externalMacro(module: "InvariantSwiftMacros", type: "CharacterizationTestMacro")
where C: Collection & Sendable, C.Element: Codable & Sendable
