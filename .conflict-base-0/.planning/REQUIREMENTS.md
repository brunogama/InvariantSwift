# InvariantSwift v2.0 Requirements

**Project:** InvariantSwift v2.0 QuickCheck Feature Parity
**Created:** 2026-01-23
**Status:** Requirements Definition Complete

---

## Executive Summary

InvariantSwift v2.0 delivers QuickCheck feature parity with accessibility for Swift developers. The framework has strong foundations (60% feature parity) but lacks critical test observability features (`cover`, `classify`, `label`, `collect`). This requirements document defines 6 phases targeting 90%+ QuickCheck parity while maintaining 100% test coverage and Swift-native ergonomics.

**Key Requirements:**
- ✅ 100% test coverage for all new code (user requirement)
- ✅ Dogfood tests - use InvariantSwift to test itself (user requirement)
- ✅ Integration macro tests - test macro expansion in real usage (user requirement)
- ✅ QuickCheck feature parity: `cover`, `classify`, `label`, `collect`, `tabulate`, `counterexample`
- ✅ Ghostwriter fixes: auto-generate missing `@Arbitrary`, filter private types
- ✅ Swift-native terminology: no FP jargon in public API

---

## Quality Requirements (Non-Negotiable)

### QR-1: Test Coverage

**Requirement:** All new code in Phases 1-6 must have 100% test coverage.

**Verification:**
```bash
swift test --enable-code-coverage
# Extract coverage report, ensure 100% for new files
```

**Test types required:**
- Unit tests: Every public function/method
- Integration tests: Feature interactions (e.g., `cover` + `classify` together)
- Dogfood tests: Use property tests to test property testing infrastructure
- Macro tests: Test all macro expansions with SwiftSyntaxMacrosTestSupport

**Acceptance criteria:**
- [ ] 100% line coverage for new code
- [ ] 100% branch coverage for new code
- [ ] Every public API has at least 3 tests (happy path, edge cases, errors)

---

### QR-2: Dogfooding

**Requirement:** Use InvariantSwift's own property testing to test the framework.

**Examples:**
```swift
// Test generator laws with property tests
@PropertyTest
func testGeneratorIdentity(seed: Seed, size: Size) {
  let gen = Gen<Int>.int
  let value1 = gen.sample(seed: seed, size: size)
  let value2 = gen.sample(seed: seed, size: size)
  #expect(value1 == value2)  // Same seed → same value
}

// Test shrinking with property tests
@PropertyTest
func testShrinkTowardsZero(n: Int) {
  let shrunk = Shrink.towards(0, n).shrink(n)
  #expect(shrunk.allSatisfy { abs($0) < abs(n) })  // Strictly decreasing
}

// Test classification with property tests
@PropertyTest
func testCoverEnforcement(@Gen(.int(in: 0...100)) n: Int) throws {
  // This should fail if coverage requirement not met
  let property = Property(generator: Gen.int) { _ in true }
    .cover(50, when: { $0 > 0 }, label: "positive")

  try await checkProperty(property, iterations: 100)
}
```

**Acceptance criteria:**
- [ ] All generator combinators tested with property tests
- [ ] Shrinking functions tested for termination via property tests
- [ ] Classification functions tested with property tests
- [ ] At least 20% of test suite uses property-based testing

---

### QR-3: Integration Macro Tests

**Requirement:** Test macro expansions in real usage scenarios, not just unit tests.

**Test structure:**
```swift
// Integration test: @PropertyTest macro with classification
@Suite("Macro Integration Tests")
struct MacroIntegrationTests {

  @Test("@PropertyTest generates working classification")
  func testPropertyTestWithClassification() async throws {
    // This test file itself uses the macro
    @PropertyTest
    func arrayReverse(array: [Int]) {
      let reversed = array.reversed()
      #expect(reversed.reversed() == array)
    }

    // Macro should expand to:
    // - Gen<[Int]> generator creation
    // - PropertyRunner invocation
    // - Seed handling
    // - Swift Testing integration

    // Verify expansion works by running the test
    await arrayReverse()  // Should pass
  }

  @Test("@Arbitrary macro generates valid generators")
  func testArbitraryMacroExpansion() {
    struct User {
      let name: String
      let age: Int
    }

    // Apply macro
    extension User: @Arbitrary {
      static var arbitrary: Gen<User> {
        Gen.zip(Gen.string, Gen.int(in: 0...120))
          .map { User(name: $0, age: $1) }
      }
    }

    // Test generated arbitrary works
    let user = User.arbitrary.sample()
    #expect(user.age >= 0 && user.age <= 120)
  }
}
```

**Acceptance criteria:**
- [ ] All macros tested in realistic usage scenarios
- [ ] Macro expansion tests run as part of CI
- [ ] Macro error messages validated (incorrect usage should give helpful errors)
- [ ] SwiftSyntaxMacrosTestSupport used for expansion verification

---

## Functional Requirements by Phase

### Phase 1: Test Observability (P0 - MVP Blocker)

**Epic:** As a developer, I need to verify my property tests are exercising the right code paths so that I can trust my test suite.

#### FR-1.1: Coverage Enforcement (`cover`)

**User Story:** As a developer, I want to enforce minimum coverage thresholds so that I know my tests aren't biased.

**API:**
```swift
extension Property {
  /// Enforce minimum percentage of test cases match condition
  public func cover(
    _ percentage: Double,
    when predicate: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> Property<T>
}
```

**Behavior:**
- Tracks how many test cases satisfy `predicate`
- Fails test if percentage < target after all iterations
- Labels passing test cases for statistics
- Reports actual vs expected coverage in failure message

**Example:**
```swift
@PropertyTest
func testSortedArray(array: [Int]) {
  #expect(array.sorted().count == array.count)
}
.cover(30, when: { $0.isEmpty }, label: "empty arrays")
.cover(50, when: { $0.count > 5 }, label: "large arrays")
// Fails if < 30% empty arrays or < 50% large arrays
```

**Tests required:**
- [ ] Unit test: Coverage enforcement calculation
- [ ] Unit test: Failure message formatting
- [ ] Integration test: Multiple cover requirements
- [ ] Dogfood test: Use property test to verify cover enforcement
- [ ] Macro test: @PropertyTest with .cover() compiles and runs

**Acceptance criteria:**
- [ ] Enforces coverage percentage with configurable threshold
- [ ] Clear failure message shows actual vs expected coverage
- [ ] Works with multiple cover requirements
- [ ] Zero performance overhead if no cover requirements

---

#### FR-1.2: Test Classification (`classify`)

**User Story:** As a developer, I want to see the distribution of my test cases so that I can identify bias in my generators.

**API:**
```swift
extension Property {
  /// Label test cases based on condition
  public func classify(
    when predicate: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> Property<T>
}
```

**Behavior:**
- Labels test cases that satisfy `predicate`
- Accumulates statistics across all iterations
- Reports distribution in test output (e.g., "40% positive integers")
- No enforcement - purely informational

**Example:**
```swift
@PropertyTest
func testIntegerProperties(n: Int) {
  #expect(abs(n) >= 0)
}
.classify(when: { $0 > 0 }, label: "positive")
.classify(when: { $0 < 0 }, label: "negative")
.classify(when: { $0 == 0 }, label: "zero")
// Output:
// 45% positive
// 45% negative
// 10% zero
```

**Tests required:**
- [ ] Unit test: Classification accumulation
- [ ] Unit test: Statistics calculation
- [ ] Integration test: Multiple classify conditions
- [ ] Dogfood test: Property test for classification correctness
- [ ] Performance test: Overhead < 5%

**Acceptance criteria:**
- [ ] Accurate statistics reported after test run
- [ ] Works with multiple classification labels
- [ ] Thread-safe accumulation (actor-based)
- [ ] Pretty-printed output matches QuickCheck format

---

#### FR-1.3: Test Labeling (`label`)

**User Story:** As a developer, I want to unconditionally label my test cases so that I can track what inputs were tested.

**API:**
```swift
extension Property {
  /// Unconditionally attach a label to every test case
  public func label(_ text: String) -> Property<T>

  /// Dynamic labeling based on input value
  public func label(_ text: @escaping @Sendable (T) -> String) -> Property<T>
}
```

**Behavior:**
- Attaches label to every test case (no condition)
- Multiple .label() calls accumulate
- Labels displayed in failure reports
- Labels tracked in statistics

**Example:**
```swift
@PropertyTest
func testWithLabels(n: Int) {
  #expect(n * 2 > n)
}
.label("multiplication test")
.label { n in "input: \(n)" }
// Failure shows both labels
```

**Tests required:**
- [ ] Unit test: Label accumulation
- [ ] Unit test: Dynamic labeling
- [ ] Integration test: Multiple labels
- [ ] Dogfood test: Property test for label tracking

**Acceptance criteria:**
- [ ] Static and dynamic labeling both work
- [ ] Labels appear in failure reports
- [ ] Multiple labels accumulate correctly
- [ ] Zero performance overhead for failures

---

### Phase 2: Enhanced Reporting (P1 - QuickCheck Parity)

#### FR-2.1: Value Collection (`collect`)

**User Story:** As a developer, I want to see the distribution of collected values so that I can verify my generators produce diverse inputs.

**API:**
```swift
extension Property {
  /// Collect values and report histogram
  public func collect<U: Hashable & CustomStringConvertible>(
    _ extract: @escaping @Sendable (T) -> U
  ) -> Property<T>
}
```

**Behavior:**
- Extracts value from each input via `extract`
- Tracks frequency of each unique value
- Reports histogram in test output
- Groups values into buckets for readability

**Example:**
```swift
@PropertyTest
func testArraySort(array: [Int]) {
  #expect(array.sorted().count == array.count)
}
.collect { $0.count }
// Output:
// 15% length 0
// 30% length 1-5
// 40% length 6-10
// 15% length 11+
```

**Tests required:**
- [ ] Unit test: Value extraction and histogram
- [ ] Unit test: Bucketing algorithm
- [ ] Integration test: collect + classify together
- [ ] Dogfood test: Property test for histogram accuracy

**Acceptance criteria:**
- [ ] Histogram accurately reflects value distribution
- [ ] Automatic bucketing for numeric values
- [ ] Works with custom types (Hashable + CustomStringConvertible)
- [ ] Pretty-printed tables in test output

---

#### FR-2.2: Multi-Dimensional Tabulation (`tabulate`)

**User Story:** As a developer, I want to track multiple dimensions simultaneously so that I can see correlations in my test data.

**API:**
```swift
extension Property {
  /// Multi-dimensional classification
  public func tabulate(
    _ category: String,
    labels: @escaping @Sendable (T) -> [String]
  ) -> Property<T>
}
```

**Behavior:**
- Tracks distributions for named categories
- Multiple categories tracked independently
- Reports separate tables per category
- Labels can overlap within a category

**Example:**
```swift
@PropertyTest
func testInteger(n: Int) {
  #expect(abs(n) >= 0)
}
.tabulate("magnitude") { n in
  [abs(n) < 10 ? "small" : "large"]
}
.tabulate("sign") { n in
  [n > 0 ? "positive" : n < 0 ? "negative" : "zero"]
}
// Output:
// Category: magnitude
//   small: 60%
//   large: 40%
// Category: sign
//   positive: 45%
//   negative: 45%
//   zero: 10%
```

**Tests required:**
- [ ] Unit test: Category separation
- [ ] Unit test: Table formatting
- [ ] Integration test: Multiple categories
- [ ] Dogfood test: Property test for tabulation

**Acceptance criteria:**
- [ ] Categories tracked independently
- [ ] Pretty-printed tables per category
- [ ] Overlapping labels within category allowed
- [ ] Integrates with existing classification

---

#### FR-2.3: Custom Counterexample Messages (`counterexample`)

**User Story:** As a developer, I want to add explanatory text to failures so that I understand why a test failed.

**API:**
```swift
extension Property {
  /// Add custom message to failure reports
  public func counterexample(
    _ message: @escaping @Sendable (T) -> String
  ) -> Property<T>
}
```

**Behavior:**
- Message computed for failing input
- Displayed alongside shrunk counterexample
- Multiple counterexample calls accumulate
- Not evaluated for passing tests (performance)

**Example:**
```swift
@PropertyTest
func testPositive(n: Int) {
  #expect(n > 0)
}
.counterexample { n in "Expected positive, got: \(n)" }
// Failure output:
// *** Failed! Falsified after 1 test.
// Expected positive, got: 0
// Shrunk: 0
```

**Tests required:**
- [ ] Unit test: Message computation
- [ ] Unit test: Multiple counterexample messages
- [ ] Integration test: counterexample + cover
- [ ] Dogfood test: Property test for message rendering

**Acceptance criteria:**
- [ ] Messages only computed for failures (lazy evaluation)
- [ ] Multiple messages accumulate
- [ ] Clear formatting in failure reports
- [ ] Zero overhead for passing tests

---

### Phase 3: Discard & Syntax Sugar (P1 - DX Improvements)

#### FR-3.1: Conditional Property Operator (`==>`)

**User Story:** As a developer, I want QuickCheck-style implication syntax so that preconditions are readable.

**API:**
```swift
infix operator ==> : ComparisonPrecedence

extension Bool {
  public static func ==> (
    precondition: Bool,
    consequent: @autoclosure () -> Bool
  ) -> PropertyEvaluation
}
```

**Behavior:**
- If precondition false, discard test case
- If precondition true, evaluate consequent
- Returns `.discard` or `.pass`/`.fail`
- Syntactic sugar over existing `.filter()`

**Example:**
```swift
@PropertyTest
func testNonEmptyArray(array: [Int]) {
  (!array.isEmpty ==> (array.first != nil))
    .evaluate()
}
// Discards empty arrays, tests non-empty ones
```

**Tests required:**
- [ ] Unit test: Operator precedence
- [ ] Unit test: Short-circuit evaluation
- [ ] Integration test: ==> with cover
- [ ] Macro test: @PropertyTest with ==> compiles

**Acceptance criteria:**
- [ ] Reads like QuickCheck Haskell syntax
- [ ] Short-circuits consequent evaluation if precondition false
- [ ] Works with existing discard infrastructure
- [ ] Clear documentation with examples

---

#### FR-3.2: Discard Ratio Tracking

**User Story:** As a developer, I want to be warned about excessive discards so that I can fix my generators.

**API:**
```swift
public struct PropertyConfig {
  /// Maximum discard ratio before warning (default: 5.0)
  public var warnDiscardRatio: Double = 5.0

  /// Maximum discard ratio before failure (default: 10.0)
  public var maxDiscardRatio: Double = 10.0
}

public struct PropertyResult {
  /// Number of discarded test cases
  public let discards: Int

  /// Discard ratio (discards / iterations)
  public var discardRatio: Double

  /// Reasons for discards with frequencies
  public let discardReasons: [String: Int]
}
```

**Behavior:**
- Track discards per reason
- Warn if ratio exceeds threshold
- Fail if ratio exceeds max
- Suggest generator improvements in warning

**Example output:**
```
⚠️ High discard ratio: 7.5x (750 discards / 100 iterations)
Reasons:
  - "non-empty array": 600 (80%)
  - "positive integer": 150 (20%)

Suggestion: Redesign generator to produce valid inputs directly.
Instead of:  Gen.array(Gen.int).filter { !$0.isEmpty }
Try:         Gen.array(Gen.int, count: 1...)
```

**Tests required:**
- [ ] Unit test: Discard ratio calculation
- [ ] Unit test: Warning thresholds
- [ ] Integration test: Discard with ==>
- [ ] Dogfood test: Property test for discard tracking

**Acceptance criteria:**
- [ ] Accurate discard ratio tracking
- [ ] Clear warnings with actionable suggestions
- [ ] Configurable thresholds via PropertyConfig
- [ ] Discard reasons reported with frequencies

---

### Phase 4: Ghostwriter Fixes (P1 - Production-Ready)

#### FR-4.1: Access Level Filtering

**User Story:** As a developer, I want Ghostwriter to only generate tests for public APIs so that generated tests compile.

**Requirement:**
- Extract access level from SwiftSyntax AST
- Filter types: only `public` and `open`
- Skip: `private`, `fileprivate`, `internal`
- Add `--include-internal` flag for comprehensive testing

**API:**
```swift
struct TypeInfo {
  let name: String
  let accessLevel: AccessLevel  // NEW
  let members: [MemberInfo]
  // ...
}

enum AccessLevel {
  case `private`
  case `fileprivate`
  case `internal`
  case `public`
  case `open`
}
```

**Tests required:**
- [ ] Unit test: Access level extraction
- [ ] Integration test: Skip private types
- [ ] Macro test: --include-internal flag

**Acceptance criteria:**
- [ ] Generated tests only reference public types
- [ ] Private types skipped with verbose logging
- [ ] Flag to include internal for app testing

---

#### FR-4.2: Auto-Generate Missing @Arbitrary

**User Story:** As a developer, I want Ghostwriter to generate missing generators so that tests compile without manual fixes.

**Requirement:**
- Detect when type lacks generator
- Generate `@Arbitrary` extension automatically
- Handle nested types and generics
- Emit warning if generation not possible

**API:**
```swift
struct GhostwriterConfig {
  /// Auto-generate missing @Arbitrary conformances
  public var generateArbitrary: Bool = true

  /// Maximum nesting depth for generated types
  public var maxArbitraryDepth: Int = 3
}
```

**Generated code example:**
```swift
// Input: struct User { let name: String; let age: Int }

// Generated:
extension User: Arbitrary {
  public static var arbitrary: Gen<User> {
    Gen.zip(Gen.string, Gen.int(in: 0...120))
      .map { User(name: $0, age: $1) }
  }
}
```

**Tests required:**
- [ ] Unit test: Simple struct generation
- [ ] Unit test: Nested type generation
- [ ] Unit test: Generic type generation
- [ ] Integration test: Generated tests compile
- [ ] Dogfood test: Property test for generator validity

**Acceptance criteria:**
- [ ] Generates valid `@Arbitrary` conformances
- [ ] Handles structs with 1-10 members
- [ ] Warns for unsupported types (classes, protocols)
- [ ] Generated code compiles without errors

---

#### FR-4.3: Compile-Test Infrastructure

**User Story:** As a developer, I want Ghostwriter to verify generated tests compile so that I get working tests.

**Requirement:**
- Write generated code to temporary file
- Invoke Swift compiler with test target context
- Report compilation errors with line numbers
- Only write to disk if compilation succeeds

**Implementation:**
```swift
func compileTest(_ code: String, in target: String) throws -> CompilationResult {
  let tempFile = "/tmp/ghostwriter_\(UUID()).swift"
  try code.write(toFile: tempFile, atomically: true, encoding: .utf8)

  let result = shell("swift", "build", "--target", target, tempFile)
  if result.exitCode != 0 {
    throw GhostwriterError.compilationFailed(result.stderr)
  }

  return .success
}
```

**Tests required:**
- [ ] Unit test: Compilation success
- [ ] Unit test: Compilation failure handling
- [ ] Integration test: Full Ghostwriter pipeline
- [ ] CI test: Ghostwriter on sample projects

**Acceptance criteria:**
- [ ] All generated tests compile before writing
- [ ] Clear error messages for compilation failures
- [ ] Flag to skip compile-test for speed
- [ ] CI/CD integration verified

---

### Phase 5: Error Messages & Progress (P2 - Polish)

#### FR-5.1: Enhanced Failure Messages

**User Story:** As a developer, I want actionable failure messages so that I can debug property test failures quickly.

**Requirement:**
- Show property description
- Show minimal counterexample
- Show reproduction command with seed
- Show shrinking metrics

**Example output:**
```
❌ Property test failed

Test: testArrayReverse (PropertyTests.swift:42)
Property: array.reversed().reversed() == array

Counterexample (minimal after 15 shrinks):
  array = [Int.min, 0]

Reproduce with:
  swift test --filter testArrayReverse
  OR
  @PropertyTest(seed: 12345, iterations: 1)
  func testArrayReverse() { /* ... */ }

Original failure:
  array = [Int.min, -5, 0, 3, 7, -2, 8]

Shrinking path: 7 elements → 2 elements (71% reduction)
Time: 0.3s (15 shrink attempts)
```

**Tests required:**
- [ ] Unit test: Message formatting
- [ ] Integration test: Reproduction command works
- [ ] Dogfood test: Property test for message correctness

**Acceptance criteria:**
- [ ] All failure info in single, clear message
- [ ] Reproduction command copy-pasteable
- [ ] Shrinking metrics informative
- [ ] Works with Swift Testing output

---

#### FR-5.2: Progress Indicators

**User Story:** As a developer, I want progress updates for long-running tests so that I know tests aren't hung.

**Requirement:**
- Show progress every 1000 iterations or 5 seconds
- Display iteration count, elapsed time, current rate
- Suppress for fast tests (< 5 seconds)
- Configurable via PropertyConfig

**Example output:**
```
Running testComplexProperty: 1000/10000 tests (5.2s, 192 tests/sec)
Running testComplexProperty: 2000/10000 tests (10.5s, 190 tests/sec)
...
✓ testComplexProperty: 10000 tests in 52.3s (191 tests/sec)
```

**Tests required:**
- [ ] Unit test: Progress calculation
- [ ] Integration test: Progress output
- [ ] CI test: Verify no progress for fast tests

**Acceptance criteria:**
- [ ] Progress shown for tests > 5 seconds
- [ ] Silent for fast tests
- [ ] Works in CI/CD (no TTY required)
- [ ] Configurable thresholds

---

#### FR-5.3: Seed Logging

**User Story:** As a developer, I want seeds logged for all tests so that I can reproduce any test run.

**Requirement:**
- Log seed at test start (verbose mode)
- Log seed in failure reports (always)
- Support `INVARIANT_SEED` environment variable
- Document seed usage in every failure

**Example:**
```
# Verbose mode
Running testArraySort with seed: 42

# Failure
❌ Test failed with seed: 12345
Reproduce: swift test --filter testArraySort
           OR set INVARIANT_SEED=12345
```

**Tests required:**
- [ ] Unit test: Seed extraction and logging
- [ ] Integration test: INVARIANT_SEED env var
- [ ] CI test: Seed logging in CI output

**Acceptance criteria:**
- [ ] Seeds logged in all failure reports
- [ ] Environment variable override works
- [ ] Documentation explains seed usage
- [ ] Deterministic replay verified

---

### Phase 6: Documentation & Examples (P2 - Accessibility)

#### FR-6.1: XCTest Migration Guide

**User Story:** As an XCTest user, I want a migration guide so that I can convert my tests to property-based testing.

**Content:**
- 20 before/after examples
- Common XCTest patterns → property test equivalents
- When to use property tests vs example tests
- Performance comparison

**Examples:**
```swift
// Before: Example-based test
func testArraySort() {
  XCTAssertEqual([3,1,2].sorted(), [1,2,3])
  XCTAssertEqual([].sorted(), [])
  XCTAssertEqual([1].sorted(), [1])
}

// After: Property-based test
@PropertyTest
func testArraySort(array: [Int]) {
  let sorted = array.sorted()
  #expect(sorted == sorted.sorted())  // Idempotent
  #expect(sorted.count == array.count)  // Preserves length
  #expect(sorted.zipAdjacent().allSatisfy { $0 <= $1 })  // Ordered
}
```

**Tests required:**
- [ ] All migration examples compile
- [ ] All migration examples pass
- [ ] Performance benchmarks included

**Acceptance criteria:**
- [ ] 20 migration examples
- [ ] Covers common testing patterns
- [ ] Side-by-side comparisons
- [ ] Clear when to use each approach

---

#### FR-6.2: Terminology Glossary

**User Story:** As a non-FP developer, I want clear definitions so that I understand property testing concepts.

**Content:**
- Generator: Creates random test values (like factory)
- Property: Invariant that should always hold (like assertion)
- Shrinking: Finding minimal failing example (automatic)
- Counterexample: Failing test case (like XCTFail input)
- Classification: Tracking what inputs were tested (coverage)
- Seed: Deterministic randomness (for reproducibility)

**Tests required:**
- [ ] All terms defined with examples
- [ ] No FP jargon without explanation

**Acceptance criteria:**
- [ ] All terms from public API explained
- [ ] Examples for each concept
- [ ] Comparison to familiar testing concepts
- [ ] No assumption of FP knowledge

---

#### FR-6.3: Expanded Cookbook

**User Story:** As a developer, I want copy-paste recipes so that I can solve common testing problems.

**Content:**
- Testing sorting algorithms
- Testing JSON encode/decode
- Testing database operations
- Testing state machines
- Testing async code
- Testing error handling
- Testing collections
- Testing numeric properties
- Testing string manipulation
- Testing custom types

**Example:**
```swift
// Recipe: Testing JSON encode/decode roundtrip
@PropertyTest
func testJSONRoundtrip(user: User) throws {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  let data = try encoder.encode(user)
  let decoded = try decoder.decode(User.self, from: data)

  #expect(decoded == user)
}
.cover(20, when: { $0.name.isEmpty }, label: "empty names")
.cover(30, when: { $0.age > 65 }, label: "senior users")
```

**Tests required:**
- [ ] All cookbook examples compile
- [ ] All cookbook examples pass
- [ ] Examples cover common use cases

**Acceptance criteria:**
- [ ] 10+ cookbook recipes
- [ ] Each recipe with explanation
- [ ] Copy-paste ready
- [ ] Real-world use cases

---

## Non-Functional Requirements

### NFR-1: Performance

**Requirement:** Classification overhead must be < 10% vs baseline property tests.

**Measurement:**
```swift
// Benchmark: Property test without classification
Benchmark("Property baseline") { benchmark in
  for _ in benchmark.scaledIterations {
    checkProperty(Property(generator: Gen<Int>.int) { $0 >= 0 })
  }
}

// Benchmark: Property test with classification
Benchmark("Property with classification") { benchmark in
  for _ in benchmark.scaledIterations {
    checkProperty(
      Property(generator: Gen<Int>.int) { $0 >= 0 }
        .classify(when: { $0 > 0 }, label: "positive")
        .cover(40, when: { $0 > 0 }, label: "positive")
    )
  }
}
```

**Acceptance criteria:**
- [ ] < 10% overhead for classification
- [ ] < 5% overhead for simple cover requirements
- [ ] Benchmarks run in CI
- [ ] Performance regressions fail CI

---

### NFR-2: Memory

**Requirement:** Classification storage must be bounded to prevent memory exhaustion.

**Constraints:**
- Maximum 1000 unique classification labels
- Warn if label count exceeds 500
- Fail if label count exceeds 1000

**Tests required:**
- [ ] Unit test: Label count limit enforcement
- [ ] Integration test: Large classification sets
- [ ] Stress test: 10,000 iterations with many labels

**Acceptance criteria:**
- [ ] Bounded memory usage
- [ ] Clear warnings for excessive labels
- [ ] No memory leaks in long-running tests

---

### NFR-3: Concurrency

**Requirement:** All classification infrastructure must be thread-safe (Swift 6 strict concurrency).

**Constraints:**
- All mutable state in actors
- No data races (verified by compiler)
- Works with parallel property test execution

**Tests required:**
- [ ] Unit test: Concurrent classification updates
- [ ] Integration test: Parallel property tests
- [ ] Stress test: 1000 concurrent property tests

**Acceptance criteria:**
- [ ] Zero data race warnings
- [ ] Compiles with -strict-concurrency=complete
- [ ] Sendable conformance on all public types

---

## Success Metrics

**v2.0 Release Criteria:**

1. ✅ **Feature Completeness:** 90%+ QuickCheck parity
   - P0 features: 100% implemented (`cover`, `classify`, `label`)
   - P1 features: 100% implemented (`collect`, `tabulate`, `counterexample`, `==>`)
   - P2 features: 80%+ implemented (error messages, progress)

2. ✅ **Quality:**
   - 100% test coverage for new code
   - 20%+ dogfood tests (property tests testing property testing)
   - Zero warnings with -warnings-as-errors
   - Zero force unwraps in new code

3. ✅ **Performance:**
   - < 10% overhead for classification
   - < 5% overhead for cover requirements
   - No memory leaks

4. ✅ **Accessibility:**
   - XCTest migration guide with 20 examples
   - Glossary with zero FP jargon
   - 10+ cookbook recipes
   - User testing with non-FP developers

5. ✅ **Reliability:**
   - All 16 disabled tests re-enabled or removed
   - Ghostwriter generates compilable tests
   - CI/CD passing on all platforms

---

## Out of Scope for v2.0

**Explicitly deferred to v2.1+:**

1. Advanced modifiers (Positive, NonEmpty wrappers) - low value in Swift
2. CoArbitrary (function generators) - breaks accessibility
3. Advanced targeted testing - platform limitations
4. SMT solver integration - research phase needed
5. LibFuzzer integration - niche use case
6. Lens/Prism optics - too FP-heavy

**Rationale:** Focus on 90% QuickCheck parity with high accessibility. Advanced features can be added incrementally post-v2.0 based on user feedback.

---

## Dependencies

**Phase dependencies:**
```
Phase 1 (Observability) → Phase 2 (Reporting) → Phase 5 (Errors) → Phase 6 (Docs)
                       ↘ Phase 3 (Discard)  ↗
Phase 4 (Ghostwriter) — independent
```

**External dependencies:**
- SwiftSyntax 602.0.0 (existing) - macro infrastructure
- swift-custom-dump 1.3.3+ (existing) - pretty-printing
- swift-benchmark 0.1.2+ (existing) - performance testing
- Swift 6.0+ - language and concurrency
- Swift Testing - test framework integration

---

**Requirements complete. Ready for Phase 8: Create Roadmap.**
