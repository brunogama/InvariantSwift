# CLAUDE.md - Tests

> **Sub-package CLAUDE.md** for `Tests/`
>
> Parent: [../CLAUDE.md](../CLAUDE.md) | See also: [AGENTS.md](AGENTS.md)

## Package Identity

| Attribute | Value |
|-----------|-------|
| **Purpose** | Test suites for InvariantSwift library and macros |
| **Framework** | Swift Testing (`@Test`, `@Suite`) |
| **Coverage Target** | 99%+ |

---

## Directory Structure

```
Tests/
├── InvariantSwiftTests/         # Core library tests (47 files)
│   ├── GeneratorTests.swift
│   ├── PropertyTests.swift
│   ├── ShrinkTests.swift
│   ├── FakerTests.swift
│   └── ...
├── InvariantSwiftMacroTests/    # Macro expansion tests (11 files)
│   ├── PropertyMacroTests.swift
│   ├── ArbitraryMacroTests.swift
│   ├── BusinessRuleMacroTests.swift
│   └── ...
├── PerformanceTests/            # Benchmarks
├── CoverageIntegrationTests/    # Integration tests
└── AGENTS.md                    # AI agent conventions
```

---

## Running Tests

### All Tests

```bash
swift test
just test-swift
```

### Filtered Tests

```bash
# Specific test file
swift test --filter GeneratorTests

# Specific test method (use / separator)
swift test --filter "PropertyTests/testPropertyHolds"

# Macro tests only
swift test --filter InvariantSwiftMacroTests
```

### Platform-Specific

```bash
just test-macos    # Xcode macOS
just test-ios      # iOS Simulator
just test-tvos     # tvOS Simulator
just test-linux    # Linux Docker
just test-safe     # SIGTRAP-protected (beta SDK)
```

### Coverage

```bash
swift test --enable-code-coverage
just coverage
```

---

## Test Patterns

### ✅ DO: Swift Testing Format

```swift
// See: InvariantSwiftTests/GeneratorTests.swift
import Testing
@testable import InvariantSwift

@Suite("Generator Tests")
struct GeneratorTests {
  
  @Test("Integer generator produces values in range")
  func integerInRange() {
    let gen = Gen<Int> { rng, size in
      Int.random(in: 0..<100, using: &rng)
    }
    let value = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(value >= 0 && value < 100)
  }
}
```

### ✅ DO: Deterministic Seeds for Reproducibility

```swift
// See: InvariantSwiftTests/FakerTests.swift
@Test("Same seed produces same output")
func determinism() {
  let gen = Gen<String>.faker(.email)
  let seed = Seed(value: 12345)
  
  let value1 = gen.sample(size: .medium, seed: seed)
  let value2 = gen.sample(size: .medium, seed: seed)
  
  #expect(value1 == value2)
}
```

### ✅ DO: Macro Expansion Tests

```swift
// See: InvariantSwiftMacroTests/PropertyMacroTests.swift
import SwiftSyntaxMacrosTestSupport

@Test("@PropertyTest expands correctly")
func testPropertyExpansion() throws {
  assertMacroExpansion(
    """
    @PropertyTest
    func addition(a: Int, b: Int) -> Bool { a + b == b + a }
    """,
    expandedSource: """
    // Expected expansion (whitespace-sensitive!)
    """,
    macros: testMacros
  )
}
```

### ✅ DO: Async Property Tests

```swift
@Test("Async property test")
func testAsyncProperty() async throws {
  let property = Property(generator: Gen<String>.string) { input in
    await asyncValidation(input)
  }
  try await checkPropertyAsync(property)
}
```

### ❌ DON'T: Use XCTest

```swift
// OLD - Don't use
import XCTest
class MyTests: XCTestCase { ... }

// NEW - Use Swift Testing
import Testing
@Suite struct MyTests { ... }
```

---

## Key Test Files

| File | Tests For |
|------|-----------|
| `InvariantSwiftTests/GeneratorTests.swift` | `Gen<T>` combinators |
| `InvariantSwiftTests/PropertyTests.swift` | Property test execution |
| `InvariantSwiftTests/ShrinkTests.swift` | Shrinking strategies |
| `InvariantSwiftTests/FakerTests.swift` | Faker generators |
| `InvariantSwiftMacroTests/PropertyMacroTests.swift` | @PropertyTest macro |
| `InvariantSwiftMacroTests/ArbitraryMacroTests.swift` | @Arbitrary macro |
| `InvariantSwiftMacroTests/BusinessRuleMacroTests.swift` | @BusinessRule macro |
| `InvariantSwiftMacroTests/StateMachineMacroTests.swift` | @StateMachine macro |

---

## Quick Find Commands (JIT Index)

```bash
# Find all test suites
rg -n "@Suite" Tests/

# Find tests for a component
rg -n "@Test.*ComponentName" Tests/

# Find failing test patterns
rg -n "#expect\(.*==.*false" Tests/

# Count total tests
rg -c "@Test" Tests/ | awk -F: '{sum += $2} END {print sum}'

# Find test helpers
rg -n "func make|func create|func build" Tests/

# Find macro expansion tests
rg -n "assertMacroExpansion" Tests/
```

---

## Common Gotchas

1. **Async tests**: Use `async throws` signature for property tests
2. **Test isolation**: Each test gets fresh state; don't share mutable state
3. **Deterministic seeds**: Always use explicit `Seed(value:)` for reproducibility
4. **Macro test context**: Must register macros in `testMacros` dictionary
5. **Whitespace sensitivity**: Macro expansion tests are whitespace-sensitive; match expected output exactly (including leading spaces)

---

## Pre-PR Checks

```bash
swift test && \
swift test --enable-code-coverage
```

---

## Related Documents

- [AGENTS.md](AGENTS.md) - General AI agent conventions for this directory
- [../CLAUDE.md](../CLAUDE.md) - Root project guidance
