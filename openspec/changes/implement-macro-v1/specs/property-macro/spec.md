# Property Macro Capability

## ADDED Requirements

### Requirement: Property Macro Declaration
The system SHALL provide a `@Property` macro that transforms functions into property-based tests with automatic generator inference.

#### Scenario: Minimal usage with type inference
- **GIVEN** a function annotated with `@Test @Property`
- **WHEN** the function has typed parameters (e.g., `a: Int, b: String`)
- **THEN** the macro SHALL infer appropriate generators for each parameter type
- **AND** generate a Swift Testing compatible test function

#### Scenario: Usage with configuration
- **GIVEN** a function annotated with `@Property(iterations: 500, seed: 12345)`
- **WHEN** the macro expands
- **THEN** the generated test SHALL use the specified iteration count
- **AND** use the specified seed for deterministic generation

### Requirement: Property Macro Parameters
The `@Property` macro SHALL accept the following optional parameters:
- `iterations: Int` (default: 100) - Number of test iterations
- `seed: UInt64?` (default: nil) - Seed for deterministic RNG
- `maxShrinks: Int` (default: 1000) - Maximum shrinking attempts
- `verbose: Bool` (default: false) - Enable verbose output

#### Scenario: Default configuration
- **GIVEN** `@Property` with no arguments
- **WHEN** the macro expands
- **THEN** iterations SHALL default to 100
- **AND** maxShrinks SHALL default to 1000
- **AND** seed SHALL be nil (random)
- **AND** verbose SHALL be false

### Requirement: Property Macro Expansion Pattern
The `@Property` macro SHALL generate code using pure SwiftSyntax AST builders (NEVER raw string interpolation).

#### Scenario: Expansion structure
- **GIVEN** a function `func testAdd(a: Int, b: Int) { #expect(a + b == b + a) }`
- **WHEN** annotated with `@Test @Property`
- **THEN** the expansion SHALL create a peer function with `_PropertyTest` suffix
- **AND** the peer function SHALL be annotated with `@Test`
- **AND** the body SHALL contain generator creation, property creation, execution, and result handling

#### Scenario: SwiftSyntax builder usage
- **WHEN** the macro generates code
- **THEN** it SHALL use `FunctionDeclSyntax`, `VariableDeclSyntax`, etc.
- **AND** it SHALL NOT use `DeclSyntax(stringLiteral:)` or string interpolation

### Requirement: Generator Inference
The `@Property` macro SHALL automatically infer generators for parameters based on their types.

#### Scenario: Primitive type inference
- **GIVEN** parameter types `Int`, `String`, `Bool`, `Double`
- **WHEN** no explicit `@Gen` annotation is present
- **THEN** the macro SHALL infer `Gen<Int>.int`, `Gen<String>.string`, `Gen<Bool>.bool`, `Gen<Double>.double` respectively

#### Scenario: Collection type inference
- **GIVEN** parameter type `[Int]` or `Array<Int>`
- **WHEN** no explicit `@Gen` annotation is present
- **THEN** the macro SHALL infer `Gen.array(Gen<Int>.int)`

#### Scenario: Optional type inference
- **GIVEN** parameter type `String?` or `Optional<String>`
- **WHEN** no explicit `@Gen` annotation is present
- **THEN** the macro SHALL infer `Gen.optional(Gen<String>.string)`

#### Scenario: Custom type inference
- **GIVEN** parameter type `User` (a custom type)
- **WHEN** no explicit `@Gen` annotation is present
- **THEN** the macro SHALL infer `User.arbitrary`
- **AND** emit a diagnostic if `User` does not conform to `Generatable`

### Requirement: Result Handling
The expanded property test SHALL handle all possible `PropertyResult` cases.

#### Scenario: Success case
- **GIVEN** property test passes all iterations
- **WHEN** result is `.success`
- **THEN** the test SHALL complete without error

#### Scenario: Failure case
- **GIVEN** property test finds a counterexample
- **WHEN** result is `.failure(counterexample:iterations:shrunk:)`
- **THEN** the test SHALL call `Issue.record()` with formatted failure message
- **AND** include the shrunk counterexample in the message
- **AND** include the seed for reproduction

#### Scenario: GaveUp case
- **GIVEN** property test discards too many values
- **WHEN** result is `.gaveUp(discarded:iterations:)`
- **THEN** the test SHALL call `Issue.record()` with appropriate message

### Requirement: #expect Passthrough
The `@Property` macro SHALL preserve `#expect` assertions in the test body.

#### Scenario: Single expect
- **GIVEN** function body contains `#expect(a + b == b + a)`
- **WHEN** the macro expands
- **THEN** the closure body SHALL contain the original `#expect` call

#### Scenario: Multiple expects
- **GIVEN** function body contains multiple `#expect` calls
- **WHEN** the macro expands
- **THEN** all `#expect` calls SHALL be preserved in order

### Requirement: Diagnostic Messages
The `@Property` macro SHALL emit clear diagnostic messages for invalid usage.

#### Scenario: Applied to non-function
- **GIVEN** `@Property` applied to a struct or variable
- **WHEN** the macro attempts to expand
- **THEN** it SHALL emit error: "@Property can only be applied to functions"

#### Scenario: No parameters
- **GIVEN** `@Property` applied to a parameterless function
- **WHEN** the macro attempts to expand
- **THEN** it SHALL emit error: "@Property requires at least one parameter to generate test values"

#### Scenario: Cannot infer generator
- **GIVEN** parameter type has no known generator and no `@Arbitrary` conformance
- **WHEN** the macro attempts to expand
- **THEN** it SHALL emit error: "Cannot infer generator for type 'X'. Add @Arbitrary to X or use @Gen explicitly."
