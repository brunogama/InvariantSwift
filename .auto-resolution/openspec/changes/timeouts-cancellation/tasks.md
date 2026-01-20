# Tasks

- [ ] Add PropertyConfig.timeout and RunnerConfig.globalTimeout
- [ ] Implement timeout enforcement for async predicates (Task + clock) with FailureReason.timedOut
- [ ] Implement cancellation propagation and deterministic cancellation outcome
- [ ] Ensure shrinking obeys remaining time budget (stop shrink search when exhausted)
- [ ] Add tests for timeout and cancellation behavior
