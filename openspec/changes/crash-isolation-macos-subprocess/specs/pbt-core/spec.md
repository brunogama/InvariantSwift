# Spec Delta — pbt-core

## ADDED Requirements

### Requirement: CORE-CRASH-001 — Crash isolation
When isolation is enabled, crashes MUST not terminate the parent test process.

#### Scenario: fatalError isolated
- **Given:** a property that triggers fatalError
- **When:** run with isolation enabled
- **Then:** the run reports failure and the test process remains alive
