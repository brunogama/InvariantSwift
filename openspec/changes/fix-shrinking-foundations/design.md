# Design: ShrinkTree and shrink search

## Decisions
1. Shrinking is expressed as a tree, not just a flat list.
2. The shrink search uses BFS with deterministic ordering to improve minimality and reproducibility.

## Interface Sketch
- `struct ShrinkTree<T> { let value: T; let children: () -> [ShrinkTree<T>] }`
- `typealias Shrinker<T> = (T) -> ShrinkTree<T>`

## Search Strategy
BFS over the shrink tree, exploring candidates level-by-level. A candidate is accepted if it still fails the property. The process repeats from the accepted candidate until no better candidates exist.

## Performance Controls
- `maxNodes` and `maxDepth` guardrails to prevent pathological cases.
- Optional memoization for visited values (requires `Hashable` or a custom fingerprint).

## Open Questions
- How to treat non-Hashable types: user-supplied fingerprint or identity-based visited set.
