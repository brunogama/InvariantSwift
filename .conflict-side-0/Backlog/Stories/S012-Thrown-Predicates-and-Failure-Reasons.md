---
id: S012
title: Support thrown predicates and report `.threwError`
epic: E001
priority: P1
status: todo
dependencies: [S010]
---

## Problem
`FailureReason.threwError` exists but the main predicate signature cannot throw.

## Scope
- Update property predicate to `(T) throws -> Bool`.
- In the runner, catch errors and return `.failure(reason: .threwError(...))` including the replay token.

## Acceptance criteria
- A predicate that throws is reported as threwError, not predicateFailed.
- Shrinking is not attempted for thrown errors (unless you can justify safe semantics).

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- Any call sites / macros generating predicates

## Tests to add
- `Tests/FunctionalTesting/ThrownPredicateTests.swift`
