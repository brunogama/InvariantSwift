# Delta for Replay

## ADDED Requirements

### Requirement: Replay Token Is Emitted on Failure
When a property fails, the system MUST emit a replay token that is sufficient to reproduce the failure.

#### Scenario: Failure output includes replay token
- GIVEN a property that fails
- WHEN the run completes
- THEN the failure output includes a replay token string

### Requirement: Replay Token Can Be Consumed
The system MUST provide an API to rerun a property using a replay token.

#### Scenario: Rerun fails again
- GIVEN a replay token from a failing run
- WHEN rerunning using that token
- THEN the property fails with the same minimal counterexample
