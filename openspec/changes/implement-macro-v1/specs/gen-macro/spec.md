# Gen Macro Capability

## ADDED Requirements

### Requirement: Gen Parameter Attribute
The system SHALL provide a `@Gen` parameter attribute macro that specifies an explicit generator for a function parameter.

#### Scenario: Override type inference
- **GIVEN** a parameter `@Gen(.int(in: 1...100)) x: Int`
- **WHEN** used with `@Property`
- **THEN** the property macro SHALL use the explicit generator instead of type inference

#### Scenario: Marker attribute behavior
- **GIVEN** `@Gen` applied to a parameter
- **WHEN** the `@Gen` macro itself expands
- **THEN** it SHALL produce no additional declarations (marker only)

### Requirement: Generator DSL - Primitives
The `@Gen` DSL SHALL support the following primitive generator expressions:

#### Scenario: Integer generators
- **GIVEN** `@Gen(.int)` - full range Int
- **AND** `@Gen(.int(in: 0...100))` - bounded range
- **AND** `@Gen(.int(.positive))` - positive only
- **AND** `@Gen(.int(.negative))` - negative only  
- **AND** `@Gen(.int(.nonZero))` - non-zero
- **WHEN** parsed by GeneratorDSL
- **THEN** each SHALL generate the corresponding `Gen<Int>` expression

#### Scenario: String generators
- **GIVEN** `@Gen(.string)` - default alphanumeric
- **AND** `@Gen(.string(length: 1...20))` - with length bounds
- **AND** `@Gen(.string(.ascii))` - ASCII only
- **AND** `@Gen(.string(.alphanumeric))` - letters and digits
- **AND** `@Gen(.string(.email))` - email format
- **AND** `@Gen(.string(.uuid))` - UUID format
- **WHEN** parsed by GeneratorDSL
- **THEN** each SHALL generate the corresponding `Gen<String>` expression

#### Scenario: Other primitive generators
- **GIVEN** `@Gen(.bool)` - boolean
- **AND** `@Gen(.double)` - full range double
- **AND** `@Gen(.double(in: 0.0...1.0))` - bounded double
- **AND** `@Gen(.float)` - float
- **AND** `@Gen(.uuid)` - UUID
- **AND** `@Gen(.date)` - Date
- **AND** `@Gen(.data)` - Data
- **AND** `@Gen(.url)` - URL
- **AND** `@Gen(.character)` - Character
- **WHEN** parsed by GeneratorDSL
- **THEN** each SHALL generate the appropriate generator expression

### Requirement: Generator DSL - Collections
The `@Gen` DSL SHALL support collection generator expressions.

#### Scenario: Array generators
- **GIVEN** `@Gen(.array(of: .int))` - variable length
- **AND** `@Gen(.array(of: .int, count: 5))` - fixed length
- **AND** `@Gen(.array(of: .int, count: 1...10))` - range length
- **WHEN** parsed by GeneratorDSL
- **THEN** each SHALL generate the corresponding `Gen.array(...)` expression

#### Scenario: Set generator
- **GIVEN** `@Gen(.set(of: .int))`
- **WHEN** parsed by GeneratorDSL
- **THEN** it SHALL generate `Gen.set(Gen<Int>.int)`

#### Scenario: Dictionary generator
- **GIVEN** `@Gen(.dictionary(keys: .string, values: .int))`
- **WHEN** parsed by GeneratorDSL
- **THEN** it SHALL generate `Gen.dictionary(Gen<String>.string, Gen<Int>.int)`

### Requirement: Generator DSL - Optionals
The `@Gen` DSL SHALL support optional generator expressions.

#### Scenario: Optional generators
- **GIVEN** `@Gen(.optional(.string))` - Some or None
- **AND** `@Gen(.some(.string))` - always Some
- **AND** `@Gen(.none)` - always nil
- **WHEN** parsed by GeneratorDSL
- **THEN** each SHALL generate the corresponding optional generator

### Requirement: Generator DSL - Combinators
The `@Gen` DSL SHALL support combinator generator expressions.

#### Scenario: OneOf combinator
- **GIVEN** `@Gen(.oneOf([.int(.positive), .int(.negative)]))`
- **WHEN** parsed by GeneratorDSL
- **THEN** it SHALL generate `Gen.oneOf([Gen<Int>.positiveInt, Gen<Int>.negativeInt])`

#### Scenario: Frequency combinator
- **GIVEN** `@Gen(.frequency([(3, .int(.positive)), (1, .int(.negative))]))`
- **WHEN** parsed by GeneratorDSL
- **THEN** it SHALL generate `Gen.frequency([(3, Gen<Int>.positiveInt), (1, Gen<Int>.negativeInt)])`

### Requirement: Generator DSL - Custom
The `@Gen` DSL SHALL support custom generator expressions.

#### Scenario: Custom closure generator
- **GIVEN** `@Gen(.custom { rng, size in ... })`
- **WHEN** parsed by GeneratorDSL
- **THEN** it SHALL wrap the closure in a `Gen(...)` initializer

### Requirement: Gen DSL Parsing
The GeneratorDSL parser SHALL handle all supported expressions.

#### Scenario: Member access parsing
- **GIVEN** expressions like `.int`, `.string`, `.bool`
- **WHEN** parsed as MemberAccessExprSyntax
- **THEN** the parser SHALL recognize the generator type

#### Scenario: Function call parsing
- **GIVEN** expressions like `.int(in: 0...100)`, `.array(of: .int)`
- **WHEN** parsed as FunctionCallExprSyntax
- **THEN** the parser SHALL extract labeled arguments correctly

#### Scenario: Invalid expression
- **GIVEN** an unrecognized expression in `@Gen`
- **WHEN** the parser attempts to parse
- **THEN** it SHALL emit diagnostic: "@Gen requires a valid generator expression"

### Requirement: Gen DSL Code Generation
The GeneratorDSL SHALL generate SwiftSyntax expressions for all parsed generators.

#### Scenario: Code generation uses builders
- **WHEN** generating code for a parsed generator
- **THEN** it SHALL use `FunctionCallExprSyntax`, `MemberAccessExprSyntax`, etc.
- **AND** it SHALL NOT use string interpolation
