# Swift Testing Integration Guide

**Using InvariantSwift with Apple's Swift Testing framework.**

---

## Overview

InvariantSwift integrates seamlessly with Swift Testing, allowing you to write property-based tests using the `@Test` macro and Swift Testing's assertion system.

## Quick Start

### Basic Property Test

```swift
import Testing
import InvariantSwift

@Test func testSortingIsIdempotent() async throws {
    let property = Property(generator: Gen.array(of: Gen.int)) { array in
        array.sorted() == array.sorted().sorted()
    }
    
    try await checkProperty(property)
}
```

### Using @PropertyTest Macro

```swift
import Testing
import InvariantSwift

@PropertyTest("Array reverse is involutive")
func testReverseInvolution(xs: [Int]) {
    #expect(xs.reversed().reversed() == Array(xs))
}
```

## Integration Features

### Failure Reporting

Property failures are reported through Swift Testing's issue system:

```
Property failed after 42 tests (predicate returned false)

Counterexample: [2, 1]

Seed: 12345
To reproduce: swift test --filter testSorting --env INVARIANT_SWIFT_SEED=12345
```

### Async Properties

Test async code with the async variant:

```swift
@Test func testAsyncOperation() async throws {
    let property = Property(generator: Gen.int) { n in
        await someAsyncOp(n) != nil
    }
    
    try await checkPropertyAsync(property)
}
```

### Configuration

Control test behavior with `PropertyConfig`:

```swift
let config = PropertyConfig(
    iterations: 1000,      // Number of test cases
    maxShrinks: 500,       // Maximum shrink attempts
    seed: Seed(value: 42)  // Reproducible seed
)

try await checkProperty(property, config: config)
```

## Advanced Usage

### Test Statistics

Collect metrics about your property tests:

```swift
let collector = StatisticsCollector(testName: "myTest")
// ... run property with statistics collection ...
let stats = collector.finalize()
print(stats.formatted())
```

### Failure Persistence

Save failing cases for later analysis:

```swift
let manager = FailurePersistenceManager()

// Failures are automatically saved
// Replay with:
let failures = try manager.loadAll()
```

### Custom Generators via Registry

Register generators for custom types:

```swift
let userGen = Gen<User> { rng, size in
    User(
        id: Int.random(in: 1...1000, using: &rng),
        name: "User\(Int.random(in: 1...100, using: &rng))"
    )
}

await GeneratorRegistry.shared.register(for: User.self, generator: userGen)

// Now @PropertyTest can use User parameters automatically
```

## Best Practices

1. **Use meaningful test names**: They appear in failure messages
2. **Set seeds for debugging**: Reproduce failures exactly
3. **Keep properties fast**: Avoid I/O or network in properties
4. **Use assumptions sparingly**: Too many discards = slow tests
5. **Review shrunk counterexamples**: They reveal minimal failing cases

## Troubleshooting

### Tests Time Out

- Reduce `iterations` count
- Check for infinite loops in property closure
- Ensure generators terminate

### Too Many Discards

- Loosen assumptions with `suchThat`
- Use more targeted generators
- Check for contradictory assumptions

### Non-Deterministic Failures

- Always use `Seed` for debugging
- Check for global mutable state
- Ensure generators are deterministic
