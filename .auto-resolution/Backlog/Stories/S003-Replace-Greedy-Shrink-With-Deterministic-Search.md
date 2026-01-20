---
id: S003
epic: E002
status: done
owner: llm
depends_on: [S002]
---

# S003: Replace greedy-first shrink with deterministic shrink search

## Problem
Greedy-first shrinking often yields non-minimal counterexamples and is hard to reason about.

## Scope
- Introduce a shrink search engine with a deterministic strategy (default BFS).

## Acceptance criteria
- Runner uses the new shrink search engine.
- Shrink path is deterministic for a given seed/counterexample.
- Tests demonstrate BFS finds a strictly smaller counterexample than greedy-first on a constructed example.

## Files
- `Sources/InvariantSwift/Core/Property.swift`
- (new) `Sources/InvariantSwift/Core/ShrinkSearch.swift`
- Tests under `Tests/FunctionalTesting`.
