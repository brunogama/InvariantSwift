# Spec Delta — pbt-generators

## ADDED Requirements

### Requirement: GEN-FLOAT-001 — Finite by default
Default Float/Double generators MUST produce finite values only.

#### Scenario: No NaN/inf by default
- **Given:** default Double generator
- **When:** sampling many values
- **Then:** no values are NaN or infinity

### Requirement: SHRINK-FLOAT-001 — Converges to zero
Float/Double shrinkers MUST be deterministic and converge toward 0.

#### Scenario: Shrinks toward 0
- **Given:** a failing value 12345.678
- **When:** shrinking runs
- **Then:** candidates monotonically approach 0 (in magnitude)
