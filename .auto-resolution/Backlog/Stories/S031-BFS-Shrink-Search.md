---
id: S031
title: Replace greedy-first shrinking with BFS shrink search
epic: E002
priority: P0
status: todo
dependencies: [S030]
---

## Scope
- Update the shrink loop to BFS (or best-first) over ShrinkTree.

## Acceptance criteria
- For a known property, BFS finds a smaller counterexample than greedy-first.
- Search is deterministic across runs.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`

## Tests to add
- Regression test covering minimal shrink.
