# AGENTS.md - Tests

> **Sub-package AGENTS.md** for `Tests/`

## Package Identity

**Purpose:** Test suites for InvariantSwift library and macros  
**Framework:** Swift Testing (`@Test`, `@Suite`)  
**Coverage Target:** 99%+

---

## Directory Structure

```
Tests/
├── FunctionalTesting/           # Core library tests (47 files)
│   ├── GeneratorTests.swift     # Gen<T> combinator tests
│   ├── PropertyTests.swift      # Property execution tests
│   ├── ShrinkTests.swift        # Shrinking algorithm tests
│   ├── FakerTests.swift         # Faker generator tests
│   ├── GhostwriterTests.swift   # Auto-test generation tests
│   ├── LensSystemTests.swift    # Optics tests
│   ├── ModelBasedTests.swift    # State machine tests
│   └── ...
├── InvariantSwiftMacroTests/    # Macro expansion tests (11 files)
│   ├── PropertyMacroTests.swift
│   ├── ArbitraryMacroTests.swift
│   ├── BusinessRuleMacroTests.swift
│   ├── StateMachineMacroTests.swift
│   └── ...
├── PerformanceTests/            # Benchmarks
└── CoverageIntegrationTests/    # Integration tests
```

---

## Running Tests

```bash
# All tests
swift test

# Specific test file
swift test --filter GeneratorTests

# Specific test method (use / separator)
swift test --filter "PropertyTests/testPropertyHolds"

# Macro tests only
swift test --filter InvariantSwiftMacroTests

# With coverage
swift test --enable-code-coverage

# Platform-specific
make test-macos    # Xcode macOS
make test-ios      # iOS Simulator
make test-tvos     # tvOS Simulator
make test-safe     # With SIGTRAP crash protection (beta SDK)
```

---

## Test Patterns

### ✅ DO: Swift Testing Format

```swift
// See: FunctionalTesting/GeneratorTests.swift
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

### ✅ DO: Macro Expansion Tests

```swift
// See: InvariantSwiftMacroTests/PropertyMacroTests.swift
import SwiftSyntaxMacrosTestSupport

@Test("@Property expands correctly")
func testPropertyExpansion() throws {
  assertMacroExpansion(
    """
    @Property
    func addition(a: Int, b: Int) -> Bool { a + b == b + a }
    """,
    expandedSource: """
    // Expected expansion - WHITESPACE MATTERS!
    """,
    macros: testMacros
  )
}
```

### ✅ DO: Deterministic seeds for reproducibility

```swift
// See: FunctionalTesting/FakerTests.swift
@Test("Same seed produces same output")
func determinism() {
  let gen = Gen<String>.faker(.email)
  let seed = Seed(value: 12345)
  
  let value1 = gen.sample(size: .medium, seed: seed)
  let value2 = gen.sample(size: .medium, seed: seed)
  
  #expect(value1 == value2)
}
```

### ✅ DO: Use explicit type annotations for generics

```swift
// See: FunctionalTesting/LensSystemTests.swift
// When generic inference fails, provide explicit types
let lens: Lens<Person, String> = \.name
let composed = lens.then(otherLens)
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

## Touch Points / Key Test Files

| File | Tests For |
|------|-----------|
| `FunctionalTesting/GeneratorTests.swift` | `Gen<T>` combinators |
| `FunctionalTesting/PropertyTests.swift` | Property test execution |
| `FunctionalTesting/ShrinkTests.swift` | Shrinking strategies |
| `FunctionalTesting/FakerTests.swift` | Faker generators |
| `FunctionalTesting/FuzzDataProviderTests.swift` | LibFuzzer integration |
| `FunctionalTesting/RegressionBankTests.swift` | Regression test banking |
| `FunctionalTesting/LensSystemTests.swift` | Lens/Prism optics |
| `FunctionalTesting/ModelBasedTests.swift` | State machine testing |
| `InvariantSwiftMacroTests/PropertyMacroTests.swift` | @Property macro |
| `InvariantSwiftMacroTests/ArbitraryMacroTests.swift` | @Arbitrary macro |
| `InvariantSwiftMacroTests/BusinessRuleMacroTests.swift` | @BusinessRule macro |
| `InvariantSwiftMacroTests/StateMachineMacroTests.swift` | @StateMachine macro |

---

## JIT Index Hints

```bash
# Find all test suites
rg -n "@Suite" Tests/

# Find tests for a component
rg -n "@Test.*ComponentName" Tests/

# Find failing test patterns
rg -n "#expect\(.*==.*false" Tests/

# Count tests
rg -c "@Test" Tests/ | awk -F: '{sum += $2} END {print sum}'

# Find test helpers
rg -n "func make|func create|func build" Tests/

# Find macro test expansions
rg -n "assertMacroExpansion" Tests/

# Find tests using specific seed
rg -n "Seed\(value:" Tests/
```

---

## Common Gotchas

1. **Async tests** - Use `async throws` signature for property tests
2. **Test isolation** - Each test gets fresh state; don't share mutable state
3. **Deterministic seeds** - Always use explicit `Seed(value:)` for reproducibility
4. **Macro test context** - Must register macros in `testMacros` dictionary
5. **Whitespace in macro tests** - `assertMacroExpansion` is whitespace-sensitive; match indentation exactly
6. **Generic type inference** - Provide explicit type annotations when Swift can't infer

---

## Pre-PR Checks

```bash
swift test && swift test --enable-code-coverage
```
