---
id: S022
title: Replace placeholder `Shrink.contramap`
epic: E002
priority: P1
status: done
dependencies: [S020]
---

## Problem
Current `contramap` returns the same input repeatedly and does not shrink.

## Scope
- Either remove `contramap` until correct, or implement it correctly.
- A correct `contramap` needs a way to rebuild `U` from shrunk `T`. If you only have `(U) -> T`, you cannot produce new `U` values.

## Recommendation
- Remove `contramap` from public API, or change it to require a rebuild function:
  - `contramap(_ project: (U) -> T, rebuild: (U, T) -> U)`

## Acceptance criteria
- No placeholder behavior remains.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
