# Spec Delta — pbt-shrinking

## ADDED Requirements

### Requirement: SHRINK-COLL-001 — Chunk removal first
Collection shrinkers MUST attempt chunk deletion before element-wise shrinking.

#### Scenario: Array deletion minimizes
- **Given:** a failing array case
- **When:** shrinking runs
- **Then:** the minimal array is achieved primarily via deletions when possible
