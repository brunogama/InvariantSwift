# Delta for PBT Generators

## MODIFIED Requirements

### Requirement: suchThat is safe
`suchThat` MUST not return a value that violates its predicate.

#### Scenario: suchThat gives up
- GIVEN a predicate that rejects all values
- WHEN generating
- THEN the result MUST be a discard/give-up outcome, not an invalid value
