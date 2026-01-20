# Delta for Shrinking

## ADDED Requirements

### Requirement: ShrinkTree Representation
The system MUST represent shrinking as a tree of candidates to enable deterministic traversal and composition.

#### Scenario: A shrinker returns a tree
- GIVEN a shrinker for type T
- WHEN called with a value V
- THEN it returns a `ShrinkTree<T>` with root value V and zero or more child candidates
- AND children are computed lazily (not all at initialization)
- AND the same value always produces the same tree structure

#### Scenario: Tree node has functor operations
- GIVEN a `ShrinkTree<T>`
- WHEN `map` is called with a function `(T) -> U`
- THEN a new `ShrinkTree<U>` is produced with the function applied to all values
- AND the tree structure (parent-child relationships) is preserved

#### Scenario: Tree node supports monadic bind
- GIVEN a `ShrinkTree<T>` and a function `(T) -> ShrinkTree<U>`
- WHEN `flatMap` is called with the function
- THEN a `ShrinkTree<U>` is produced that includes both direct shrinks and indirect (transformed) shrinks

#### Scenario: Leaf nodes and empty shrinking
- GIVEN a value that cannot be simplified further
- WHEN `ShrinkTree.leaf(_)` is used
- THEN the tree has the value but no children
- AND the structure is immutable and reusable

### Requirement: Deterministic Shrink Search
The system MUST use a deterministic shrink search that yields the same minimal counterexample under the same inputs.

#### Scenario: BFS yields stable minimal counterexample
- GIVEN a failing value V and its `ShrinkTree<T>` representation
- WHEN `findMinimal(budget:satisfying:)` is executed twice with identical arguments
- THEN the same minimal value satisfying the predicate is returned
- AND the traversal order is reproducible (breadth-first, left-to-right)

#### Scenario: Deterministic children order
- GIVEN two calls to the same `ShrinkTree` node's children
- WHEN children are computed
- THEN the children appear in the same order both times
- AND the order is consistent across runs (same seed/input)

### Requirement: Performance Controls
The system MUST prevent pathological tree expansion via configurable limits.

#### Scenario: Depth limit prevents deep recursion
- GIVEN a `ShrinkTree<T>` with infinite or very deep nesting
- WHEN `prune(maxDepth:)` is called with `maxDepth = 10`
- THEN the returned tree has at most 10 levels
- AND shrinks at depth > 10 are discarded

#### Scenario: Breadth limit prevents wide trees
- GIVEN a node with 1000 children
- WHEN `limitBreadth(maxChildren:)` is applied with `maxChildren = 10`
- THEN the node retains only the first 10 children (most likely to shrink)
- AND subsequent children are discarded

#### Scenario: Search budget prevents exhaustive exploration
- GIVEN a `ShrinkTree` and `findMinimal(budget:satisfying:)` with `budget = 100`
- WHEN the search would explore more than 100 nodes
- THEN the search stops after visiting exactly 100 nodes
- AND the best failing value found so far is returned

#### Scenario: Lazy evaluation avoids computing unexplored branches
- GIVEN a `ShrinkTree` with expensive children computation
- WHEN a leaf is reached before exploring all children
- THEN the expensive children of unvisited siblings are never computed

### Requirement: Bridge from Flat `Shrink<T>` to Tree
The system MUST maintain compatibility with existing `Shrink<T>` API while providing a migration path.

#### Scenario: `ShrinkTree.from()` bridges existing shrinkers
- GIVEN a value `v: T` and an existing `Shrink<T>` strategy
- WHEN `ShrinkTree.from(v, shrink: strategy)` is called
- THEN a `ShrinkTree<T>` is constructed recursively
- AND each level of the tree represents one shrinking step

#### Scenario: Properties using flat `Shrink<T>` still work
- GIVEN an existing property using `Gen<T>` with flat shrinking
- WHEN the property is run through `PropertyRunner`
- THEN shrinking still works (via bridge conversion)
- AND the minimal counterexample is found (via BFS instead of greedy)

### Requirement: PropertyRunner Integration
The property runner MUST use BFS-based search to find minimal counterexamples deterministically.

#### Scenario: PropertyRunner switches shrinking strategy
- GIVEN a failing property test
- WHEN `PropertyRunner` executes shrinking
- THEN it constructs a `ShrinkTree` from the failing value
- AND uses BFS (not greedy) to explore shrink candidates
- AND reports the minimal failing value after budgeted search

#### Scenario: Shrink path is tracked and reproducible
- GIVEN a shrinking session that reduces [a, b, c, d] to [a, b]
- WHEN the shrink path is recorded and replayed
- THEN the same minimal counterexample is reached deterministically

#### Scenario: Failure output includes shrink metrics
- GIVEN a property that fails and shrinks
- WHEN failure is reported
- THEN the output includes:
  - Original failing value
  - Minimal counterexample
  - Number of shrink steps
  - Approximate "complexity" of the minimal value

### Requirement: Core Shrinker Reference Implementations
The system MUST provide canonical shrinkers for built-in types that return `ShrinkTree`.

#### Scenario: Integer shrinking toward target
- GIVEN integers 100 and target 0
- WHEN `Shrink.towards(0, value: 100)` is applied
- THEN shrinking produces: 0, 50, 75, 88, 94, 97, 99 (in BFS order)
- AND each shrink is strictly closer to the target than its parent

#### Scenario: String shrinking removes characters
- GIVEN string "hello"
- WHEN shrinking is applied
- THEN candidates include: "", "h", "he", "hell", "hello" (minus each char)
- AND all shrinks are actual substrings or reductions

#### Scenario: Array shrinking combines removal and element shrinking
- GIVEN `[1, 2, 3]` with element shrinker shrinking ints to 0
- WHEN array shrinking is applied
- THEN candidates include:
  - Shorter arrays: `[]`, `[1]`, `[2]`, `[3]`, `[1, 2]`, `[1, 3]`, `[2, 3]`
  - Element-shrunk: `[0, 2, 3]`, `[1, 0, 3]`, `[1, 2, 0]`

#### Scenario: Double/Float shrinking respects precision
- GIVEN floating-point value 3.14159
- WHEN shrinking toward 0.0
- THEN shrinking uses binary search and respects epsilon precision
- AND no spurious "equal" values (within tolerance) are reported as new shrinks

### Requirement: Determinism Guarantees
Shrinking MUST be deterministic for replay and debugging.

#### Scenario: Same seed produces same shrink sequence
- GIVEN seed S and failing value V
- WHEN property test is replayed with seed S
- THEN the shrink sequence is identical
- AND the minimal counterexample is the same

#### Scenario: Shrink path can be serialized and replayed
- GIVEN a shrink path [a → b → c → d] (each entry is a shrink step)
- WHEN path is saved and replayed in a new run
- THEN the same final minimal value d is reached
- AND the property still fails at d

## MODIFIED Requirements

### Requirement: `Shrink<T>` API Stability (Legacy)
The existing `Shrink<T>` struct MUST remain available for backward compatibility.

#### Scenario: Existing `Shrink<T>` usage continues to work
- GIVEN code using `Shrink<Int>` or `Shrink<String>` or `Shrink<[T]>`
- WHEN compiled with the new implementation
- THEN the code compiles without errors
- AND shrinking behavior is preserved (via bridge to BFS)

#### Scenario: Deprecated methods are properly marked
- GIVEN `Shrink<T>.flatMap` and `Shrink<T>.contramap` (mathematically invalid for flat lists)
- WHEN these methods are called
- THEN compiler emits deprecation/unavailability warning
- AND error message directs user to `ShrinkTree` API

## REMOVED Requirements

None. All existing shrinking invariants are maintained.

## Cross-References

- Related to **ISP-0001 (deterministic replay)**: Deterministic shrinking is essential for replay tokens
- Related to **ISP-0003 (discard semantics)**: Shrinker must respect property assumptions (tested in `filter` scenario)
- Related to **ISP-0004 (example database)**: Shrunk counterexamples are stored in the database
- Related to **ISP-0009 (ghostwriter)**: Generated tests may define custom shrinkers for domain types
