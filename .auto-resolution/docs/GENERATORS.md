# Generators Guide

Generators are the heart of property-based testing. They define how random test data is created.

## Table of Contents

1. [Introduction](#introduction)
2. [Built-in Generators](#built-in-generators)
3. [Generator Combinators](#generator-combinators)
4. [Custom Generators](#custom-generators)
5. [Shrinking](#shrinking)
6. [Size and Distribution](#size-and-distribution)
7. [Advanced Patterns](#advanced-patterns)
8. [Reference](#reference)

---

## Introduction

A `Gen<T>` is a recipe for generating random values of type `T`. It takes a random number generator and a "size" parameter, and produces a value:

```swift
public struct Gen<Value: Sendable>: Sendable {
    let generate: @Sendable (inout SeededRNG, Size) -> Value
}
```

Key concepts:
- **Deterministic**: Given the same seed, generators produce the same sequence
- **Size-aware**: Generators scale with the "size" parameter (larger sizes = larger values)
- **Composable**: Generators combine using `map`, `flatMap`, `zip`, etc.
- **Shrinkable**: Most generators include shrinking strategies

---

## Built-in Generators

### Numeric Types

#### Integers

```swift
// Unbounded (scaled by size)
Gen<Int>.int
Gen<Int8>.int
Gen<Int16>.int
Gen<Int32>.int
Gen<Int64>.int

Gen<UInt>.uint
Gen<UInt8>.uint
Gen<UInt16>.uint
Gen<UInt32>.uint
Gen<UInt64>.uint

// Bounded ranges
Gen<Int>.int(in: 0...100)
Gen<Int>.int(in: -50..<50)

// Boundary-focused (more likely to hit edges)
Gen<Int>.boundary(in: 0...100)
```

#### Floating Point

```swift
// Standard
Gen<Double>.double
Gen<Float>.float

// Bounded
Gen<Double>.double(in: 0.0...1.0)

// Special values (includes NaN, infinity)
Gen<Double>.doubleWithSpecials
```

### Boolean

```swift
Gen<Bool>.bool                    // 50/50
Gen<Bool>.bool(probability: 0.7)  // 70% true
```

### Strings

```swift
// Random strings
Gen<String>.string
Gen<String>.string(length: 10)
Gen<String>.string(length: 5...20)

// Character sets
Gen<String>.alphanumeric
Gen<String>.alphabetic
Gen<String>.numeric
Gen<String>.ascii
Gen<String>.unicode

// Characters
Gen<Character>.letter
Gen<Character>.digit
Gen<Character>.alphanumeric
Gen<Character>.ascii
```

### Foundation Types

```swift
Gen<UUID>.uuid
Gen<Date>.date
Gen<Date>.date(in: startDate...endDate)
Gen<Data>.data
Gen<Data>.data(count: 100)
Gen<URL>.url
```

### Collections

```swift
// Arrays
Gen.array(Gen<Int>.int)                    // Variable length
Gen.array(Gen<Int>.int, count: 5)          // Exact length
Gen.array(Gen<Int>.int, count: 1...10)     // Length range
Gen.nonEmptyArray(Gen<Int>.int)            // At least 1 element

// Sets
Gen.set(Gen<String>.string)
Gen.set(Gen<Int>.int, count: 5)

// Dictionaries
Gen.dictionary(Gen<String>.string, Gen<Int>.int)
Gen.dictionary(keyGen, valueGen, count: 3...10)
```

### Optionals

```swift
Gen.optional(Gen<Int>.int)                    // Default 20% nil
Gen.optional(Gen<Int>.int, nilProbability: 0.5)  // 50% nil
Gen.some(Gen<Int>.int)                        // Never nil
```

### Result Type

```swift
Gen.result(successGen, failureGen)
Gen.result(successGen, failureGen, successProbability: 0.8)
```

### Enums

```swift
enum Color: CaseIterable {
    case red, green, blue
}

Gen.element(of: Color.allCases)

// With weights
Gen.frequency([
    (5, Gen.pure(.red)),
    (3, Gen.pure(.green)),
    (2, Gen.pure(.blue))
])
```

---

## Generator Combinators

### Pure (Constant)

```swift
// Always returns the same value
Gen.pure(42)
Gen.pure("constant")
```

### Map

Transform generated values:

```swift
let positiveInt = Gen<Int>.int.map { abs($0) }
let upperString = Gen<String>.string.map { $0.uppercased() }

// Multiple maps
let formatted = Gen<Int>.int
    .map { abs($0) }
    .map { String($0) }
    .map { "Value: \($0)" }
```

### FlatMap

Chain generators (when the next generator depends on a previous value):

```swift
let variableLengthString = Gen<Int>.int(in: 1...10).flatMap { length in
    Gen<String>.string(length: length)
}

let personGen = Gen<String>.string.flatMap { name in
    Gen<Int>.int(in: 0...120).map { age in
        Person(name: name, age: age)
    }
}
```

### Zip

Combine independent generators:

```swift
// Two values
let pointGen = Gen.zip(Gen<Int>.int, Gen<Int>.int)
    .map { Point(x: $0, y: $1) }

// Three values
let rgbGen = Gen.zip(
    Gen<UInt8>.uint,
    Gen<UInt8>.uint,
    Gen<UInt8>.uint
).map { RGB(r: $0, g: $1, b: $2) }

// Four values
let rectGen = Gen.zip(
    Gen<Int>.int, Gen<Int>.int,
    Gen<Int>.int, Gen<Int>.int
).map { Rect(x: $0, y: $1, width: $2, height: $3) }
```

### OneOf

Choose uniformly from multiple generators:

```swift
let mixedGen = Gen.oneOf([
    Gen<Int>.int.map { .integer($0) },
    Gen<String>.string.map { .string($0) },
    Gen<Bool>.bool.map { .boolean($0) }
])
```

### Frequency

Choose with weights:

```swift
let biasedGen = Gen.frequency([
    (7, Gen.pure("common")),      // 70%
    (2, Gen.pure("uncommon")),    // 20%
    (1, Gen.pure("rare"))         // 10%
])

// Common pattern: mostly valid, sometimes invalid
let inputGen = Gen.frequency([
    (9, validInputGen),
    (1, invalidInputGen)
])
```

### Element

Pick from a collection:

```swift
let dayGen = Gen.element(of: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
let colorGen = Gen.element(of: Color.allCases)
```

### Filter (suchThat)

Filter generated values (use sparingly!):

```swift
let evenGen = Gen<Int>.int.suchThat { $0 % 2 == 0 }
let nonEmptyGen = Gen<String>.string.suchThat { !$0.isEmpty }

// WARNING: If filter rejects too many values, test may give up
// Better: Generate directly what you need
let evenGen = Gen<Int>.int.map { $0 * 2 }  // Always even
```

### Recursive

Generate recursive data structures:

```swift
indirect enum Tree<T> {
    case leaf(T)
    case node(Tree<T>, Tree<T>)
}

let treeGen: Gen<Tree<Int>> = Gen.recursive { recurse in
    Gen.frequency([
        (3, Gen<Int>.int.map { Tree.leaf($0) }),
        (1, Gen.zip(recurse, recurse).map { Tree.node($0, $1) })
    ])
}
```

---

## Custom Generators

### Manual Construction

```swift
struct Person {
    let name: String
    let age: Int
    let email: String
}

extension Person {
    static var arbitrary: Gen<Person> {
        Gen.zip(
            Gen<String>.alphanumeric,
            Gen<Int>.int(in: 0...120),
            Gen<String>.alphanumeric.map { "\($0)@example.com" }
        ).map { Person(name: $0, age: $1, email: $2) }
    }
}
```

### Using @Arbitrary Macro

```swift
@Arbitrary
struct Person {
    let name: String
    let age: Int
    let email: String
}

// Automatically generates:
// extension Person {
//     static var arbitrary: Gen<Person> { ... }
// }
```

### Domain-Specific Generators

```swift
struct EmailGenerator {
    static var valid: Gen<String> {
        Gen.zip(
            Gen<String>.alphanumeric(length: 5...15),
            Gen.element(of: ["gmail.com", "yahoo.com", "example.com"])
        ).map { "\($0)@\($1)" }
    }
    
    static var invalid: Gen<String> {
        Gen.oneOf([
            Gen.pure(""),
            Gen.pure("@missing-local"),
            Gen.pure("missing-at.com"),
            Gen.pure("spaces in@email.com")
        ])
    }
}

struct PhoneNumberGenerator {
    static var us: Gen<String> {
        Gen.zip(
            Gen<Int>.int(in: 200...999),
            Gen<Int>.int(in: 200...999),
            Gen<Int>.int(in: 0000...9999)
        ).map { "(\($0)) \($1)-\(String(format: "%04d", $2))" }
    }
}
```

---

## Shrinking

Shrinking finds minimal counterexamples when tests fail.

### Built-in Shrinking

Most built-in generators shrink automatically:
- Integers shrink towards 0
- Strings shrink towards empty
- Arrays shrink by removing elements and shrinking remaining ones
- Optionals shrink to `nil`

### Custom Shrinking

```swift
struct PositiveInt {
    let value: Int
}

extension PositiveInt {
    static var arbitrary: Gen<PositiveInt> {
        Gen<Int>.int(in: 1...Int.max)
            .map { PositiveInt(value: $0) }
            .withShrink { pos in
                // Shrink towards 1 (the smallest positive int)
                Shrink.towards(1, pos.value).map { PositiveInt(value: $0) }
            }
    }
}
```

### Shrink Combinators

```swift
// Shrink towards a target
Shrink.towards(0, currentValue)

// Remove elements from array
Shrink.removeElements(from: array)

// Shrink each element
Shrink.shrinkElements(in: array, using: elementShrinker)

// Combine shrinking strategies
Shrink.concat([shrink1, shrink2, shrink3])
```

---

## Size and Distribution

### Size Parameter

Generators receive a `Size` parameter (typically 0-100) that controls "how big" generated values should be:

```swift
// Size affects:
// - String length
// - Array length
// - Integer magnitude
// - Recursion depth

// Small size = small values
// Large size = large values
```

### Scaling

```swift
// Scale generator output
let smallArrayGen = Gen.array(Gen<Int>.int).scale { $0 / 2 }

// Resize to specific size
let fixedSizeGen = Gen<String>.string.resize(to: 50)
```

### Distribution Control

```swift
// Uniform distribution (default)
Gen<Int>.int(in: 0...100)

// Boundary-focused (hits 0, 100 more often)
Gen<Int>.boundary(in: 0...100)

// Custom distribution
Gen<Int>.int.map { value in
    // Apply custom distribution
    Int(pow(Double(value), 2))
}
```

---

## Advanced Patterns

### Dependent Generators

When later values depend on earlier ones:

```swift
// Array where sum equals a target
func arrayWithSum(_ target: Int) -> Gen<[Int]> {
    Gen<Int>.int(in: 1...10).flatMap { count in
        var remaining = target
        var result: [Int] = []
        for i in 0..<count {
            if i == count - 1 {
                result.append(remaining)
            } else {
                let value = Int.random(in: 0...remaining)
                result.append(value)
                remaining -= value
            }
        }
        return Gen.pure(result)
    }
}
```

### Permutation Generator

```swift
func permutation<T>(of array: [T]) -> Gen<[T]> {
    guard !array.isEmpty else { return Gen.pure([]) }
    
    return Gen { rng, size in
        var result = array
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i, using: &rng)
            result.swapAt(i, j)
        }
        return result
    }
}
```

### Stateful Generation

```swift
// Generate valid state machine traces
func validTrace(machine: StateMachine) -> Gen<[Command]> {
    Gen.recursive { recurse in
        Gen.frequency([
            (1, Gen.pure([])),  // Empty trace
            (9, recurse.flatMap { previousCommands in
                let state = machine.execute(previousCommands)
                let validCommands = machine.validCommands(in: state)
                guard !validCommands.isEmpty else {
                    return Gen.pure(previousCommands)
                }
                return Gen.element(of: validCommands).map {
                    previousCommands + [$0]
                }
            })
        ])
    }
}
```

### Graph Generation

```swift
struct Graph<T> {
    var nodes: [T]
    var edges: [(Int, Int)]
}

func connectedGraph<T>(nodeGen: Gen<T>, nodeCount: Int) -> Gen<Graph<T>> {
    Gen.array(nodeGen, count: nodeCount).flatMap { nodes in
        // Generate spanning tree (ensures connectivity)
        var edges: [(Int, Int)] = []
        for i in 1..<nodeCount {
            let parent = Int.random(in: 0..<i)
            edges.append((parent, i))
        }
        
        // Add random extra edges
        let extraEdgeCount = Int.random(in: 0...nodeCount)
        for _ in 0..<extraEdgeCount {
            let from = Int.random(in: 0..<nodeCount)
            let to = Int.random(in: 0..<nodeCount)
            if from != to {
                edges.append((from, to))
            }
        }
        
        return Gen.pure(Graph(nodes: nodes, edges: edges))
    }
}
```

---

## Generator Middleware

Add cross-cutting concerns to generators without modifying code.

### GeneratorInterceptor Protocol

```swift
public protocol GeneratorInterceptor: Sendable {
  func onGenerate<T>(_ value: T, size: Size) -> T
  func onShrink<T>(_ original: T, shrunk: T, step: Int) -> T
  func onPropertyEvaluated<T>(_ value: T, passed: Bool)
}
```

### Built-in Interceptors

| Interceptor | Purpose |
|-------------|---------|
| LoggingInterceptor | Logs all operations to console |
| MetricsInterceptor | Collects generation/shrink statistics |
| ValidationInterceptor | Validates generated values |

### Attaching Interceptors

```swift
// Single interceptor
let gen = Gen<Int>.int.withInterceptor(LoggingInterceptor())

// Multiple interceptors (chained)
let gen = Gen<Int>.int.withInterceptors([
  LoggingInterceptor(),
  MetricsInterceptor()
])

// Convenience methods
let logged = Gen<Int>.int.logged()
let (gen, metrics) = Gen<Int>.int.withMetrics()
```

### Example: Collecting Metrics

```swift
let (gen, metrics) = Gen<Int>.int.withMetrics()

// Use generator in tests
for _ in 0..<100 {
  _ = gen.sample(size: Size.medium, seed: Seed.random())
}

// Inspect metrics
let stats = metrics.metrics
print("Generated \(stats.generationCount) values")
print("Average size: \(stats.averageSize)")
print("Shrink steps: \(stats.shrinkSteps)")
```

### Example: Custom Interceptor

```swift
class ValidationInterceptor: GeneratorInterceptor {
  func onGenerate<T>(_ value: T, size: Size) -> T {
    if let num = value as? Int, num < 0 {
      print("Warning: negative value \(num)")
    }
    return value
  }
}

let gen = Gen<Int>.int.withInterceptor(ValidationInterceptor())
```

---

## Generator Catalog CLI

Browse available generators interactively.

### Launch Interactive Browser

```bash
swift package browse-generators
```

This opens an interactive menu where you can:
- Browse generators by category
- Search by name
- View generator details
- Generate sample values

### Command-Line Usage

```bash
# List all generators
swift package browse-generators --list

# Search by name
swift package browse-generators --search email

# Filter by category
swift package browse-generators --category Numeric

# Generate sample value
swift package browse-generators --sample int-range
```

### Available Categories

| Category | Generators |
|----------|------------|
| Primitive | Bool, Character |
| Numeric | Int, Double, Float, Int8, Int16, Int32, Int64, UInt, UInt8, etc. |
| String | String (length variants), alphanumeric, alphabetic, ascii, unicode |
| Collection | Array, Set, Dictionary, NonEmptyArray |
| Composite | Tuple (2-4 components), Optional, Result |
| Domain Data | UUID, Date, URL, Data |

### CLI Help

```bash
swift package browse-generators --help
```

Shows all available options:
- `--list` — List all generators
- `--category <name>` — Filter by category
- `--search <term>` — Search by name
- `--sample <id>` — Generate sample value
- `--help` — Show help message

---

## Reference

### Type-Specific Generators

| Type | Generator | Notes |
|------|-----------|-------|
| `Int` | `Gen<Int>.int` | Scaled by size |
| `Int` | `Gen<Int>.int(in: range)` | Bounded |
| `Double` | `Gen<Double>.double` | Includes special values |
| `Bool` | `Gen<Bool>.bool` | 50/50 |
| `String` | `Gen<String>.string` | Variable length |
| `Character` | `Gen<Character>.letter` | a-z, A-Z |
| `UUID` | `Gen<UUID>.uuid` | Random UUID |
| `Date` | `Gen<Date>.date` | Random date |
| `Data` | `Gen<Data>.data` | Random bytes |
| `URL` | `Gen<URL>.url` | Random URL |

### Combinator Summary

| Combinator | Purpose | Example |
|------------|---------|---------|
| `pure` | Constant value | `Gen.pure(42)` |
| `map` | Transform | `gen.map { $0 * 2 }` |
| `flatMap` | Chain | `gen.flatMap { ... }` |
| `zip` | Combine | `Gen.zip(gen1, gen2)` |
| `oneOf` | Uniform choice | `Gen.oneOf([gen1, gen2])` |
| `frequency` | Weighted choice | `Gen.frequency([(3, gen1), (1, gen2)])` |
| `element` | Pick from collection | `Gen.element(of: array)` |
| `suchThat` | Filter | `gen.suchThat { predicate }` |
| `optional` | Make optional | `Gen.optional(gen)` |
| `array` | Make array | `Gen.array(gen)` |
| `recursive` | Recursive structures | `Gen.recursive { ... }` |

### Generator Protocol

```swift
public struct Gen<Value: Sendable>: Sendable {
    public let generate: @Sendable (inout SeededRNG, Size) -> Value
    
    public func map<U>(_ f: @escaping (Value) -> U) -> Gen<U>
    public func flatMap<U>(_ f: @escaping (Value) -> Gen<U>) -> Gen<U>
    public func suchThat(_ predicate: @escaping (Value) -> Bool) -> Gen<Value>
    public func withShrink(_ shrinker: @escaping (Value) -> [Value]) -> Gen<Value>
    public func scale(_ f: @escaping (Size) -> Size) -> Gen<Value>
    public func resize(to size: Size) -> Gen<Value>
}
```
