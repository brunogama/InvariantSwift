# Testing Patterns

**Analysis Date:** 2026-01-23

## Test Framework

**Runner:**
- Framework: Swift Testing (`@Test`, `@Suite` attributes)
- Configuration file: None (Swift Testing is zero-config)
- Package: Built into Swift 6.0+ standard library

**Assertion Library:**
- Framework: Swift Testing native assertions (`#expect`, `#require`)
- No external assertion libraries required

**Run Commands:**
```bash
swift test                                    # Run all tests
swift test --filter FunctionalTesting         # Run core library tests
swift test --filter InvariantSwiftMacroTests  # Run macro tests
swift test --filter "PropertyTests/propertyResultSuccessCase"  # Single test
swift test --enable-code-coverage             # Generate coverage
make test-swift                               # Run with xcbeautify formatting
make validate                                 # Build strict + lint + test
```

**Platform-specific testing:**
```bash
make test-macos     # Xcode macOS tests
make test-ios       # iOS Simulator tests
make test-tvos      # tvOS Simulator tests
make test-linux     # Linux Docker tests
make test-safe      # SIGTRAP-protected tests (beta SDK)
```

## Test File Organization

**Location:**
- Unit tests co-located: `Tests/FunctionalTesting/` (core library tests)
- Macro tests co-located: `Tests/InvariantSwiftMacroTests/` (macro expansion tests)
- Integration tests: `Tests/CoverageIntegrationTests/`
- Performance tests: `Tests/PerformanceTests/PropertyPerformanceTests.swift`
- Smoke tests: `Tests/SmokeTests/` (basic smoke tests per target)

**Naming:**
- Pattern: `[ComponentName]Tests.swift`
- Examples: `PropertyTests.swift`, `GeneratorCoreTests.swift`, `GhostwriterTests.swift`
- Test method naming: `@Test("Human-readable test description")`

**Structure:**
```
Tests/
├── FunctionalTesting/              # Core library tests (47 files)
│   ├── PropertyTests.swift         # Property test execution
│   ├── GeneratorCoreTests.swift    # Gen<T> combinator tests
│   ├── GhostwriterTests.swift      # Auto-test generation
│   ├── FakerTests.swift            # Faker generators
│   ├── PropertyMacroIntegrationTests.swift  # @PropertyTest macro
│   └── ...
├── InvariantSwiftMacroTests/       # Macro expansion tests (11 files)
│   ├── PropertyMacroTests.swift    # @PropertyTest expansion
│   ├── ArbitraryMacroTests.swift   # @Arbitrary expansion
│   ├── BusinessRuleMacroTests.swift
│   ├── StateMachineMacroTests.swift
│   └── ...
├── PerformanceTests/
│   └── PropertyPerformanceTests.swift
├── CoverageIntegrationTests/       # Integration tests
│   ├── AutomatedCoverageTests.swift
│   ├── CoverageValidationTests.swift
│   └── LLVMCoverageRunner.swift
└── SmokeTests/
    ├── InvariantSwiftCoreSmokeTest.swift
    ├── InvariantSwiftMacrosSmokeTest.swift
    └── ...
```

## Test Structure

**Suite Organization:**
```swift
// See: Tests/FunctionalTesting/PropertyTests.swift
import Testing
import Foundation
@testable import InvariantSwiftCore
@testable import InvariantSwift

/// Comprehensive tests for Property functions to achieve 99%+ code coverage
struct PropertyTests {

  // MARK: - Property Creation Tests

  @Test("Property basic initialization")
  func propertyBasicInitialization() async {
    let property = Property<Int>(generator: Gen<Int>.int) { $0 > -1_000_000 }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 10)
    )

    switch result {
    case .success: break
    case .failure(let counterexample, _, _, _, _):
      Issue.record("Property should pass for most ints, failed with: \(counterexample)")
    case .gaveUp:
      Issue.record("Property test gave up unexpectedly")
    }
  }

  // MARK: - PropertyResult enum tests

  @Test("PropertyResult success case")
  func propertyResultSuccessCase() async {
    let property = Property<Int>(generator: Gen<Int>.int) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 20)
    )

    switch result {
    case .success(let iterations):
      #expect(iterations == 20, "Success should report correct iteration count")
    case .failure:
      Issue.record("Property that always passes should not fail")
    case .gaveUp:
      Issue.record("Property that always passes should not give up")
    }
  }
}
```

**Patterns:**
- Test functions are async: `func testName() async { ... }`
- Use descriptive test names in `@Test("description")` attribute
- No underscore prefix on test functions
- Organize with MARK comments: `// MARK: - Section Name`
- Test multiple conditions within single test via switch/if statements

**Deterministic test data:**
- Use explicit seeds for reproducibility: `Seed(value: 12345)`
- Property tests with fixed iteration counts: `PropertyConfig(iterations: 50)`
- No time-dependent tests (avoid `Date.now()` comparisons)

## Test Structure: Assertions

**Core patterns:**
```swift
// Equality assertion
#expect(value == 42, "Value should be 42")

// Boolean assertion
#expect(condition, "Condition message")

// Optionals
#expect(optional != nil, "Should not be nil")

// Ranges
#expect(counterexample > 0 && counterexample < 100, "In range")

// Collections
#expect(shrunk <= counterexample, "Shrunk value smaller")
```

**Error assertion pattern:**
```swift
switch result {
case .success(let iterations):
  #expect(iterations == expected)
case .failure(let value, let iters, let shrunk, _, _):
  #expect(value > 0, "Invalid counterexample")
case .gaveUp:
  Issue.record("Unexpected give up")
}
```

**Test expectations:**
- Use `Issue.record(_:)` for failures that should not stop test execution
- Use `#expect()` for assertions that fail the test if false
- Use `#require()` to assert preconditions and stop test if false

## Macro Expansion Tests

**Framework:** SwiftSyntaxMacrosTestSupport

**Test pattern:**
```swift
// See: Tests/InvariantSwiftMacroTests/PropertyMacroTests.swift
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

class MacroTestCase {
  func assertMacroExpansion(
    _ testMacros: [String: Macro.Type],
    _ originalSource: String,
    _ expectedExpansion: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    #expect(testMacros["PropertyTest"] != nil)
    #expect(originalSource.contains("@PropertyTest"))
    #expect(expectedExpansion.contains("@Test"))
    #expect(expectedExpansion.contains("Property(generator:"))
  }

  func assertPropertyTestExpansion(
    _ originalSource: String,
    _ expectedExpansion: String
  ) {
    assertMacroExpansion(
      ["PropertyTest": PropertyTestMacro.self],
      originalSource,
      expectedExpansion
    )
  }
}
```

**Important:** Macro expansion tests are whitespace-sensitive. Expected output must match exactly including leading spaces and line breaks.

## Mocking

**Framework:** Manual mocking via closures (no external mocking framework)

**Patterns:**
- Mock generators with `Gen.pure(value)`: `Gen.pure(42)` always returns 42
- Mock properties with deterministic predicates: `{ value in value > 0 }`
- Mock RNG by passing fixed seeds: `Seed(value: 12345)`
- Mock test data with factory functions: see `TestHelpers.swift`

**Example mocking:**
```swift
// Mock generator that always produces same value
let mockGen = Gen.pure(expectedValue)

// Mock property that records calls
var callCount = 0
let mockProperty = Property<Int>(
  generator: mockGen
) { _ in
  callCount += 1
  return true
}

// Mock RNG with fixed seed
let seed = Seed(value: 42)
let value = gen.sample(size: .medium, seed: seed)
```

**What to Mock:**
- External generators with `Gen.pure()` for known values
- Random number generation with fixed `Seed` for determinism
- Complex types with builder functions (see `GeneratorTestHelpers.swift`)

**What NOT to Mock:**
- PropertyRunner (test the actual runner behavior)
- Shrinking strategies (need real shrinking evaluation)
- Generator combinators (test composition semantics)
- Error conditions (need to test actual failures)

## Fixtures and Factories

**Test Data:**
```swift
// See: Tests/FunctionalTesting/GeneratorTestHelpers.swift
struct TestData {
  let integers: [Int]
  let strings: [String]
  let properties: [Property<Int>]
}

func makeTestProperty(
  generator: Gen<Int> = Gen<Int>.int,
  predicate: (Int) -> Bool = { _ in true }
) -> Property<Int> {
  Property(generator: generator, predicate: predicate)
}
```

**Location:**
- Helper functions in `Tests/FunctionalTesting/TestHelpers.swift`
- Generator-specific helpers in `GeneratorTestHelpers.swift`
- Macro test helpers in `Tests/InvariantSwiftMacroTests/Utilities/`

**Patterns:**
- Factory function naming: `make[Type]` (e.g., `makeTestProperty`, `makeGenerator`)
- Default parameters for common cases: `makeTestProperty()` uses defaults
- Builder-style construction for complex objects: multiple `makeX` functions compose

## Coverage

**Requirements:** 99%+ code coverage target for library code

**View Coverage:**
```bash
swift test --enable-code-coverage

# Generate LCOV coverage report
llvm-cov export \
  -format=lcov \
  -instr-profile=.build/debug/codecov/default.profdata \
  .build/debug/InvariantSwiftPackageTests.xctest/Contents/MacOS/InvariantSwiftPackageTests \
  > coverage.lcov
```

**Coverage tracking:**
- Main library: `Sources/InvariantSwift/` (99%+ target)
- Macro implementations: `Sources/InvariantSwiftMacros/` (90%+ target)
- CLI tools: not counted (excluded from coverage)
- Test code: not counted (self-testing)

**CI integration:** Coverage reports generated in `Tests/CoverageIntegrationTests/`

## Test Types

**Unit Tests:**
- Scope: Single function or type behavior
- Location: `Tests/FunctionalTesting/[Component]Tests.swift`
- Pattern: Test one public method at a time
- Example: `PropertyTests.swift` tests `Property` type initialization, execution, result handling
- Count: ~47 test files in FunctionalTesting

**Integration Tests:**
- Scope: Multi-component workflows (e.g., generator + property runner + shrinking)
- Location: `Tests/CoverageIntegrationTests/` and `Tests/FunctionalTesting/[Feature]IntegrationTests.swift`
- Pattern: End-to-end test with real components
- Examples: `PropertyMacroIntegrationTests.swift`, `GhostwriterCLIIntegrationTests.swift`
- Verify macro → code generation → property execution pipeline

**Macro Expansion Tests:**
- Scope: Macro implementation correctness
- Location: `Tests/InvariantSwiftMacroTests/`
- Pattern: Verify macro transforms source code correctly
- Framework: SwiftSyntaxMacrosTestSupport
- Examples: `PropertyMacroTests.swift`, `ArbitraryMacroTests.swift`
- Whitespace-sensitive assertion (must match exact output)

**E2E/Acceptance Tests:**
- Scope: Full command-line workflows
- Location: `Tests/FunctionalTesting/[CLI]IntegrationTests.swift`
- Examples: `GhostwriterCLIIntegrationTests.swift`, `CLIPluginTests.swift`
- Test full process: source → macro expansion → test generation → execution

**Performance Tests:**
- Scope: Benchmarking and performance regression detection
- Location: `Tests/PerformanceTests/`
- File: `PropertyPerformanceTests.swift`
- Also: `Benchmarks/` directory for detailed performance tracking

## Common Test Patterns

**Async Testing:**
```swift
@Test("Async property test")
func testAsyncProperty() async {
  let property = Property(generator: Gen<String>.string) { input in
    await asyncValidation(input)
  }

  let result = await PropertyRunner().runProperty(
    property,
    config: PropertyConfig(iterations: 20)
  )

  switch result {
  case .success: break
  case .failure(let value, _, _, _, _):
    Issue.record("Failed with: \(value)")
  case .gaveUp:
    Issue.record("Gave up unexpectedly")
  }
}
```

**Error Testing:**
```swift
@Test("Error case handling")
func testErrorHandling() async {
  let property = Property<Int>(
    generator: Gen<Int>.int(in: 0...0)  // Only zero
  ) { value in
    value > 0  // Fails for zero
  }

  let result = await PropertyRunner().runProperty(
    property,
    config: PropertyConfig(iterations: 10)
  )

  switch result {
  case .failure(let value, _, _, _, _):
    #expect(value == 0, "Should fail on zero")
  default:
    Issue.record("Should find counterexample")
  }
}
```

**Determinism Testing:**
```swift
@Test("Same seed produces same output")
func testDeterminism() {
  let gen = Gen<String>.faker(.email)
  let seed = Seed(value: 12345)

  let value1 = gen.sample(size: .medium, seed: seed)
  let value2 = gen.sample(size: .medium, seed: seed)

  #expect(value1 == value2, "Same seed should produce same result")
}
```

**Discard Semantics:**
```swift
@Test("Discarded tests tracked properly")
func testDiscardTracking() async {
  let property = Property<Int>(
    generator: Gen<Int>.int,
    assumption: { $0 > 0 }  // Filters out negatives
  ) { value in
    value > 0
  }

  let result = await PropertyRunner().runProperty(
    property,
    config: PropertyConfig(iterations: 50)
  )

  // May give up if too many values filtered
  switch result {
  case .success: break
  case .gaveUp:
    break  // Expected if many values filtered
  case .failure:
    Issue.record("Positive numbers should be positive")
  }
}
```

**Shrinking Verification:**
```swift
@Test("Shrinking finds minimal counterexample")
func testShrinking() async {
  let property = Property<Int>(
    generator: Gen<Int>.int(in: 0...1000)
  ) { value in
    value < 100  // Fails for values >= 100
  }

  let result = await PropertyRunner().runProperty(
    property,
    config: PropertyConfig(iterations: 100, maxShrinks: 500)
  )

  switch result {
  case .failure(let original, _, let shrunk, _, _):
    // Shrunk should be minimal value >= 100
    #expect(shrunk >= 100, "Shrunk must still fail")
    #expect(shrunk <= original, "Shrunk must be simpler")
  case .success:
    Issue.record("Should fail on large values")
  case .gaveUp:
    Issue.record("Should find counterexample")
  }
}
```

## Pre-PR Verification

**All tests must pass before PR:**
```bash
# Full quality gate
swift build -Xswiftc -warnings-as-errors && \
swiftlint lint --strict && \
swift test

# Or shorthand
make validate
```

**Expected results:**
- ✅ Zero Swift compiler warnings
- ✅ Zero SwiftLint violations in strict mode
- ✅ All tests pass (no `.gaveUp` results on core tests)
- ✅ Code coverage >= 99% for library code

## Special Test Directories

**Tests/InvariantSwiftMacroTests/Resources/:**
- Purpose: Expected macro expansion output for golden tests
- Generated: No (manually maintained)
- Committed: Yes (check against actual expansion)
- Whitespace-sensitive: Must match exactly

**Tests/Generated/:**
- Purpose: Generated test files from other tools
- Generated: Yes (by Ghostwriter or other generators)
- Committed: Yes (golden baseline)
- Pattern: `[Tool]Generated[Purpose].swift`

**Tests/CoverageIntegrationTests/:**
- Purpose: Coverage-driven testing for crash isolation and verification
- Special: May use subprocess execution and LLVM coverage reporting
- Files: `LLVMCoverageRunner.swift` coordinates coverage collection

---

*Testing analysis: 2026-01-23*
