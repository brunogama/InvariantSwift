# Getting Started with InvariantSwift

This guide walks you through setting up InvariantSwift and writing your first property-based tests.

## Table of Contents

1. [Installation](#installation)
2. [Your First Property Test](#your-first-property-test)
3. [Understanding the Output](#understanding-the-output)
4. [Using Macros](#using-macros)
5. [Working with Generators](#working-with-generators)
6. [Handling Failures](#handling-failures)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps](#next-steps)

---

## Installation

### Swift Package Manager

Add InvariantSwift to your `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyProject",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    dependencies: [
        .package(
            url: "https://github.com/your-org/InvariantSwift",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(name: "MyProject"),
        .testTarget(
            name: "MyProjectTests",
            dependencies: [
                "MyProject",
                "InvariantSwift"
            ]
        )
    ]
)
```

### Xcode

1. File > Add Package Dependencies
2. Enter the repository URL
3. Select your test target

### Verify Installation

```bash
swift build
swift test
```

---

## Your First Property Test

### Step 1: Create a Test File

Create a new test file, e.g., `PropertyTests.swift`:

```swift
import Testing
import InvariantSwift

@Suite("My Property Tests")
struct PropertyTests {
    
}
```

### Step 2: Write a Simple Property

Let's test that sorting an array preserves its length:

```swift
import Testing
import InvariantSwift

@Suite("Array Property Tests")
struct ArrayPropertyTests {
    
    @Test("Sorting preserves array length")
    func testSortingPreservesLength() async throws {
        let property = Property(generator: Gen.array(Gen<Int>.int)) { array in
            array.sorted().count == array.count
        }
        
        try await checkProperty(property)
    }
}
```

### Step 3: Run the Test

```bash
swift test --filter testSortingPreservesLength
```

Output:
```
Test Suite 'ArrayPropertyTests' started
Test 'testSortingPreservesLength' passed after 100 iterations
```

---

## Understanding the Output

### Successful Test

```
Property passed after 100 iterations.
```

This means the property held true for 100 randomly generated test cases.

### Failed Test

```
Property failed after 23 iterations (predicateFailed).

Counterexample:
  [847, -291, 553, 102, -847, 291]

Shrunk counterexample:
  [-1]

Seed: 98234
```

Key information:
- **Counterexample**: The original failing input
- **Shrunk counterexample**: The minimal failing case (easier to debug!)
- **Seed**: Use this to reproduce the exact failure

### Reproducing a Failure

```swift
try await checkProperty(property, config: PropertyConfig(seed: 98234))
```

---

## Using Macros

The `@PropertyTest` macro eliminates boilerplate by automatically inferring generators.

### Basic Usage

```swift
import Testing
import InvariantSwift

// Without macro (verbose)
@Test("Addition is commutative")
func testAdditionCommutativeVerbose() async throws {
    let property = Property(
        generator: Gen.zip(Gen<Int>.int, Gen<Int>.int)
    ) { (a, b) in
        a + b == b + a
    }
    try await checkProperty(property)
}

// With macro (concise)
@PropertyTest
func testAdditionCommutative(a: Int, b: Int) {
    #expect(a + b == b + a)
}
```

### Multiple Parameters

```swift
@PropertyTest
func testStringConcatenation(s1: String, s2: String, s3: String) {
    // Associativity
    #expect((s1 + s2) + s3 == s1 + (s2 + s3))
}
```

### Configuration Options

```swift
@PropertyTest(iterations: 500)
func testWithMoreIterations(value: Int) {
    #expect(value * 2 / 2 == value || value == Int.min)
}

@PropertyTest(seed: 42)
func testReproducible(array: [Int]) {
    // Always runs with the same random seed
    #expect(array.reversed().reversed() == array)
}

@PropertyTest(iterations: 1000, maxSize: 50)
func testWithConfig(data: [String]) {
    #expect(data.count <= 50)  // maxSize limits collection size
}
```

---

## Working with Generators

### Built-in Generators

```swift
// Integers
Gen<Int>.int                    // Any Int
Gen<Int>.int(in: 0...100)       // In range
Gen<Int8>.int                   // Int8
Gen<UInt>.uint                  // Unsigned

// Floating point
Gen<Double>.double              // Any Double
Gen<Float>.float                // Any Float

// Strings
Gen<String>.string              // Random string
Gen<String>.alphanumeric        // [a-zA-Z0-9]+
Gen<String>.string(length: 5)   // Exact length
Gen<String>.string(length: 1...10)  // Length range

// Collections
Gen.array(Gen<Int>.int)         // [Int]
Gen.set(Gen<String>.string)     // Set<String>
Gen.dictionary(keyGen, valueGen) // [K: V]

// Optionals
Gen.optional(Gen<Int>.int)      // Int?
```

### Combining Generators

```swift
// Transform values
let positiveGen = Gen<Int>.int.map { abs($0) + 1 }

// Chain generators
let personGen = Gen<String>.string.flatMap { name in
    Gen<Int>.int(in: 0...120).map { age in
        Person(name: name, age: age)
    }
}

// Combine multiple
let pointGen = Gen.zip(Gen<Int>.int, Gen<Int>.int)
    .map { Point(x: $0, y: $1) }
```

### Custom Type with @Arbitrary

```swift
@Arbitrary
struct User {
    let id: UUID
    let name: String
    let email: String
    let age: Int
}

// Now usable in @PropertyTest
@PropertyTest
func testUserValidation(user: User) {
    #expect(user.age >= 0 || user.age < 0)  // Always true
}
```

---

## Handling Failures

### Understanding Shrinking

When a test fails, InvariantSwift automatically shrinks the counterexample:

```swift
@PropertyTest
func testAllPositive(numbers: [Int]) {
    #expect(numbers.allSatisfy { $0 >= 0 })
}
```

Failure process:
1. **Find failure**: `[847, -291, 553, 102, -847, 291]`
2. **Shrink array**: Remove elements, keep failure
3. **Shrink values**: Make numbers smaller
4. **Result**: `[-1]` - the minimal failing case

### Debugging with Seeds

Always note the seed from failures:

```swift
// Original failure output:
// Seed: 98234

// Reproduce exactly:
@PropertyTest(seed: 98234)
func testDebugSpecificFailure(data: [Int]) {
    // Debug the exact failure case
}
```

### Using expectNoDifference

For complex types, use diff-based assertions:

```swift
struct Config: Equatable {
    var timeout: Int
    var retries: Int
    var enabled: Bool
}

@PropertyTest
func testConfigRoundtrip(config: Config) {
    let encoded = try! JSONEncoder().encode(config)
    let decoded = try! JSONDecoder().decode(Config.self, from: encoded)
    
    // Shows detailed diff on failure
    expectNoDifference(decoded, config)
}
```

---

## Best Practices

### 1. Test Properties, Not Examples

```swift
// Bad: Tests one specific case
@Test func testSort() {
    #expect([3, 1, 2].sorted() == [1, 2, 3])
}

// Good: Tests a universal property
@PropertyTest
func testSortIdempotent(array: [Int]) {
    #expect(array.sorted().sorted() == array.sorted())
}
```

### 2. Choose Meaningful Properties

Common property patterns:

```swift
// Roundtrip / Inverse
@PropertyTest
func testEncodeDecodeRoundtrip(value: MyType) {
    let encoded = encode(value)
    let decoded = decode(encoded)
    #expect(decoded == value)
}

// Idempotence
@PropertyTest
func testIdempotent(input: String) {
    let once = normalize(input)
    let twice = normalize(once)
    #expect(once == twice)
}

// Invariant preservation
@PropertyTest
func testInvariant(items: [Item]) {
    var collection = Collection(items)
    collection.sort()
    #expect(collection.count == items.count)
}

// Commutativity
@PropertyTest
func testCommutative(a: Int, b: Int) {
    #expect(a + b == b + a)
}

// Associativity
@PropertyTest
func testAssociative(a: String, b: String, c: String) {
    #expect((a + b) + c == a + (b + c))
}
```

### 3. Use Appropriate Iteration Counts

```swift
// Simple properties: 100 iterations (default)
@PropertyTest
func testSimple(n: Int) { ... }

// Complex state: 500-1000 iterations
@PropertyTest(iterations: 500)
func testStateMachine(commands: [Command]) { ... }

// Critical paths: 5000+ iterations
@PropertyTest(iterations: 5000)
func testSecurityProperty(input: Data) { ... }
```

### 4. Constrain Generators When Needed

```swift
// Don't test with unbounded data when not needed
@PropertyTest
func testBadPerformance(hugeArray: [Int]) {
    // This might generate arrays with millions of elements!
}

// Constrain to reasonable sizes
@PropertyTest
func testGoodPerformance(
    @Gen(.array(.int, count: 0...100)) reasonableArray: [Int]
) {
    // Bounded to 100 elements
}
```

---

## Troubleshooting

### Swift test fails?

```bash
swift package resolve
swift package clean
rm -rf .build
swift test
```

### Missing tools?

```bash
# Install development tools
brew install swiftlint swift-format xcbeautify

# Or use make
make setup
```

### Pre-commit issues?

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

### Flaky tests?

Use a fixed seed to make tests deterministic:

```swift
@PropertyTest(seed: 42)
func testDeterministic(value: Int) {
    // Always runs with seed 42
}
```

### Slow tests?

Reduce iteration count during development:

```swift
@PropertyTest(iterations: 10)  // Quick feedback
func testDuringDevelopment(data: [Int]) {
    // ...
}
```

---

## Next Steps

Now that you understand the basics:

1. **[Generators Guide](GENERATORS.md)** - Deep dive into generators
2. **[Macros Guide](MACROS.md)** - All macro options
3. **[Pretty Printing](PRETTY_PRINTING.md)** - Diff-based assertions
4. **[Advanced Features](ADVANCED.md)** - Coverage-guided, model-based testing
5. **[Full Onboarding](ONBOARDING.md)** - Comprehensive guide
6. **[Examples](../Examples/)** - Real-world examples

### Quick Reference

| Task | Code |
|------|------|
| Basic property test | `@PropertyTest func test(x: Int) { ... }` |
| Custom iterations | `@PropertyTest(iterations: 500)` |
| Reproducible seed | `@PropertyTest(seed: 42)` |
| Custom generator | `@Gen(.int(in: 1...100)) x: Int` |
| Arbitrary type | `@Arbitrary struct MyType { ... }` |
| Diff assertion | `expectNoDifference(a, b)` |
| Async property | `try await checkPropertyAsync(property)` |

---

Ready to dive deeper? See [ONBOARDING.md](ONBOARDING.md) for the complete guide.
