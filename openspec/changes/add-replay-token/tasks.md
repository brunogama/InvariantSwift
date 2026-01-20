## 1. Define replay token format
- [ ] 1.1 Decide encoding (JSON string, base64 JSON, or Swift literal)
- [ ] 1.2 Define fields: seed, iteration count, size schedule, minimal counterexample, optional shrink trace

## 2. Emit replay token on failure
- [ ] 2.1 Add replay data to `Failure`/result types
- [ ] 2.2 Update output formatting and macros to surface the token

## 3. Consume replay token
- [ ] 3.1 Add API to run a property from a replay token
- [ ] 3.2 Add tests for replay stability across runs within the same toolchain
