# Label Macro Capability

## ADDED Requirements

### Requirement: Label Parameter Attribute
The system SHALL provide a `@Label` parameter attribute macro that adds diagnostic labels to property test parameters.

#### Scenario: Basic label usage
- **GIVEN** a parameter `@Label("user age") age: Int`
- **WHEN** used with `@Property`
- **THEN** the label "user age" SHALL appear in failure messages instead of "age"

#### Scenario: Marker attribute behavior
- **GIVEN** `@Label` applied to a parameter
- **WHEN** the `@Label` macro itself expands
- **THEN** it SHALL produce no additional declarations (marker only)

### Requirement: Label Macro Parameter
The `@Label` macro SHALL accept a single string parameter.

#### Scenario: String literal label
- **GIVEN** `@Label("descriptive name")`
- **WHEN** parsed by the Property macro
- **THEN** it SHALL extract "descriptive name" as the label

### Requirement: Label Integration with Property Macro
The `@Property` macro SHALL read `@Label` attributes from parameters.

#### Scenario: Label extraction
- **GIVEN** function with `@Label("account balance") balance: Decimal`
- **WHEN** the `@Property` macro extracts parameters
- **THEN** it SHALL associate the label with the parameter

#### Scenario: Mixed labeled and unlabeled
- **GIVEN** function with labeled `@Label("x") a: Int` and unlabeled `b: Int`
- **WHEN** failure occurs
- **THEN** the message SHALL show "x = ..." for `a` and "b = ..." for `b`

### Requirement: Label in Failure Messages
Labels SHALL appear in property test failure messages.

#### Scenario: Failure message with labels
- **GIVEN** parameters with labels "user age" and "account balance"
- **WHEN** property test fails
- **THEN** the failure message SHALL include:
  ```
  Shrunk to minimal case:
     user age = 0
     account balance = -0.01
  ```

#### Scenario: Labels in verbose mode
- **GIVEN** `@Property(verbose: true)` with labeled parameters
- **WHEN** generating test values
- **THEN** verbose output SHALL use labels: "Generated user age = 25"

### Requirement: Label Diagnostic Messages
The `@Label` macro SHALL emit diagnostics for invalid usage.

#### Scenario: Empty label
- **GIVEN** `@Label("")`
- **WHEN** the macro is parsed
- **THEN** it SHALL emit warning: "@Label should not be empty"

#### Scenario: Non-string argument
- **GIVEN** `@Label(123)`
- **WHEN** the macro is parsed
- **THEN** it SHALL emit error: "@Label requires a string literal"
