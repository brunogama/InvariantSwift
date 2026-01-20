---
id: S033
title: Replace placeholder Shrink.flatMap with ShrinkTree-based implementation
epic: E002
priority: P1
status: todo
dependencies: [S030]
---

## Scope
Implement dependent shrinking where child shrinks are composed deterministically.

## Acceptance criteria
- `Shrink.flatMap` is either removed or implemented with tests.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
