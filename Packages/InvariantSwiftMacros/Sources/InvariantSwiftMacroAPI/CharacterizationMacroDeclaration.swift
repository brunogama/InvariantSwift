import InvariantSwift
import InvariantSwiftAdvanced
import InvariantSwiftCore

/// Captures and verifies current behavior for explicit Codable inputs.
///
/// The generated Swift Testing wrapper delegates execution to `characterize`.
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
@attached(peer, names: suffixed(_CharacterizationTest))
public macro CharacterizationTest(
  fixture: String,
  inputs: Any
) = #externalMacro(module: "InvariantSwiftMacros", type: "CharacterizationTestMacro")
