# Tasks

## Implementation
- [ ] 1. Introduce `PropertyContext` (or extend existing) to collect `classify` and `cover` events per evaluation
- [ ] 2. Aggregate classification counts in the runner and include them in final report output
- [ ] 3. Implement `cover(minPercent:label:condition:)` with optional `strictCoverage` config
- [ ] 4. Add tests: classification counts, cover thresholds, deterministic output ordering

## Validation
- [ ] Run unit tests for affected targets
- [ ] Add/adjust tests to cover new requirements and scenarios
- [ ] Ensure failure output includes replay token when applicable
