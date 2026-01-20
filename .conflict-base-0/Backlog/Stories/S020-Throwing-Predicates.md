---
id: S020
title: Support throwing predicates and failure reason propagation
epic: E001
priority: P1
status: done
dependencies: [S010]
---

## Scope
- Allow property predicates to throw.
- Runner catches errors and records `.threwError` with the error payload.

## Acceptance criteria
- A predicate that throws yields a failure with reason `threwError`.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- `Sources/InvariantSwift/Core/FailureReason.swift` (if separate)

## Tests to add
- Throwing predicate is captured and reported.
