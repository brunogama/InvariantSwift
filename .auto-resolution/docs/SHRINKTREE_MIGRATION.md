# ShrinkTree Migration Guide

This guide explains how to migrate from the deprecated `Shrink.flatMap` and `Shrink.contramap` to the new `ShrinkTree`-based approach.

## Why Migrate?

The old `Shrink<T>` combinators (`flatMap`, `contramap`) were stubs that didn't properly support dependent shrinking. The new `ShrinkTree<T>` provides:

- ✅ Correct dependent shrinking for `Gen.flatMap`
- ✅ BFS search for minimal counterexamples
- ✅ Deterministic shrink ordering
- ✅ Composable tree structure

## Migration Summary

| Old (deprecated) | New (recommended) |
|------------------|-------------------|
| `Shrink.flatMap` | `ShrinkTree.flatMap` |
| `Shrink.contramap` | `ShrinkTree.map` |
| `gen.flatMap { ... }` | Works automatically via `generateTreeFlatMap` |

## No Action Required for Gen.flatMap

If you use `Gen.flatMap`, shrinking already works correctly:

```swift
// This works correctly - no changes needed
let gen = Gen<Int>.int(in: 1...10).flatMap { n in
    Gen<[Int]>.array(of: Gen<Int>.int(in: 0...100), count: n)
}
```

The `Gen.flatMap` internally uses `generateTreeFlatMap` which properly composes `ShrinkTree`s.

## Custom Shrinking with ShrinkTree

For custom shrinking logic, use `ShrinkTree` directly:

```swift
// Create a shrink tree for custom types
let tree = ShrinkTree.from(myValue) { value in
    // Return array of simpler values
    myShrinkFunction(value)
}

// Use BFS to find minimal counterexample
let minimal = tree.findMinimal(budget: 1000) { candidate in
    !myProperty(candidate)  // Returns true if still failing
}
```

## ShrinkTree API

```swift
public struct ShrinkTree<T> {
    let value: T
    var children: [ShrinkTree<T>]  // Lazily evaluated
    
    // Transformation
    func map<U>(_ f: (T) -> U) -> ShrinkTree<U>
    func flatMap<U>(_ f: (T) -> ShrinkTree<U>) -> ShrinkTree<U>
    func filter(_ predicate: (T) -> Bool) -> ShrinkTree<T>
    
    // Search
    func findMinimal(budget: Int, _ predicate: (T) -> Bool) -> T?
    
    // Factory
    static func from(_ value: T, shrink: (T) -> [T]) -> ShrinkTree<T>
}
```

## Example: Custom Dependent Generator

```swift
// Custom generator with proper shrinking
struct Person: Equatable {
    let age: Int
    let name: String
}

let personGen = Gen<Int>.int(in: 1...100).flatMap { age in
    let nameGen = Gen<String>.string(count: age / 10 + 3)
    return nameGen.map { name in Person(age: age, name: name) }
}

// Shrinking automatically handles:
// 1. Shrinking age toward 0
// 2. Regenerating name for each shrunk age
// 3. Shrinking name characters
```
