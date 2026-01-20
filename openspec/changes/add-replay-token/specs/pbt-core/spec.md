# Delta for PBT Core

## MODIFIED Requirements

### Requirement: Runner Evaluates a Predicate
The system MUST evaluate a predicate over generated values for a configured number of iterations and MUST include seed and replay information in failure results.

#### Scenario: Failure includes seed and replay info
- GIVEN a failing property
- WHEN the runner returns a failure result
- THEN that result includes seed and replay token
