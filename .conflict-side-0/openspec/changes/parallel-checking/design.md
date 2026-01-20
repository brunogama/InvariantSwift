# Design

## Key decisions
- Parallelism affects generation/evaluation only; shrinking stays serial
- Determinism definition: minimal counterexample + replay token must match serial

## Open questions
- Should parallelism be disabled by default on iOS to reduce noise?
