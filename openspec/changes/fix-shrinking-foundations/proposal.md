# Proposal: Fix shrinking foundations (ShrinkTree + deterministic search)

## Summary
Replace the current ad-hoc shrinking (`Shrink` returning `[T]` + greedy search) with a shrink-tree abstraction and a deterministic search strategy that reliably finds minimal counterexamples.

## Why
Property-based testing is only as valuable as the failing examples it produces. Current greedy-first shrinking can miss truly minimal counterexamples, making failures harder to debug. Flat list-based shrinking (`Shrink<T>: (T) -> [T]`) cannot correctly represent dependent shrinking (e.g., array elements shrinking based on array length). A deterministic tree-based search guarantees reproducible shrinking results, essential for replay tokens. This proposal unifies the already-implemented `ShrinkTree` types into a canonical foundation, making shrinking correct, deterministic, and composable.

## Current State

### Status Quo
- **Shrink<T> API** (`Core/Generator.swift`): Flat list-based shrinking `(T) -> [T]`
  - `flatMap` and `contramap` are marked unavailable (mathematical impossibility for flat lists)
  - Greedy search in `PropertyRunner` can miss minimal cases
- **ShrinkTree<T>** (`Core/ShrinkTree.swift`): Already partially implemented
  - Lazy tree structure with `value: T` and `children: () -> [ShrinkTree<T>]`
  - Bridge from `Shrink<T>` via `ShrinkTree.from(_:shrink:)`
  - BFS-based `findMinimal` search
- **Advanced ShrinkTrees** (`Advanced/ShrinkTrees.swift`): Experimental tree-based generators
  - `Node<A>` and `TreeGen<A>` types (alternative naming)
  - Functor, monad, and combinator instances
  - Integration point: `ShrinkTreeRunner` for property testing

### Core Issues to Fix
1. **Dual tree implementations**: `ShrinkTree` vs `Node` need unification or clear responsibility separation
2. **Shrink<T> limitations**: Flat lists cannot represent dependent shrinking correctly
3. **Search strategy**: `PropertyRunner` uses greedy-first; needs BFS determinism
4. **Performance controls**: Tree explosion unchecked; needs `maxDepth` and `maxNodes` limits
5. **Property runner integration**: How to switch from `Shrink<T>` to `ShrinkTree<T>` without breaking existing code

## Goals
- **Unify shrink-tree types**: Single canonical tree abstraction (decide: `ShrinkTree` or `Node`)
- **Implement deterministic search**: BFS with stable ordering in `PropertyRunner`
- **Provide safety guards**: Depth/breadth caps to prevent pathological expansion
- **Maintain bridge API**: Keep `Shrink<T>` working for existing code; provide migration path
- **Full test coverage**: Determinism, termination, minimality for core types

## Non-Goals
- Coverage-guided generation (ISP-0007)
- Stateful/model-based testing (ISP-0008)
- Auto-generation of shrinkers via `@Arbitrary` macro
- Custom fingerprinting for memoization

## Risks
- **Performance regressions**: Shrink trees can be exponential; must cap depth/breadth
- **Binary compatibility**: Changing search strategy may alter reported counterexamples (desired, but needs careful docs)
- **Complexity explosion**: `Node<A>` and `TreeGen<A>` are already in codebase; unifying with `ShrinkTree` requires careful refactoring
- **Sendable constraints**: Lazy computation with `@Sendable` closures requires careful thread safety

## Definition of Success
- `ShrinkTree<T>` is the canonical shrink-tree type (all code uses it)
- `PropertyRunner` uses BFS with deterministic order and caps
- All core shrinkers (`Int`, `String`, `Array`, `Double`) produce correct trees
- Property tests replay shrink results deterministically
- No performance regression in common cases (benchmarks must pass)
