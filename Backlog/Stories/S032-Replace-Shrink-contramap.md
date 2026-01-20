---
id: S032
title: Replace placeholder Shrink.contramap with correct implementation
epic: E002
priority: P1
status: done
dependencies: [S030]
---

## Scope
Implement a correct adaptation strategy for shrinking mapped types.

## Notes
A pure `contramap (U -> T)` is not enough to construct shrunk `U` values without a way to build `U` from `T`. Provide one of:
- `dimap(to:from:)` with `(U)->T` and `(T)->U`
- remove `contramap` and rely on explicit shrinkers on `U`

## Acceptance criteria
- No implementation that returns the same `U` repeatedly.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
