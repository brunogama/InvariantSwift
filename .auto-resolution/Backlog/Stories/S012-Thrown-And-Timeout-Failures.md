---
id: S012
title: Support thrown errors and timeouts as failure reasons
epic: E001
priority: P1
status: todo
dependencies: [S010]
---

## Scope
- Change predicate type from `(T) -> Bool` to `(T) throws -> Bool`.
- Add an async runner variant that supports `(T) async throws -> Bool`.
- Implement failure classification:
  - `.threwError(error)`
  - `.timedOut(duration)` (if timeout configured)

## Acceptance criteria
- Thrown errors are reported with replay token and shrunk counterexample.
- Timeout returns `.failure` with `.timedOut`.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- `Sources/InvariantSwift/Core/IsolatedPropertyRunner.swift` (align APIs)

## Tests to add
- Property predicate throws => `.failure(reason: .threwError)`.
