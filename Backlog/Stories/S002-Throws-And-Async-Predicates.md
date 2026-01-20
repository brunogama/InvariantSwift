---
id: S002
epic: E001
status: done
owner: llm
depends_on: [S001]
---

# S002: Support throwing and async predicates

## Problem
Failure reasons include `threwError` and timeout, but predicate signature is `(T) -> Bool`.

## Scope
- Introduce predicate variants:
  - sync throws
  - async throws
- Update runner to handle both.

## Acceptance criteria
- Public API allows defining properties with `throws` predicates.
- Runner catches thrown errors and returns `.failure(reason: .threwError(...))`.
- Async variant runs under Swift concurrency (no blocking).
- Existing sync non-throwing call sites still compile (via overloads).

## Files
- `Sources/InvariantSwift/Core/Property.swift`
- `Sources/InvariantSwift/Core/IsolatedPropertyRunner.swift`
- Add tests covering throw path.
