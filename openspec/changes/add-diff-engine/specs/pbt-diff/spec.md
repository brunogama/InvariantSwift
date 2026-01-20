# Capability: pbt-diff

## ADDED Requirements
### Requirement: Stable diff output
Diff output MUST be deterministic and MUST not depend on terminal capabilities by default.

#### Scenario: Deterministic diff
Given two equal pairs of values across runs
When diff is generated
Then the diff text MUST be identical.

### Requirement: Collection diff clarity
For arrays, diffs MUST indicate the first mismatch index and show expected vs actual at that index.

#### Scenario: Array mismatch
Given two arrays differing at index i
When diff is generated
Then the output MUST include i and the differing elements.
