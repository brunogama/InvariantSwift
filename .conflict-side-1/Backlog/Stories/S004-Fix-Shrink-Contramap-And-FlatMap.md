---
id: S004
epic: E002
status: done
owner: llm
depends_on: [S003]
---

# S004: Fix `Shrink.contramap` and `Shrink.flatMap`

## Problem
`Shrink.contramap` and `Shrink.flatMap` are currently incorrect/stubbed.

## Scope
- Replace current implementations with correct semantics using a shrink tree or equivalent structure.

## Acceptance criteria
- `Shrink.contramap` produces shrunk `U` values (not the original input).
- `Shrink.flatMap` supports dependent shrinking and is exercised by `Gen.flatMap`.
- Add tests for a dependent generator where shrinking reduces both outer and inner values.

## Files
- `Sources/InvariantSwift/Core/Generator.swift`
- Tests in `Tests/FunctionalTesting`.
