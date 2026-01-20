# Design: ShrinkTree and shrink search

## Architecture Decisions

### 1. Canonical Shrink-Tree Type: `ShrinkTree<T>`
- **Single canonical type**: Use `Core/ShrinkTree.swift` as the authoritative implementation
- **Rationale**: Consistency, avoids duplication, simpler mental model for users
- **Migration path**: Deprecate `Node<A>` and `TreeGen<A>` from `Advanced/ShrinkTrees.swift` in favor of `ShrinkTree` combinators
- **Key properties**:
  - `value: T` – current node value
  - `children: () -> [ShrinkTree<T>]` – lazy children (computed on demand)
  - Functor/Monad/Applicative laws (map, flatMap, filter, etc.)

### 2. Shrink-to-Tree Bridge
- `ShrinkTree.from(_ value:T, shrink:Shrink<T>) -> ShrinkTree<T>` already exists
- Keep `Shrink<T>` available for backward compatibility; mark as legacy in docs
- Encourage new code to use `ShrinkTree` directly or via generators that return trees

### 3. Deterministic BFS Search Strategy
**Algorithm**:
```
1. Start with root node value; check if it fails property
2. If yes, enqueue all children (BFS level N)
3. For each child in queue:
   a. Test if child fails property
   b. If yes, update best candidate; enqueue its children
   c. If no, skip (candidate passed, not useful)
4. Stop when queue exhausted or budget exceeded
5. Return best (most shrunk) failing candidate
```

**Stability**: Same input → same output (deterministic children ordering is essential)

### 4. Performance Control Strategy
**Limits** (configurable in `PropertyRunner`):
- `maxShrinkNodes`: Stop BFS after visiting N nodes (default: 10,000)
- `maxShrinkDepth`: Prune tree to max depth (default: 50)
- `maxShrinkTime`: Stop after elapsed milliseconds (optional, for long shrinks)

**Lazy evaluation**:
- Children only computed when node is visited
- Memoize children call (avoid recomputing)
- Use `Lazy<T>` wrapper for deferred computation if needed

### 5. Handling Non-Hashable Values
- **No memoization by default** (avoid Hashable requirement)
- **Identity-based visited set** via `ObjectIdentifier` (for reference types)
- **User-supplied fingerprint** as optional parameter (future enhancement)
- **Implication**: May visit same value multiple times on different paths (acceptable cost)

## Interface Specification

### Core Type
```swift
public struct ShrinkTree<T>: @unchecked Sendable {
  public let value: T
  public var children: [ShrinkTree<T>]

  public init(value: T, children: @escaping () -> [ShrinkTree<T>] = { [] })
  public static func leaf(_ value: T) -> ShrinkTree<T>
  public static func from(_ value: T, shrink: Shrink<T>) -> ShrinkTree<T>
}
```

### Combinators
- `map<U>(_ f: (T) -> U) -> ShrinkTree<U>` – functor
- `flatMap<U>(_ f: (T) -> ShrinkTree<U>) -> ShrinkTree<U>` – monad (now correct!)
- `filter(_ predicate: (T) -> Bool) -> ShrinkTree<T>` – respect assumptions
- `prune(maxDepth: Int) -> ShrinkTree<T>` – safety guard
- `take(_ n: Int) -> ShrinkTree<T>` – limit branching

### Search
```swift
public func findMinimal(budget: Int, satisfying predicate: (T) -> Bool) -> T?
```

### Traversals
- `breadthFirst() -> [T]` – BFS order
- `depthFirst() -> [T]` – DFS order (for debugging)

## PropertyRunner Integration

**Current** (`Testing/PropertyRunner.swift`):
```swift
let shrunk = shrink.shrink(failingValue)  // [T]
// Greedy: check shrunk[0], then shrunk[1], etc.
```

**New**:
```swift
let tree = ShrinkTree.from(failingValue, shrink: shrink)
let minimal = tree.findMinimal(budget: 10000) { value in
  !property(value)  // true = still fails (we want to keep shrinking)
}
```

## Shrinker Definitions

All core shrinkers must return `ShrinkTree<T>`:
- `Shrink<Int>.towards(0, value: Int) -> ShrinkTree<Int>`
- `Shrink<String>.removeChars → ShrinkTree<String>`
- `Shrink<[T]>.removeElements → ShrinkTree<[T]>`
- `Shrink<Double>.towards(0.0, value: Double) -> ShrinkTree<Double>`

**Key invariant**: Shrink candidates must be monotonically smaller/simpler than parent.

## Determinism and Reproducibility

**What we guarantee**:
- Same `value` + same `Shrink<T>` → same tree structure
- BFS with stable children ordering → same minimal result
- Replay tokens capture both input value AND shrink steps

**What differs**:
- Old greedy may report [x, y, z]; new BFS may report [x, z] (both valid!)
- This is **acceptable** and **desired** (BFS finds better minimality)

## Edge Cases & Mitigation

| Edge Case | Risk | Mitigation |
|-----------|------|-----------|
| Infinite tree (cycles) | Budget exhausted, wrong result | BFS + budget prevents infinite loops |
| Exponential branching | Memory explosion | `maxDepth` + `take(n)` limits children |
| Empty children | Premature convergence | Ensure all leaf nodes return `[]` |
| Non-deterministic children | Replay fails | Ensure children order is stable |
| `Sendable` closure capture | Thread-safety | Use `@Sendable` + no mutation |

## Open Questions Resolved
- **Memoization**: Defer to future optimization; no Hashable requirement now
- **Fingerprinting**: Optional future feature for non-Hashable types
- **Dual types**: Unify on `ShrinkTree`; deprecate `Node` if still needed
