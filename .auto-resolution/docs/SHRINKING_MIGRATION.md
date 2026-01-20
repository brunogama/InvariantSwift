# Shrinking Migration Guide

## Overview

InvariantSwift has standardized on `ShrinkTree<T>` as the canonical shrink-tree abstraction. Two experimental types—`Node<A>` and `TreeGen<A>` from `Advanced/ShrinkTrees.swift`—are now deprecated in favor of the streamlined approach.

This guide helps you migrate to the new model.

## What Changed

### Old Model (Deprecated)
```swift
// From Advanced/ShrinkTrees.swift
struct Node<A> { ... }        // Experimental shrink-tree node
struct TreeGen<A> { ... }     // Experimental generator
```

### New Model (Canonical)
```swift
// From Core/ShrinkTree.swift
struct ShrinkTree<T> { ... }  // Canonical shrink-tree
struct Gen<T> { ... }         // Standard generator (unchanged)
```

## Migration Paths

### If You Were Using `Node<A>`

**Before:**
```swift
let node: Node<Int> = Node(value: 100) {
  [Node.leaf(0), Node.leaf(50)]
}

let result = node.map { $0 * 2 }
```

**After:**
```swift
let tree: ShrinkTree<Int> = ShrinkTree(value: 100) {
  [ShrinkTree.leaf(0), ShrinkTree.leaf(50)]
}

let result = tree.map { $0 * 2 }
```

**Key differences:**
- Replace `Node<A>` with `ShrinkTree<A>`
- Replace `Lazy<[Node<A>]>` with `() -> [ShrinkTree<A>]` (lazy closure)
- All methods are available on both types with identical behavior

### If You Were Using `TreeGen<A>`

**Before:**
```swift
let gen: TreeGen<Int> = TreeGen<Int>.int(in: 0...100)
let node = gen.run(&rng, size)
```

**After:**
Use the standard `Gen<T>` model instead:
```swift
let gen: Gen<Int> = Gen<Int>.int(in: 0...100)
let value = gen.generate(&rng, size)
// PropertyRunner automatically uses ShrinkTree-based shrinking
```

**Why the change:**
- `Gen<T>` with standard `Shrink<T>` is simpler and more familiar
- `PropertyRunner` converts `Shrink<T>` → `ShrinkTree<T>` automatically via `ShrinkTree.from()`
- No need for separate "tree generators"—use regular generators with proper shrinking

### If You Need Low-Level ShrinkTree Control

For advanced use cases where you need direct `ShrinkTree` access:

**Before:**
```swift
// Using TreeGen to create trees
let tree = TreeGen<Int>.pure(42).run(&rng, size)
```

**After:**
```swift
// Create ShrinkTree directly
let tree = ShrinkTree<Int>.leaf(42)

// Or convert from a Shrink strategy
let tree = ShrinkTree.from(42, shrink: Shrink<Int>.empty)
```

## API Compatibility

All `Node<A>` and `TreeGen<A>` methods work identically on `ShrinkTree<T>`:

| Operation | Node<A> | ShrinkTree<T> |
|-----------|---------|--------------|
| Create leaf | `Node.leaf(value)` | `ShrinkTree.leaf(value)` |
| Create with shrinks | `Node(value:shrinks:)` | `ShrinkTree(value:children:)` |
| Map | `node.map { ... }` | `tree.map { ... }` |
| FlatMap | `node.flatMap { ... }` | `tree.flatMap { ... }` |
| Filter | `node.filter { ... }` | `tree.filter { ... }` |
| Find minimal | `node.unfold()` then search | `tree.findMinimal(budget:satisfying:)` |
| BFS traversal | Custom code | `tree.breadthFirst()` |
| DFS traversal | Custom code | `tree.depthFirst()` |
| Prune | Custom code | `tree.prune(maxDepth:)` |
| Limit breadth | Not available | `tree.limitBreadth(_:)` |
| Limit total nodes | Not available | `tree.limitTotal(_:)` |

## Performance Notes

`ShrinkTree<T>` has identical performance to `Node<A>`:
- Lazy evaluation of children (computed on demand)
- O(budget) time for BFS search
- O(width) space for the queue

Additionally, `ShrinkTree` offers:
- `limitBreadth(_:)` – cap children per node for width-bounded search
- `limitTotal(_:)` – cap total nodes for depth+breadth bounded search

## Deprecation Timeline

- **Current**: `Node<A>` and `TreeGen<A>` marked with `@available(*, deprecated, ...)`
- **Next minor release**: Compiler warnings when using deprecated types
- **Future major release**: Types may be removed; use `ShrinkTree<T>` before then

## Quick Reference

| Task | Use This |
|------|----------|
| Create shrink tree | `ShrinkTree<T>(value:children:)` or `ShrinkTree.leaf(_:)` |
| Convert from Shrink | `ShrinkTree.from(_:shrink:)` |
| Find minimal value | `tree.findMinimal(budget:satisfying:)` |
| Transform tree | `tree.map { ... }` or `tree.flatMap { ... }` |
| Filter by predicate | `tree.filter { ... }` |
| Limit tree size | `tree.prune(maxDepth:)`, `limitBreadth(_:)`, or `limitTotal(_:)` |
| Get all values (BFS) | `tree.breadthFirst()` |
| Get all values (DFS) | `tree.depthFirst()` |

## Examples

### Example 1: Simple Shrinking

**Before:**
```swift
let node = Node(value: 100, shrinks: {
  [Node.leaf(0), Node.leaf(50)]
})

let values = node.unfold()  // Get all values
```

**After:**
```swift
let tree = ShrinkTree(value: 100) {
  [ShrinkTree.leaf(0), ShrinkTree.leaf(50)]
}

let values = tree.breadthFirst()  // Get all values in BFS order
```

### Example 2: Dependent Shrinking

**Before:**
```swift
let node = TreeGen<Int>.int(in: 1...10)
  .flatMap { n in
    TreeGen<String>.pure(String(repeating: "x", count: n))
  }
  .run(&rng, size)
```

**After:**
```swift
let gen = Gen<Int>.int(in: 1...10)
  .flatMap { n in
    Gen<String>.pure(String(repeating: "x", count: n))
  }

// PropertyRunner handles shrinking automatically
let tree = gen.generateTree(&rng, Size(value: 50))
```

### Example 3: Finding Minimal Value

**Before:**
```swift
let node = Node.from(100, shrink: Shrink { ... })
var allValues = node.unfold()
let minimal = allValues.first { property($0) }
```

**After:**
```swift
let tree = ShrinkTree.from(100, shrink: Shrink { ... })
let minimal = tree.findMinimal(budget: 1000) { value in
  property(value)  // True = satisfies (keep shrinking), false = stop
}
```

## See Also

- [API_REFERENCE_GENERATED.md](./API_REFERENCE_GENERATED.md) – Complete API docs for `ShrinkTree<T>`
- [ONBOARDING.md](./ONBOARDING.md) – Getting started with InvariantSwift
- [COOKBOOK.md](./COOKBOOK.md) – Common patterns and recipes
