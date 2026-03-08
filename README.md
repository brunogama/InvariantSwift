# InvariantSwift

<div align="center">

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-333333?style=for-the-badge)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-4BC51D?style=for-the-badge&logo=swift)](https://swift.org/package-manager/)

**The most advanced property-based testing framework for Swift**

[Getting Started](#getting-started) | [Documentation](docs/) | [Examples](Examples/) | [API Reference](#api-reference)

</div>

---

## What is Property-Based Testing?

Traditional unit tests verify specific examples:
```swift
// Example-based: tests ONE specific case
func testSort() {
    XCTAssertEqual([3, 1, 2].sorted(), [1, 2, 3])
}
```

Property-based tests verify **universal properties** across **thousands of auto-generated inputs**:
```swift
// Property-based: tests THOUSANDS of random cases
@PropertyTest
func testSortPreservesLength(array: [Int]) {
    #expect(array.sorted().count == array.count)
}
```

When a test fails, InvariantSwift automatically **shrinks** the counterexample to the **minimal failing case**, making debugging trivial.

---

## Features at a Glance

| Feature | Description |
|---------|-------------|
| **Automatic Generation** | 50+ built-in generators for Swift types |
| **Smart Shrinking** | Finds minimal counterexamples automatically |
| **Swift Macros** | `@PropertyTest`, `@Arbitrary`, `@Gen` for zero-boilerplate testing |
| **Swift Testing** | Native integration with Apple's Swift Testing framework |
| **Async Support** | Full Swift 6 concurrency with async properties |
| **Coverage-Guided** | Adaptive generation based on code coverage |
| **Model-Based Testing** | Test complex state machines against reference models |
| **Diff-Based Failures** | Clear, colorful diff output for debugging |

---

## Getting Started

### Installation

Add InvariantSwift to your `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyProject",
    dependencies: [
        .package(url: "https://github.com/your-org/InvariantSwift", from: "1.0.1")
    ],
    targets: [
        .testTarget(
            name: "MyProjectTests",
            dependencies: ["InvariantSwift"]
        )
    ]
)
```

### Your First Property Test

```swift
import Testing
import InvariantSwift

@Test("Reversing an array twice returns the original")
func testDoubleReverse() async throws {
    let property = Property(generator: Gen.array(Gen<Int>.int)) { array in
        array.reversed().reversed() == Array(array)
    }
    try await checkProperty(property)
}
```

### Using the @PropertyTest Macro (Recommended)

The `@PropertyTest` macro automatically infers generators from parameter types:

```swift
import Testing
import InvariantSwift

@PropertyTest
func testAdditionCommutative(a: Int, b: Int) {
    #expect(a + b == b + a)
}

@PropertyTest
func testStringConcatLength(s1: String, s2: String) {
    #expect((s1 + s2).count == s1.count + s2.count)
}

@PropertyTest(iterations: 500, seed: 42)
func testArrayAppendIncreasesCount(array: [Int], element: Int) {
    var copy = array
    copy.append(element)
    #expect(copy.count == array.count + 1)
}
```

---

## Generators

InvariantSwift provides a rich library of composable generators.

### Primitive Types

```swift
Gen<Int>.int                    // Any Int
Gen<Int>.int(in: 0...100)       // Int in range
Gen<Double>.double              // Any Double
Gen<Bool>.bool                  // true or false
Gen<String>.string              // Random string
Gen<String>.alphanumeric        // Letters and numbers only
Gen<Character>.letter           // a-z, A-Z
```

### Collections

```swift
Gen.array(Gen<Int>.int)                      // [Int]
Gen.array(Gen<Int>.int, count: 5)            // Exactly 5 elements
Gen.array(Gen<Int>.int, count: 1...10)       // 1 to 10 elements
Gen.set(Gen<String>.string)                  // Set<String>
Gen.dictionary(Gen<String>.string, Gen<Int>.int)  // [String: Int]
```

### Optionals and Results

```swift
Gen.optional(Gen<Int>.int)                   // Int?
Gen.optional(Gen<Int>.int, nilProbability: 0.3)  // 30% chance of nil
Gen.result(Gen<String>.string, Gen<Error>.error) // Result<String, Error>
```

### Combining Generators

```swift
// Map: transform generated values
let positiveInt = Gen<Int>.int.map { abs($0) }

// FlatMap: chain generators
let personGen = Gen<String>.string.flatMap { name in
    Gen<Int>.int(in: 0...120).map { age in
        Person(name: name, age: age)
    }
}

// Zip: combine multiple generators
let pointGen = Gen.zip(Gen<Int>.int, Gen<Int>.int).map { Point(x: $0, y: $1) }

// OneOf: choose from multiple generators
let numberGen = Gen.oneOf([
    Gen<Int>.int(in: 0...10),
    Gen<Int>.int(in: 100...1000),
    Gen.pure(42)
])

// Frequency: weighted choice
let biasedGen = Gen.frequency([
    (3, Gen.pure("common")),
    (1, Gen.pure("rare"))
])
```

### Custom Type Generators

#### Using @Arbitrary Macro

```swift
@Arbitrary
struct User {
    let id: UUID
    let name: String
    let age: Int
}

// Now you can use User directly in @PropertyTest:
@PropertyTest
func testUserSerialization(user: User) {
    let encoded = try! JSONEncoder().encode(user)
    let decoded = try! JSONDecoder().decode(User.self, from: encoded)
    #expect(decoded == user)
}
```

#### Manual Generator

```swift
struct Point {
    let x: Int
    let y: Int
}

extension Point {
    static var arbitrary: Gen<Point> {
        Gen.zip(Gen<Int>.int, Gen<Int>.int).map { Point(x: $0, y: $1) }
    }
}
```

---

## Shrinking

When a property fails, InvariantSwift automatically finds the **smallest counterexample**:

```swift
@PropertyTest
func testAllPositive(numbers: [Int]) {
    #expect(numbers.allSatisfy { $0 > 0 })
}
```

Output:
```
Property failed after 23 iterations.

Counterexample:
  [847, -291, 553, 102, -847, 291]

Shrunk counterexample:
  [-1]

Seed: 98234
```

The shrinking algorithm automatically reduced a 6-element array to a single element `[-1]` - the minimal case that still fails.

### Custom Shrinking

```swift
struct PositiveInt {
    let value: Int
    
    static var arbitrary: Gen<PositiveInt> {
        Gen<Int>.int(in: 1...Int.max)
            .map { PositiveInt(value: $0) }
            .withShrink { pos in
                // Shrink towards 1
                Shrink.towards(1, pos.value).map { PositiveInt(value: $0) }
            }
    }
}
```

---

## Macros

InvariantSwift provides powerful macros for expressive, boilerplate-free testing.

### @PropertyTest

Automatically generates a property test from a function with typed parameters:

```swift
@PropertyTest
func testProperty(param1: Type1, param2: Type2) {
    // test body
}

// Options
@PropertyTest(iterations: 1000)      // Number of test cases
@PropertyTest(seed: 42)              // Reproducible seed
@PropertyTest(maxSize: 50)           // Maximum size for generators
```

### @Arbitrary

Synthesizes a generator for a struct or class:

```swift
@Arbitrary
struct Config {
    let timeout: Int
    let retries: Int
    let enabled: Bool
}

// Equivalent to:
extension Config {
    static var arbitrary: Gen<Config> {
        Gen.zip(Gen<Int>.int, Gen<Int>.int, Gen<Bool>.bool)
            .map { Config(timeout: $0, retries: $1, enabled: $2) }
    }
}
```

### @Gen

Override automatic generator inference for specific parameters:

```swift
@PropertyTest
func testWithCustomGen(
    @Gen(.int(in: 1...100)) positiveNumber: Int,
    @Gen(.string(length: 5...10)) shortString: String
) {
    #expect(positiveNumber > 0)
    #expect(shortString.count >= 5)
}
```

### @Label

Provide descriptive labels for counterexample output:

```swift
@PropertyTest
func testUserValidation(
    @Label("User's Age") age: Int,
    @Label("Account Balance") balance: Double
) {
    // Labels appear in failure output
}
```

---

## Test Assertions

### expectNoDifference

Assert equality with detailed diff output on failure:

```swift
expectNoDifference(actual, expected)
```

Failure output:
```
Difference detected:

- name: "Alice"
+ name: "Bob"
  age: 30

(First: -, Second: +)
```

### expectDifference

Assert that a value changes in expected ways:

```swift
var counter = Counter(count: 0)

expectDifference(counter) {
    counter.increment()
} changes: {
    $0.count = 1
}
```

---

## Advanced Features

### Coverage-Guided Generation

Automatically prioritize inputs that explore new code paths:

```swift
let property = Property(generator: myGen) { input in
    // InvariantSwift tracks which branches are covered
    // and generates inputs that maximize coverage
    complexFunction(input)
}

try await checkProperty(property, config: PropertyConfig(
    enableCoverage: true,
    coverageStrategy: .adaptive
))
```

### Model-Based Testing

Test implementations against reference models:

```swift
// Define commands
enum StackCommand {
    case push(Int)
    case pop
    case peek
}

// Test against model
@Test("Stack matches model behavior")
func testStackModel() async throws {
    let property = Property(generator: Gen.array(StackCommand.generator)) { commands in
        let model = ArrayStack()       // Simple reference implementation
        let sut = OptimizedStack()     // System under test
        
        for command in commands {
            switch command {
            case .push(let value):
                model.push(value)
                sut.push(value)
            case .pop:
                guard model.pop() == sut.pop() else { return false }
            case .peek:
                guard model.peek() == sut.peek() else { return false }
            }
        }
        return true
    }
    try await checkProperty(property)
}
```

### Async Property Testing

Full support for async properties:

```swift
@Test("Async property test")
func testAsyncOperation() async throws {
    let property = Property(generator: Gen<String>.string) { input in
        let result = await processAsync(input)
        return result.isValid
    }
    try await checkPropertyAsync(property)
}
```

### Stateful Testing

Test sequences of operations:

```swift
@StateMachine
struct DatabaseStateMachine {
    var records: [String: Int] = [:]
    
    mutating func insert(key: String, value: Int) {
        records[key] = value
    }
    
    mutating func delete(key: String) {
        records.removeValue(forKey: key)
    }
    
    func get(key: String) -> Int? {
        records[key]
    }
}
```

---

## Configuration

### PropertyConfig

```swift
let config = PropertyConfig(
    iterations: 1000,        // Number of test cases
    maxSize: 100,            // Maximum generator size
    maxShrinks: 1000,        // Maximum shrink attempts
    timeout: 30.0,           // Timeout per property
    seed: 42,                // Reproducible seed (nil for random)
    enableCoverage: true,    // Track code coverage
    coverageStrategy: .adaptive  // Coverage-guided generation
)
```

### PrettyConfig

```swift
let config = PrettyConfig(
    pageWidth: 80,           // Output width
    enableColors: true,      // ANSI colors
    maxDepth: 10,            // Nesting depth limit
    maxLength: 100           // Collection element limit
)
```

---

## CLI Tool

The `functest` CLI provides command-line testing capabilities:

```bash
# Run all property tests
swift run functest

# Run with specific iterations
swift run functest --iterations 5000

# Generate coverage report
swift run functest --coverage --report html

# Reproducible run with seed
swift run functest --seed 12345

# Verbose output
swift run functest --verbose
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/QUICKSTART.md) | Quick start guide |
| [Generators](docs/GENERATORS.md) | Complete generator reference |
| [Macros](docs/MACROS.md) | Macro system documentation |
| [Pretty Printing](docs/PRETTY_PRINTING.md) | Diff and formatting system |
| [Advanced Features](docs/ADVANCED.md) | Coverage, model-based, DICE |
| [API Reference](docs/API_DOCUMENTATION_TEMPLATE.md) | Full API documentation |
| [Contributing](CONTRIBUTING.md) | Contribution guidelines |

---

## Examples

The [Examples/](Examples/) directory contains:

- **BasicExamples/** - Getting started with property testing
- **IntermediateExamples/** - Generator composition, custom types
- **AdvancedExamples/** - Model-based testing, coverage-guided, async

---

## Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 17.0+ |
| macOS | 14.0+ |
| tvOS | 17.0+ |
| watchOS | 10.0+ |
| Linux | Swift 6.0+ |

**Swift Version:** 6.0+

---

## Performance

InvariantSwift is optimized for high-throughput testing:

| Metric | Performance |
|--------|-------------|
| Primitive generation | 50,000+ ops/sec |
| Complex type generation | 10,000+ ops/sec |
| Shrinking | Sub-second for most cases |
| Memory | Lazy evaluation, minimal footprint |
| Concurrency | Linear scaling with cores |

---

## Acknowledgments

This project incorporates substantial work from [Point-Free](https://www.pointfree.co/), whose open-source Swift libraries have been instrumental in building InvariantSwift. In particular:

- **[swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump)** - The diff-based assertions and pretty-printing system
- **[swift-gen](https://github.com/pointfreeco/swift-gen)** - Core generator concepts and functional composition patterns

We are grateful to [Brandon Williams](https://github.com/mbrandonw) and [Stephen Celis](https://github.com/stephencelis) for their excellent work on property-based testing foundations in Swift.

## Inspiration

InvariantSwift also builds on ideas from:

- [QuickCheck](https://hackage.haskell.org/package/QuickCheck) (Haskell) - The original property-based testing library
- [Hypothesis](https://hypothesis.readthedocs.io/) (Python) - Coverage-guided testing
- [Hedgehog](https://hedgehog.qa/) - Integrated shrinking

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)

---

## License

InvariantSwift is released under the MIT license. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with care for the Swift community**

[Report Bug](https://github.com/your-org/InvariantSwift/issues) | [Request Feature](https://github.com/your-org/InvariantSwift/issues) | [Discussions](https://github.com/your-org/InvariantSwift/discussions)

</div>
