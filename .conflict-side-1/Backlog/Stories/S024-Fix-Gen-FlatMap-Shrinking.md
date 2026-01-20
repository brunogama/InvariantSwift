---
id: S024
title: Fix `Gen.flatMap` shrinking for dependent generators
epic: E002
priority: P0
status: todo
dependencies: [S020, S021]
---

## Problem
`Gen.flatMap` currently relies on placeholder shrinking, so dependent generators do not shrink.

## Scope
- Build dependent shrink trees:
  - shrink the outer value
  - for each outer value candidate, rebuild the inner generator and shrink the resulting inner value
- Ensure determinism (stable ordering).

## Acceptance criteria
- A property using `flatMap` produces a shrunk counterexample.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
- `Tests/FunctionalTesting/*`
