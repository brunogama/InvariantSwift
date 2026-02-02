# Spec Delta — pbt-core

## ADDED Requirements

### Requirement: CORE-PAR-001 — Deterministic parallelism
With the same seed/config, parallel runs MUST produce identical results to serial runs.

#### Scenario: Parallel equals serial
- **Given:** a property and fixed seed
- **When:** run with parallelism 1 vs 4
- **Then:** the minimal counterexample and replay token are identical
