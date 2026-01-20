---
id: S021
title: Replace greedy shrink with BFS shrink search
epic: E002
priority: P0
status: todo
dependencies: [S020]
---

## Problem
Greedy-first shrinking often stops at non-minimal counterexamples.

## Scope
- Implement `ShrinkSearch` (or helper) that traverses a `ShrinkTree` with BFS.
- Update `PropertyRunner` to use BFS search up to `maxShrinks` (interpret as node-visit budget).
- Ensure deterministic traversal order.

## Acceptance criteria
- Regression test shows BFS finds a smaller counterexample than greedy-first for a crafted generator.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- (new) `Sources/InvariantSwift/Core/ShrinkSearch.swift`

## Tests to add
- `Tests/FunctionalTesting/ShrinkSearchTests.swift`
