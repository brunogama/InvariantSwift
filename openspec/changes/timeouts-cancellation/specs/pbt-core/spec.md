# Spec Delta — pbt-core

## ADDED Requirements

### Requirement: CORE-TIME-001 — Timeout support
The framework MUST support timeouts for async predicate evaluation.

#### Scenario: Timeout triggers
- **Given:** an async predicate that never completes
- **When:** run with a 50ms timeout
- **Then:** the run fails with reason `timedOut`

### Requirement: CORE-CANCEL-001 — Cancellation
The framework MUST support cooperative cancellation and report cancellation deterministically.

#### Scenario: Cancelled run ends
- **Given:** a long-running property check
- **When:** the caller cancels the task
- **Then:** the run terminates and reports cancellation
