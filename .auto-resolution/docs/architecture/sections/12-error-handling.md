# Error Handling

### 12.1 Error Philosophy

Errors surface at appropriate layers:
- **Compile-time** (macros): Invalid syntax, missing generators
- **Runtime** (property execution): Predicate failures, timeouts
- **Result reporting**: Shrunk counterexamples, coverage gaps

### 12.2 Error Categories

| Category | Mechanism | Retry | User Message |
|----------|-----------|-------|--------------|
| Compilation | Macro diagnostics | No | "Macro expansion failed: [reason]" |
| Predicate Failure | PropertyResult.failure | No | "Property failed: [counterexample]" |
| Timeout | Interrupt + partial result | No | "Test timeout after [duration]" |
| Gave Up | Excessive discards | No | "Test gave up: [discarded]/[iterations]" |
| Generator Error | Optional wrapping | No | "Failed to generate value of type [T]" |

### 12.3 Retry Strategy

- **Max Retries**: 0 (deterministic with seed; no transient failures)
- **Backoff**: N/A
- **Jitter**: N/A

### 12.4 Circuit Breaker

Not applicable (single-threaded generation)

---
