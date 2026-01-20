---
id: S050
title: Provide a Swift Testing adapter with minimal counterexample output
epic: E006
priority: P1
status: done
dependencies: [S010, S021, S030]
---

## Goal
Properties should feel native inside Swift Testing and emit high-quality failures.

## Scope
- Add helper `PropertyTest.check(...)` that runs a property and uses Swift Testing failure APIs to emit:
  - minimal counterexample
  - replay token
  - discard count
- Ensure output is readable without ANSI escape sequences.

## Acceptance criteria
- In Swift Testing, a failing property produces a single failure message containing replay token.
- Works with async predicates if present.

## Files to touch
- `Sources/InvariantSwift/...` (adapter location)
- `Tests/FunctionalTesting/...`
