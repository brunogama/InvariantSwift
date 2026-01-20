# Deterministic Generation

**Reproducible random value generation in InvariantSwift.**

---

## Overview

Deterministic generation is essential for:
- Reproducing test failures
- Debugging property tests
- Regression testing
- CI/CD consistency

## How It Works

InvariantSwift uses seeded random number generation. Given the same:
- **Seed value**
- **Size parameter**

A generator will produce the **exact same sequence** of values.

## Using Seeds

### Explicit Seed

```swift
let seed = Seed(value: 42)
let gen = Gen.int

// Always produces the same sequence
let value1 = gen.sample(seed: seed)  // e.g., 7392
let value2 = gen.sample(seed: seed)  // also 7392
```

### In Property Tests

```swift
let config = PropertyConfig(
    iterations: 100,
    seed: Seed(value: 42)
)

try await checkProperty(property, config: config)
```

### Environment Variable

For CI reproduction:
```bash
INVARIANT_SWIFT_SEED=12345 swift test
```

## Capturing Seeds from Failures

When a property fails, the seed is included in the error message:

```
Property failed after 42 tests

Counterexample: [2, 1]
Seed: 12345

To reproduce: swift test --filter testName --env INVARIANT_SWIFT_SEED=12345
```

## Verifying Determinism

Use `GeneratorTestHelpers` to verify your generators:

```swift
let result = GeneratorTestHelpers.checkDeterminism(
    generator: myGen,
    seed: 12345,
    samples: 100,
    runs: 3
)

assert(result.passed)  // All 3 runs produced identical sequences
```

## Complete Example

```swift
import Testing
import InvariantSwift

@Test func reproducibleFailure() async throws {
    // Seed from previous failure
    let debugSeed = Seed(value: 12345)
    
    let property = Property(generator: Gen.array(of: Gen.int)) { array in
        array.sorted() == array.sorted().sorted()
    }
    
    let config = PropertyConfig(seed: debugSeed)
    try await checkProperty(property, config: config)
    // Will fail with the exact same counterexample
}
```

## Best Practices

1. **Log seeds in CI**: Always capture seeds from failures
2. **Use persistent failures**: `FailurePersistenceManager` saves seeds automatically
3. **Test seed stability**: Verify generators with `checkDeterminism`
4. **Don't rely on system randomness** for regression tests
