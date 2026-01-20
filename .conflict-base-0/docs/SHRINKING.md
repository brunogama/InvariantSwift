# Shrinking Guide

Shrinking is the process of finding the **minimal counterexample** when a property test fails. This guide explains how shrinking works and how to customize it.

## Table of Contents

1. [Why Shrinking Matters](#why-shrinking-matters)
2. [How Shrinking Works](#how-shrinking-works)
3. [Built-in Shrinking](#built-in-shrinking)
4. [Custom Shrinking](#custom-shrinking)
5. [Shrink Combinators](#shrink-combinators)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Why Shrinking Matters

Without shrinking, a failing test might report:

```
Counterexample: [847, -291, 553, 102, -847, 291, 0, -15, 882, 
                 -443, 201, 94, -7, 558, 112, 0, -884, 771]
```

This is hard to debug. Which element caused the failure? Why these specific values?

With shrinking, the same failure reports:

```
Counterexample: [847, -291, 553, 102, -847, 291, ...]
Shrunk counterexample: [-1]
```

Now you know: the property fails for any array containing a negative number. The minimal case is `[-1]`.

---

## How Shrinking Works

### The Shrinking Algorithm

1. **Find failure**: Run property, find a counterexample
2. **Generate shrink candidates**: Create simpler variants of the counterexample
3. **Test candidates**: Check if any candidate still fails
4. **Repeat**: If a candidate fails, use it as the new counterexample and repeat
5. **Stop**: When no simpler failing candidate exists

### Shrink Trees

Conceptually, shrinking explores a tree of progressively simpler values:

```
         [3, -1, 2]
        /    |    \
    [3, -1] [-1, 2] [3, 2]    <- Remove elements
      |       |       |
    [-1]    [-1]    [3]       <- Continue shrinking
      |       |       
    [0]     [0]               <- Shrink values
```

The algorithm does depth-first search, always preferring simpler values.

### Shrinking Directions

Different types shrink in different directions:

| Type | Shrinks Towards |
|------|-----------------|
| `Int` | 0 |
| `UInt` | 0 |
| `Double` | 0.0 |
| `Bool` | `false` |
| `String` | `""` (empty) |
| `Array` | `[]` (empty) |
| `Optional` | `nil` |
| `Enum` | First case |

---

## Built-in Shrinking

Most built-in generators include automatic shrinking.

### Integer Shrinking

```swift
// Shrinks: 100 -> 50 -> 25 -> 12 -> 6 -> 3 -> 1 -> 0
Gen<Int>.int  // Shrinks towards 0

// Shrinks within range
Gen<Int>.int(in: 10...100)  // Shrinks towards 10 (lower bound)
```

### String Shrinking

```swift
// Shrinks by:
// 1. Removing characters
// 2. Simplifying characters (towards 'a')
Gen<String>.string

// "Hello World" -> "Hello" -> "Hell" -> "Hel" -> "He" -> "H" -> ""
```

### Array Shrinking

```swift
// Shrinks by:
// 1. Removing elements
// 2. Shrinking remaining elements

Gen.array(Gen<Int>.int)

// [5, -3, 8] -> [-3, 8] -> [-3] -> [0] -> []
// or
// [5, -3, 8] -> [5, -3] -> [-3] -> [-1] -> [0]
```

### Optional Shrinking

```swift
// Shrinks to nil first, then shrinks the wrapped value
Gen.optional(Gen<Int>.int)

// .some(100) -> nil  (if nil fails)
// .some(100) -> .some(50) -> .some(25) -> ... (if nil passes)
```

---

## Custom Shrinking

### withShrink Modifier

```swift
struct PositiveInt {
    let value: Int
    
    init(_ value: Int) {
        precondition(value > 0)
        self.value = value
    }
}

extension PositiveInt {
    static var arbitrary: Gen<PositiveInt> {
        Gen<Int>.int(in: 1...Int.max)
            .map { PositiveInt($0) }
            .withShrink { pos in
                // Shrink towards 1 (smallest positive)
                Shrink.towards(1, pos.value)
                    .filter { $0 > 0 }
                    .map { PositiveInt($0) }
            }
    }
}
```

### Custom Shrink Function

```swift
struct Point {
    let x: Int
    let y: Int
}

extension Point {
    static var arbitrary: Gen<Point> {
        Gen.zip(Gen<Int>.int, Gen<Int>.int)
            .map { Point(x: $0, y: $1) }
            .withShrink { point in
                // Shrink x and y independently
                let shrunkX = Shrink.towards(0, point.x).map { Point(x: $0, y: point.y) }
                let shrunkY = Shrink.towards(0, point.y).map { Point(x: point.x, y: $0) }
                return shrunkX + shrunkY
            }
    }
}
```

### Preserving Invariants

When shrinking, ensure invariants are maintained:

```swift
struct SortedArray {
    let elements: [Int]
    
    init(_ elements: [Int]) {
        self.elements = elements.sorted()
    }
}

extension SortedArray {
    static var arbitrary: Gen<SortedArray> {
        Gen.array(Gen<Int>.int)
            .map { SortedArray($0) }
            .withShrink { arr in
                // Shrink by removing elements (maintains sorted order)
                Shrink.removeElements(from: arr.elements)
                    .map { SortedArray($0) }  // Re-sort to maintain invariant
            }
    }
}
```

---

## Shrink Combinators

### Shrink.towards

Shrink a number towards a target:

```swift
// Shrink 100 towards 0
Shrink.towards(0, 100)
// Returns: [50, 75, 88, 94, 97, 99]

// Shrink 100 towards 50
Shrink.towards(50, 100)
// Returns: [75, 62, 56, 53, 51]
```

### Shrink.removeElements

Remove elements from a collection:

```swift
Shrink.removeElements(from: [1, 2, 3, 4])
// Returns: [[2,3,4], [1,3,4], [1,2,4], [1,2,3], [3,4], [1,4], [1,2], ...]
```

### Shrink.shrinkElements

Shrink individual elements:

```swift
let intShrinker: (Int) -> [Int] = { Shrink.towards(0, $0) }
Shrink.shrinkElements(in: [10, 20], using: intShrinker)
// Returns: [[5, 20], [10, 10], [0, 20], [10, 0], ...]
```

### Shrink.concat

Combine multiple shrinking strategies:

```swift
let combinedShrink = Shrink.concat([
    { arr in Shrink.removeElements(from: arr) },
    { arr in Shrink.shrinkElements(in: arr, using: intShrinker) }
])
```

### Shrink.filter

Filter shrink candidates:

```swift
let evenShrink = Shrink.towards(0, value).filter { $0 % 2 == 0 }
```

### Shrink.map

Transform shrink candidates:

```swift
let positiveShirink = Shrink.towards(0, value)
    .map { abs($0) }
    .filter { $0 > 0 }
```

---

## Best Practices

### 1. Shrink Towards Simple Values

```swift
// Good: Shrinks towards empty string
.withShrink { str in
    (0..<str.count).map { String(str.prefix($0)) }
}

// Bad: Shrinks towards complex values
.withShrink { str in
    [str + "extra", str.uppercased()]  // Not simpler!
}
```

### 2. Maintain Type Invariants

```swift
struct NonEmpty<T> {
    let elements: [T]
    
    init?(_ elements: [T]) {
        guard !elements.isEmpty else { return nil }
        self.elements = elements
    }
}

// Good: Never shrinks to empty
.withShrink { ne in
    Shrink.removeElements(from: ne.elements)
        .filter { !$0.isEmpty }  // Maintain non-empty invariant
        .compactMap { NonEmpty($0) }
}
```

### 3. Shrink Efficiently

```swift
// Good: Binary search shrinking (O(log n) steps)
Shrink.towards(0, largeValue)

// Bad: Linear shrinking (O(n) steps)
(0..<largeValue).map { largeValue - $0 }
```

### 4. Order Shrink Candidates

```swift
// Good: Simpler candidates first
.withShrink { value in
    [
        simplestAlternative,
        simpleAlternative,
        lessSimpleAlternative
    ]
}
```

### 5. Don't Over-shrink

```swift
// Good: Reasonable number of candidates
.withShrink { arr in
    Shrink.removeElements(from: arr)  // O(n) candidates
}

// Bad: Exponential candidates
.withShrink { arr in
    allSubsets(arr)  // O(2^n) candidates - too slow!
}
```

---

## Troubleshooting

### Shrinking Takes Too Long

**Symptoms**: Test hangs during shrinking

**Causes**:
1. Too many shrink candidates
2. Each shrink candidate is slow to test
3. Property sometimes passes during shrinking

**Solutions**:
```swift
// Limit shrink attempts
let config = PropertyConfig(maxShrinks: 100)

// Make shrinking more aggressive
.withShrink { value in
    Shrink.towards(0, value)
        .prefix(10)  // Limit candidates
        .map { Array($0) }
}
```

### Shrunk Value Isn't Minimal

**Symptoms**: Counterexample could be simpler

**Causes**:
1. Shrinking stopped too early (maxShrinks limit)
2. Missing shrink directions

**Solutions**:
```swift
// Increase shrink limit
let config = PropertyConfig(maxShrinks: 5000)

// Add more shrink directions
.withShrink { point in
    let shrinkX = Shrink.towards(0, point.x).map { Point(x: $0, y: point.y) }
    let shrinkY = Shrink.towards(0, point.y).map { Point(x: point.x, y: $0) }
    let shrinkBoth = Shrink.towards(0, point.x).flatMap { x in
        Shrink.towards(0, point.y).map { y in Point(x: x, y: y) }
    }
    return shrinkX + shrinkY + shrinkBoth
}
```

### Shrinking Breaks Invariants

**Symptoms**: Crash or unexpected error during shrinking

**Causes**:
1. Shrunk values violate type invariants
2. Shrunk values outside valid range

**Solutions**:
```swift
// Filter invalid candidates
.withShrink { value in
    Shrink.towards(target, value)
        .filter { isValid($0) }  // Enforce invariants
}

// Use safe constructors
.withShrink { wrapper in
    Shrink.towards(0, wrapper.value)
        .compactMap { Wrapper(validating: $0) }  // Returns nil for invalid
}
```

### No Shrinking Occurs

**Symptoms**: Counterexample is same as shrunk counterexample

**Causes**:
1. Generator has no shrink function
2. All shrink candidates pass the property

**Solutions**:
```swift
// Add shrinking
let gen = myGenerator.withShrink { value in
    // Define shrink candidates
}

// Check if shrinking is attached
// Use .withShrink explicitly
```

---

## Reference

### Shrink Type

```swift
public struct Shrink<Value> {
    public let shrink: (Value) -> [Value]
    
    public static func towards<N: Numeric>(_ target: N, _ value: N) -> [N]
    public static func removeElements<T>(from array: [T]) -> [[T]]
    public static func shrinkElements<T>(in array: [T], using: (T) -> [T]) -> [[T]]
    public static func concat<T>(_ shrinks: [(T) -> [T]]) -> (T) -> [T]
}
```

### Generator Shrink Integration

```swift
extension Gen {
    public func withShrink(_ shrink: @escaping (Value) -> [Value]) -> Gen<Value>
    public func noShrink() -> Gen<Value>
}
```

### PropertyConfig Shrink Options

```swift
PropertyConfig(
    maxShrinks: 1000,     // Maximum shrink attempts
    shrinkEnabled: true   // Enable/disable shrinking
)
```
