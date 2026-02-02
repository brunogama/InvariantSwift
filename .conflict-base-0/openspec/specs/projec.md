---
id: collection-shrinking-v2
title: Collection shrinking v2: chunk removal first
capability: pbt-shrinking
status: proposed
---

# Collection shrinking v2: chunk removal first

## Summary

Improve collection (Array, Dictionary, Set) shrinking by prioritizing chunk deletions (delta-debugging) over element-level shrinking. This ensures faster convergence to minimal counterexamples and stabilizes deterministic ordering for hash-based collections.

## Background

### What is shrinking?

When a property-based test fails, shrinking reduces the failing input to the **smallest counterexample** that still fails the property. For example, if a test fails with `[847, -291, 553, 102, -847, 291]`, shrinking might reduce it to `[-1]` — revealing that the issue is simply "arrays containing negative numbers."

### Current shrinking limitations

The current implementation intermixes chunk removal with element shrinking, which can lead to:
1. **Suboptimal minimality**: Element shrinking may run before chunks are removed, producing larger-than-necessary counterexamples
2. **Non-determinism**: Dictionary/Set shrinking order depends on hash iteration order, causing different shrink sequences across runs
3. **Performance**: Element-wise shrinking on large collections is O(n²) vs O(log n) for chunk-based delta debugging

### Delta debugging

Delta debugging is a proven algorithm for minimizing failing inputs:
1. Remove half the collection — if it still fails, keep the smaller version
2. If removing half doesn't fail, try removing quarters, eighths, etc.
3. Fall back to removing individual elements only when larger chunks don't work

This approach achieves O(log n) convergence for most cases vs O(n) for naive single-element removal.

## Motivation

- **Improve correctness**: Ensure shrinking finds truly minimal counterexamples
- **Improve determinism**: Same seed/replay token must produce identical shrink sequences across platforms
- **Improve developer trust**: Predictable, documented shrinking behavior
- **Keep the PBT core contract sound**: Foundation for advanced features like stateful command shrinking

## Technical approach

### Requirement: SHRINK-COLL-001 — Chunk removal first

Collection shrinkers MUST attempt chunk deletion before element-wise shrinking.

#### Array shrinking strategy

```swift
Shrink<[Element]> { array in
    var candidates: [[Element]] = []
    
    // 1. FIRST: Chunk removal (delta-debugging)
    //    - Empty array (most aggressive)
    //    - Remove halves, quarters, eighths progressively
    //    - Remove individual elements
    candidates.append(contentsOf: Shrink.removeElements(from: array))
    
    // 2. THEN: Element-wise shrinking
    //    - Shrink each element independently while preserving structure
    candidates.append(contentsOf: Shrink.shrinkElements(in: array, using: elementGen.shrink))
    
    return candidates.removingDuplicates()
}
```

#### Dictionary shrinking strategy

```swift
Shrink<[Key: Value]> { dict in
    var candidates: [[Key: Value]] = []
    
    // 1. Deterministic ordering: sort by hash value for reproducibility
    let pairs = dict.sorted(by: { $0.key.hashValue < $1.key.hashValue })
    
    // 2. FIRST: Chunk removal on sorted pairs
    let pairArrays = Shrink.removeElements(from: pairs)
    candidates.append(contentsOf: pairArrays.map { Dictionary(uniqueKeysWithValues: $0) })
    
    // 3. THEN: Key and value shrinking in deterministic order
    for (key, value) in pairs {
        // Shrink keys (may cause key collisions, handled gracefully)
        for shrunkKey in keyGen.shrink.shrink(key) { ... }
        // Shrink values
        for shrunkValue in valueGen.shrink.shrink(value) { ... }
    }
    
    return candidates.removingDuplicates()
}
```

#### Set shrinking strategy

Sets require special handling due to their unordered nature:
1. Convert to sorted array (by hash value) for deterministic ordering
2. Apply array shrinking strategy
3. Convert back to Set

### Candidate ordering rules

1. **Empty collection** — always first candidate (most aggressive)
2. **Chunk removal** — halves, quarters, eighths, individual elements
3. **Element shrinking** — only after all chunk candidates are exhausted
4. **Deterministic ordering** — hash-based sorting for Dict/Set

## Scope

- Implement requirements in the spec delta under `specs/pbt-shrinking/spec.md`
- Modify `Sources/InvariantSwift/Generators/CollectionGenerators.swift`:
  - Update `Gen.array(_:)` shrink strategy
  - Update `Gen.dictionary(_:_:)` shrink strategy
  - Add `Gen.set(_:)` deterministic shrink strategy (if in scope)
- Add tests for:
  - Chunk removal priority verification
  - Minimality guarantees
  - Deterministic candidate sequence across platforms
  - Shrink tree depth/breadth bounds
- Add benchmarks to prevent pathological performance

## Non-goals

- No unrelated refactors
- No expanding to additional features not listed in the delta
- No changes to non-collection generators (Int, String, etc.)
- No changes to the ShrinkTree core algorithm

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Hash collisions could cause non-determinism | Sort by `hashValue` combined with `ObjectIdentifier` for disambiguation |
| Large collections may generate many candidates | Apply `limitBreadth` and `limitTotal` pruning to ShrinkTrees |
| Element shrinking regression | Comprehensive test coverage for element-wise shrinking after chunk removal |

## Acceptance criteria

- All scenarios in the spec delta pass
- Deterministic output for the same seed/replay token across supported platforms/toolchains (macOS, Linux, iOS)
- Shrinking finds minimal counterexamples in ≤1000 nodes visited (current budget)
- No performance regression: shrinking should be faster or equal for typical cases
- Benchmark confirms O(log n) convergence for chunk-based shrinking

## References

- [Delta Debugging (Zeller, 1999)](https://www.st.cs.uni-saarland.de/papers/tse2002/)
- [QuickCheck: A Lightweight Tool for Random Testing](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf)
- Current implementation: `Sources/InvariantSwift/Core/Generator.swift` (`Shrink.removeElements`)
- ShrinkTree BFS search: `Sources/InvariantSwift/Core/ShrinkTree.swift`
