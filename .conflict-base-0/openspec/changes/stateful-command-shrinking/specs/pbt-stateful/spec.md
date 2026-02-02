# Spec Delta — pbt-stateful

## ADDED Requirements

### Requirement: STATE-SEQ-001 — Sequence minimization
Stateful testing MUST shrink failing command sequences to a minimal reproducer.

#### Scenario: Minimize command sequence
- **Given:** a failing sequence of many commands
- **When:** shrinking runs
- **Then:** a much smaller failing sequence is produced
