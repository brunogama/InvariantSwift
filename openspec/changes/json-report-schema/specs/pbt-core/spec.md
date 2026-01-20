# Spec Delta — pbt-core

## ADDED Requirements

### Requirement: CORE-REPORT-001 — JSON report output
The framework MUST be able to emit a versioned JSON report for each run.

#### Scenario: Report contains replay
- **Given:** a failing run
- **When:** a report is emitted
- **Then:** the report includes replay token and minimal counterexample representation
