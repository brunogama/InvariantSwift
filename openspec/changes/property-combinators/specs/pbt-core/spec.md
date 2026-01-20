# Spec Delta — pbt-core

## ADDED Requirements

### Requirement: CORE-COMB-001 — Combinator support
The framework MUST support and/or/implies combinators with defined discard behavior.

#### Scenario: Implication discards
- **Given:** A implies B
- **When:** A is false for an input
- **Then:** the input is discarded and does not count as a pass
