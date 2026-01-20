# Capability: pbt-macros

## ADDED Requirements
### Requirement: Macro expansions are tested
Macro expansions MUST be covered by automated tests to prevent accidental semantic drift.

#### Scenario: PropertyTest expansion fixture
Given a source file using `@PropertyTest`
When macro expansion tests run
Then the expanded output MUST match the approved fixture (or AST-equivalent).
