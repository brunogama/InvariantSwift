# Arbitrary Macro Capability

## ADDED Requirements

### Requirement: Arbitrary Macro Declaration
The system SHALL provide an `@Arbitrary` macro that automatically derives `Gen<T>` and `Shrink<T>` for custom types.

#### Scenario: Basic struct derivation
- **GIVEN** a struct annotated with `@Arbitrary`
- **WHEN** the macro expands
- **THEN** it SHALL generate an extension conforming to `Generatable`
- **AND** provide a static `arbitrary: Gen<T>` property
- **AND** provide a static `shrink: Shrink<T>` property

#### Scenario: Enum derivation
- **GIVEN** an enum annotated with `@Arbitrary`
- **WHEN** the macro expands
- **THEN** it SHALL generate `Gen.oneOf([...])` covering all cases
- **AND** handle associated values correctly

### Requirement: Arbitrary Macro Parameters
The `@Arbitrary` macro SHALL accept the following optional parameters:
- `shrink: ShrinkStrategy` (default: `.automatic`) - Shrinking behavior
- `constraints: [String: String]` (default: `[:]`) - Field constraints

#### Scenario: Shrink strategy automatic
- **GIVEN** `@Arbitrary` or `@Arbitrary(shrink: .automatic)`
- **WHEN** the macro expands
- **THEN** shrinking SHALL be derived from field types

#### Scenario: Shrink strategy towards
- **GIVEN** `@Arbitrary(shrink: .towards(User(name: "", age: 0)))`
- **WHEN** the macro expands
- **THEN** shrinking SHALL tend towards the specified value

#### Scenario: Shrink strategy none
- **GIVEN** `@Arbitrary(shrink: .none)`
- **WHEN** the macro expands
- **THEN** no shrinking SHALL be provided (`.empty`)

### Requirement: Struct Generation
The `@Arbitrary` macro SHALL generate correct generators for structs.

#### Scenario: Simple struct with primitives
- **GIVEN** struct with fields `name: String`, `age: Int`
- **WHEN** the macro expands
- **THEN** it SHALL generate `Gen.zip(Gen<String>.string, Gen<Int>.int).map { ... }`

#### Scenario: Struct with optional field
- **GIVEN** struct with field `email: String?`
- **WHEN** the macro expands
- **THEN** it SHALL generate `Gen.optional(Gen<String>.string)` for that field

#### Scenario: Struct with collection field
- **GIVEN** struct with field `tags: [String]`
- **WHEN** the macro expands
- **THEN** it SHALL generate `Gen.array(Gen<String>.string)` for that field

#### Scenario: Struct with nested custom type
- **GIVEN** struct with field `address: Address` where `Address` has `@Arbitrary`
- **WHEN** the macro expands
- **THEN** it SHALL generate `Address.arbitrary` for that field

### Requirement: Enum Generation
The `@Arbitrary` macro SHALL generate correct generators for enums.

#### Scenario: Simple enum without associated values
- **GIVEN** enum with cases `case a, b, c`
- **WHEN** the macro expands
- **THEN** it SHALL generate `Gen.oneOf([Gen.pure(.a), Gen.pure(.b), Gen.pure(.c)])`

#### Scenario: Enum with associated values
- **GIVEN** enum case `case creditCard(number: String, cvv: String)`
- **WHEN** the macro expands
- **THEN** it SHALL generate `Gen.zip(Gen<String>.string, Gen<String>.string).map { .creditCard(number: $0, cvv: $1) }`

#### Scenario: Mixed enum cases
- **GIVEN** enum with `case cash` and `case card(number: String)`
- **WHEN** the macro expands
- **THEN** it SHALL generate `Gen.oneOf([Gen.pure(.cash), Gen<String>.string.map { .card(number: $0) }])`

### Requirement: Shrinking Derivation
The `@Arbitrary` macro SHALL derive shrinking strategies automatically by default.

#### Scenario: Struct field shrinking
- **GIVEN** struct with field `age: Int`
- **WHEN** shrinking is derived
- **THEN** it SHALL shrink `age` using `Gen<Int>.int.shrink`
- **AND** produce candidates with each field shrunk independently

#### Scenario: Composite shrinking
- **GIVEN** struct with multiple fields
- **WHEN** a counterexample needs shrinking
- **THEN** it SHALL try shrinking each field independently
- **AND** return all candidate shrunk values

### Requirement: Field Constraints
The `@Arbitrary` macro SHALL support field-level constraints.

#### Scenario: Age constraint
- **GIVEN** `@Arbitrary(constraints: ["age": "0...120"])`
- **WHEN** the macro expands
- **THEN** age generator SHALL be `Gen<Int>.int(in: 0...120)`

#### Scenario: Non-empty string constraint
- **GIVEN** `@Arbitrary(constraints: ["name": "nonEmpty"])`
- **WHEN** the macro expands
- **THEN** name generator SHALL be `Gen<String>.string.suchThat { !$0.isEmpty }`

### Requirement: Arbitrary Diagnostic Messages
The `@Arbitrary` macro SHALL emit clear diagnostics for invalid usage.

#### Scenario: Applied to class
- **GIVEN** `@Arbitrary` applied to a class
- **WHEN** the macro attempts to expand
- **THEN** it SHALL emit error: "@Arbitrary can only be applied to structs or enums"

#### Scenario: No stored properties
- **GIVEN** `@Arbitrary` applied to struct with only computed properties
- **WHEN** the macro attempts to expand
- **THEN** it SHALL emit error: "@Arbitrary requires at least one stored property"

#### Scenario: Unknown field in constraints
- **GIVEN** `@Arbitrary(constraints: ["nonexistent": "..."])`
- **WHEN** the macro attempts to expand
- **THEN** it SHALL emit warning: "Constraint for unknown field 'nonexistent'"

### Requirement: SwiftSyntax Builder Usage
The `@Arbitrary` macro SHALL generate all code using pure SwiftSyntax builders.

#### Scenario: Extension generation
- **WHEN** generating the `Generatable` extension
- **THEN** it SHALL use `ExtensionDeclSyntax` builder
- **AND** NOT use string interpolation

#### Scenario: Generator property generation
- **WHEN** generating the `arbitrary` property
- **THEN** it SHALL use `VariableDeclSyntax` with computed property pattern
- **AND** build the body using `FunctionCallExprSyntax` for `Gen.zip`, etc.
