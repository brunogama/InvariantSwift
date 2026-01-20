# Technology Stack - InvariantSwift QuickCheck Feature Parity

**Project:** InvariantSwift v2.0
**Domain:** Property-based testing framework for Swift
**Researched:** 2026-01-23
**Confidence:** HIGH

---

## Executive Summary

QuickCheck (Haskell) provides 15+ core features for property-based testing. InvariantSwift has ~60% coverage (generators, basic shrinking, property testing). Missing critical features: test case classification (`classify`, `cover`, `collect`, `label`, `tabulate`), conditional properties (`discard`, explicit assumptions), counterexample reporting, test modifiers (`NonEmpty`, `Positive`, etc.), and advanced shrinking strategies.

**Recommendation:** Implement features in priority order:
1. **P0 (MVP blockers)**: `cover`, `classify`, `label` - test distribution analysis
2. **P1 (QuickCheck parity)**: `collect`, `tabulate`, counterexample strings - observability
3. **P2 (DX improvements)**: Test modifiers, improved shrinking, stateful testing

---

## QuickCheck Feature Inventory

### ✅ Already Implemented

| Feature | QuickCheck API | InvariantSwift Status | Location |
|---------|----------------|----------------------|----------|
| Random generation | `Gen a` | ✅ `Gen<T>` | `Core/Generator.swift` |
| Basic shrinking | `Shrink a` | ✅ `Shrink<T>`, `ShrinkTree<T>` | `Core/Generator.swift` |
| Property testing | `quickCheck :: Testable prop => prop -> IO ()` | ✅ `checkProperty()` | `Testing/` |
| Explicit quantification | `forAll :: Gen a -> (a -> Bool) -> Property` | ✅ `Property(generator:predicate:)` | `Core/Property.swift` |
| Basic test configuration | `Args` record (maxSuccess, maxSize) | ✅ `PropertyConfig` | `Testing/TargetedConfig.swift` |
| Resize generators | `resize :: Int -> Gen a -> Gen a` | ✅ `Size` parameter | `Core/Generator.swift` |
| Pure generators | `return :: a -> Gen a` | ✅ `Gen.pure(T)` | `Core/Generator.swift` |
| Generator combinators | `fmap`, `<*>`, `>>=` | ✅ `map`, `flatMap`, `zip` | `Core/Generator.swift` |
| Discard semantics | `discard :: Property` | ✅ `PropertyEvaluation.discard` | `Core/Property.swift` |

**Confidence:** HIGH - Verified via codebase inspection

---

### ❌ Missing - Critical (P0)

Features required for QuickCheck feature parity and test observability.

#### 1. Coverage Guarantees (`cover`)

**QuickCheck API:**
```haskell
cover :: Testable prop
      => Double           -- Minimum required percentage
      -> Bool             -- Condition to check
      -> String           -- Label for this class
      -> prop
      -> Property
```

**Purpose:** Ensure at least X% of successful tests belong to a labeled class. Fails test if coverage threshold not met.

**Swift Implementation:**

```swift
// Core type
public struct CoverageRequirement: Sendable {
  let minimumPercentage: Double  // 0.0 to 100.0
  let condition: @Sendable (Any) -> Bool
  let label: String
}

// Property extension
extension Property {
  public func cover(
    _ percentage: Double,
    when condition: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> Property<T> {
    // Track coverage in PropertyResult
    // Fail if percentage not met after all iterations
  }
}

// Usage
Property(generator: Gen<Int>.int) { n in
  n.isMultiple(of: 2)
}
.cover(50, when: { $0 > 0 }, label: "positive numbers")
.cover(30, when: { $0 < 0 }, label: "negative numbers")
```

**Technical Requirements:**
- Thread-safe coverage tracking (use `actor` or `OSAllocatedUnfairLock`)
- Accumulate statistics across all test iterations
- Report coverage failures distinctly from predicate failures
- Integrate with Swift Testing's `@Test` reporting

**Dependencies:** None (pure Swift 6)

**Confidence:** HIGH - Standard feature in QuickCheck 2.8+

---

#### 2. Test Case Classification (`classify`)

**QuickCheck API:**
```haskell
classify :: Testable prop
         => Bool      -- Condition
         -> String    -- Classification label
         -> prop
         -> Property
```

**Purpose:** Conditionally label test cases. Reports distribution of labels after testing.

**Swift Implementation:**

```swift
// Classification tracking
public struct TestClassification: Sendable, Hashable {
  let label: String
  let count: Int
  let percentage: Double
}

public struct ClassificationReport: Sendable {
  let totalTests: Int
  let classifications: [TestClassification]

  public func prettyPrint() -> String {
    // QuickCheck-style output:
    // 45% positive
    // 30% negative
    // 25% zero
  }
}

// Property extension
extension Property {
  public func classify(
    _ condition: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> Property<T> {
    // Add classification tracking to property
  }
}

// Usage
Property(generator: Gen<Int>.int) { n in
  n + 0 == n
}
.classify({ $0 > 0 }, label: "positive")
.classify({ $0 < 0 }, label: "negative")
.classify({ $0 == 0 }, label: "zero")
```

**Technical Requirements:**
- Accumulate classifications across iterations
- Thread-safe counter updates (`OSAllocatedUnfairLock<[String: Int]>`)
- Pretty-print distribution after test run
- Integrate with existing `TestStatistics` type

**Dependencies:** None (pure Swift 6)

**Confidence:** HIGH - Core QuickCheck feature since 1.0

---

#### 3. Test Labeling (`label`)

**QuickCheck API:**
```haskell
label :: Testable prop => String -> prop -> Property
```

**Purpose:** Unconditionally attach a label to every test case. Multiple labels accumulate.

**Swift Implementation:**

```swift
extension Property {
  public func label(_ text: String) -> Property<T> {
    // Attach label to all generated test cases
    // Multiple .label() calls accumulate labels
  }

  public func label(_ text: @escaping @Sendable (T) -> String) -> Property<T> {
    // Dynamic labeling based on input value
  }
}

// Usage
Property(generator: Gen<Int>.int) { n in
  n * 2 > n
}
.label("doubling increases value")
.label { n in "input: \(n)" }
```

**Technical Requirements:**
- Store labels in `PropertyResult`
- Display labels in failure reports
- Combine with `classify` for rich reporting

**Dependencies:** None (pure Swift 6)

**Confidence:** HIGH - Standard QuickCheck feature

---

### ❌ Missing - High Priority (P1)

Features that significantly improve debugging and observability.

#### 4. Value Collection (`collect`)

**QuickCheck API:**
```haskell
collect :: (Show a, Testable prop) => a -> prop -> Property
```

**Purpose:** Label each test case with a dynamically computed value. Reports distribution of collected values.

**Swift Implementation:**

```swift
extension Property {
  public func collect<U: Hashable & CustomStringConvertible>(
    _ extract: @escaping @Sendable (T) -> U
  ) -> Property<T> {
    // Extract value from each input
    // Track distribution of extracted values
    // Report after testing
  }
}

// Usage
Property(generator: Gen<[Int]>.array(Gen<Int>.int)) { arr in
  arr.sorted().count == arr.count
}
.collect { arr in arr.count } // Collect array lengths
// Output:
// 20% length 0
// 35% length 1-5
// 45% length 6-10
```

**Technical Requirements:**
- Generic over collected value type
- Thread-safe distribution tracking
- Group values into buckets for readability
- Pretty-print distribution

**Dependencies:** None (pure Swift 6)

**Confidence:** HIGH - QuickCheck 1.0 feature

---

#### 5. Tabulation (`tabulate`)

**QuickCheck API:**
```haskell
tabulate :: Testable prop => String -> [String] -> prop -> Property
```

**Purpose:** Multi-dimensional classification. Track distribution of multiple labels simultaneously.

**Swift Implementation:**

```swift
extension Property {
  public func tabulate(
    _ category: String,
    labels: @escaping @Sendable (T) -> [String]
  ) -> Property<T> {
    // Track multi-dimensional distributions
    // Report tables like:
    // Category: size
    //   small: 40%
    //   large: 60%
    // Category: sign
    //   positive: 55%
    //   negative: 45%
  }
}

// Usage
Property(generator: Gen<Int>.int) { n in
  abs(n) >= 0
}
.tabulate("size") { n in
  [abs(n) < 10 ? "small" : "large"]
}
.tabulate("sign") { n in
  [n > 0 ? "positive" : n < 0 ? "negative" : "zero"]
}
```

**Technical Requirements:**
- Multi-dimensional distribution tracking
- Category-based organization
- Table formatting for output
- Integration with Swift Testing output

**Dependencies:** None (pure Swift 6)

**Confidence:** HIGH - QuickCheck 2.7+ feature

---

#### 6. Counterexample Strings (`counterexample`)

**QuickCheck API:**
```haskell
counterexample :: Testable prop => String -> prop -> Property
```

**Purpose:** Add custom explanatory text to failure reports.

**Swift Implementation:**

```swift
extension Property {
  public func counterexample(
    _ message: @escaping @Sendable (T) -> String
  ) -> Property<T> {
    // Attach message to failure reports
    // Show alongside shrunk value
  }
}

// Usage
Property(generator: Gen<Int>.int) { n in
  n > 0
}
.counterexample { n in "Expected positive, got: \(n)" }
// Failure output:
// *** Failed! Falsified after 1 test.
// Expected positive, got: 0
// Shrunk: 0
```

**Technical Requirements:**
- Store counterexample strings in `PropertyResult`
- Display in failure reports
- Combine multiple counterexample calls

**Dependencies:** None (pure Swift 6)

**Confidence:** HIGH - QuickCheck 2.4+ feature

---

### ❌ Missing - Medium Priority (P2)

Features that improve ergonomics and advanced use cases.

#### 7. Test Modifiers

**QuickCheck API:**
```haskell
-- Type wrappers that constrain generation
newtype Positive a = Positive { getPositive :: a }
newtype NonZero a = NonZero { getNonZero :: a }
newtype NonEmpty a = NonEmpty { getNonEmpty :: [a] }
newtype Blind a = Blind { getBlind :: a }  -- No Show required
```

**Purpose:** Type-level constraints on generated values. Alternative to `filter()` that doesn't discard.

**Swift Implementation:**

```swift
// Wrapper types with constrained generators
public struct Positive<T: Numeric & Comparable>: Sendable {
  public let value: T

  public static var generator: Gen<Positive<T>> {
    Gen { rng, size in
      // Generate only positive values
      Positive(value: /* positive generation */)
    }
  }
}

public struct NonEmpty<T: Sendable>: Sendable {
  public let value: [T]

  public static func generator<T>(of elementGen: Gen<T>) -> Gen<NonEmpty<T>> {
    Gen { rng, size in
      var arr = elementGen.array(count: 1...max(1, size.value)).generate(&rng, size)
      return NonEmpty(value: arr.isEmpty ? [elementGen.generate(&rng, size)] : arr)
    }
  }
}

// Usage
Property(generator: Positive<Int>.generator) { pos in
  pos.value > 0  // Always passes
}

Property(generator: NonEmpty.generator(of: Gen<Int>.int)) { nonEmpty in
  !nonEmpty.value.isEmpty  // Always passes
}
```

**Available Modifiers:**
- `Positive<T>` - values > 0
- `NonNegative<T>` - values >= 0
- `NonZero<T>` - values != 0
- `NonEmpty<T>` - non-empty collections
- `Blind<T>` - no `CustomStringConvertible` requirement
- `Small<T>` - small magnitude values (for performance)
- `Large<T>` - large magnitude values (stress testing)
- `Ordered<T>` - sorted collections
- `Fixed<T>` - constant size collections

**Technical Requirements:**
- Generic wrapper types with `Sendable` conformance
- Specialized generators per modifier
- Efficient generation (no rejection sampling)
- Pattern matching support: `case let .positive(value)`

**Dependencies:** None (pure Swift 6)

**Confidence:** HIGH - QuickCheck 2.0+ feature

**Source:** [Test.QuickCheck.Modifiers - Hackage](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck-Modifiers.html)

---

#### 8. Improved Shrinking - Integrated Shrinking

**Current Status:** InvariantSwift uses type-based shrinking (`Shrink<T>` + `ShrinkTree<T>`)

**QuickCheck Evolution:** Modern property testing frameworks (Hypothesis, Hedgehog) use **integrated shrinking** where shrinking is built into generation, not type-based.

**Hypothesis Approach (Python):**
```python
# Integrated: Generator produces value + shrink tree in one go
@given(st.integers())
def test_property(n):
    # Shrinking happens automatically from generation context
```

**Benefits:**
- Shrinking always works (no missing `Shrink` instances)
- Better composition (shrinking composes with generation)
- More efficient (no separate shrink phase)

**Swift Implementation Strategy:**

```swift
// Option 1: Enhance existing Gen<T> to track provenance
public struct Gen<T>: @unchecked Sendable {
  // Current
  public let generate: (inout any RandomNumberGenerator, Size) -> T
  public let shrink: Shrink<T>

  // Future: Add provenance tracking
  public let generateWithTree: (inout any RandomNumberGenerator, Size) -> ShrinkTree<T>

  // Bridge: Automatically derive tree from generate + shrink
  public var integratedGen: Gen<T> {
    Gen { rng, size in
      let value = self.generate(&rng, size)
      return value
    } shrink: { value in
      // Build tree lazily from shrink function
      ShrinkTree.from(value, shrink: self.shrink)
    }
  }
}

// Option 2: New IntegratedGen<T> type
public struct IntegratedGen<T>: @unchecked Sendable {
  public let generate: (inout any RandomNumberGenerator, Size) -> ShrinkTree<T>

  // Automatic shrinking - no separate Shrink<T> needed
}
```

**Migration Strategy:**
1. Keep existing `Gen<T>` + `Shrink<T>` for backward compatibility
2. Add `IntegratedGen<T>` as opt-in new API
3. Provide automatic bridging: `Gen<T>.integrated` property
4. Migrate internal generators incrementally

**Technical Requirements:**
- Lazy tree construction (avoid memory blowup)
- Efficient BFS shrinking (existing `ShrinkTree<T>.findMinimal` is good)
- Composition operators: `map`, `flatMap` preserve shrinking
- Performance monitoring (integrated may be slower for simple types)

**Dependencies:** None (pure Swift 6)

**Confidence:** MEDIUM - Modern best practice, but requires careful API design

**Source:** [Hypothesis: Integrated vs Type-Based Shrinking](https://hypothesis.works/articles/integrated-shrinking/)

---

#### 9. Stateful Testing (`quickcheck-state-machine`)

**QuickCheck Extension:** Separate library for testing stateful systems

**Purpose:** Generate sequences of commands, execute them, verify post-conditions via state machine model.

**Example Use Case:**
```haskell
-- Model: Stack operations
data Command = Push Int | Pop | Peek
data Model = Model [Int]

-- Pre-condition: Pop/Peek require non-empty stack
precondition :: Model -> Command -> Bool
precondition (Model []) Pop  = False
precondition (Model []) Peek = False
precondition _          _    = True

-- Post-condition: Result matches model
postcondition :: Model -> Command -> Result -> Bool
postcondition (Model (x:_)) Peek (Got x') = x == x'
-- ... etc
```

**Swift Implementation:**

InvariantSwift already has `@StateMachine` macro (see `Sources/InvariantSwiftMacros/StateMachineMacroDeclaration.swift`), but lacks:
- Command sequence generation
- Parallel execution testing (race conditions)
- Pre/post-condition validation framework

**Recommended Approach:**

```swift
// State machine protocol
public protocol StateMachine {
  associatedtype State: Sendable
  associatedtype Command: Sendable
  associatedtype Result: Sendable

  var initialState: State { get }

  func precondition(state: State, command: Command) -> Bool
  func execute(state: inout State, command: Command) async throws -> Result
  func postcondition(state: State, command: Command, result: Result) -> Bool
}

// Generator for command sequences
public func commandSequence<SM: StateMachine>(
  for machine: SM,
  length: Int
) -> Gen<[SM.Command]> {
  // Generate valid command sequences respecting preconditions
}

// Parallel testing
public func parallelCommands<SM: StateMachine>(
  for machine: SM,
  prefix: [SM.Command],
  parallel: ([SM.Command], [SM.Command])
) -> Property {
  // Execute prefix sequentially, then parallel branches concurrently
  // Check for race conditions via linearizability
}
```

**Technical Requirements:**
- Swift 6 structured concurrency (`async`/`await`)
- Actor isolation for state access
- Command shrinking (remove commands from sequence)
- Linearizability checking (existing in `Advanced/Linearizability.swift`)

**Dependencies:** None (pure Swift 6)

**Confidence:** MEDIUM - Complex feature, requires careful concurrency design

**Source:** [quickcheck-state-machine - Hackage](https://hackage.haskell.org/package/quickcheck-state-machine)

---

#### 10. Monadic Properties (`Test.QuickCheck.Monadic`)

**QuickCheck API:**
```haskell
-- Test monadic code (IO, State, etc.)
monadicIO $ do
  x <- pick arbitrary  -- Generate value inside monad
  result <- run $ performIO x  -- Run IO action
  assert (result > 0)  -- Check condition
```

**Purpose:** Test properties that require effects (I/O, state, async)

**Swift Implementation:**

InvariantSwift already supports `async` predicates:
```swift
Property(generator: Gen<URL>.url) { url in
  let data = try await URLSession.shared.data(from: url)
  return data.0.count > 0
}
```

**What's Missing:**
- Explicit `pick` for quantification inside async context
- Better control flow for monadic property DSL

**Recommended Enhancement:**

```swift
public struct MonadicProperty<T: Sendable> {
  public func pick<U>(_ generator: Gen<U>) async -> U {
    // Generate value inside async context
  }

  public func run<U>(_ operation: () async throws -> U) async throws -> U {
    // Execute async operation
  }

  public func assert(_ condition: Bool, _ message: String = "") {
    // Check condition with custom message
  }
}

// Usage
monadicProperty(Gen<URL>.url) { url in
  let url2 = pick(Gen<URL>.url)  // Nested generation
  let data1 = try await run { URLSession.shared.data(from: url) }
  let data2 = try await run { URLSession.shared.data(from: url2) }
  assert(data1.0.count > 0 && data2.0.count > 0)
}
```

**Technical Requirements:**
- Swift 6 structured concurrency
- Task isolation and cancellation handling
- Seed management for nested `pick` calls
- Integration with existing `Property<T>` type

**Dependencies:** None (pure Swift 6)

**Confidence:** MEDIUM - Async support exists, needs DSL refinement

**Source:** [Test.QuickCheck.Monadic - Hackage](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck-Monadic.html)

---

## Technology Choices for Implementation

### Core Technologies (Already in Use)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift | 6.0+ | Language | Required. Strict concurrency via `Sendable` |
| SwiftSyntax | 602.0.0 | Macro implementation | Current dependency. AST manipulation for `@PropertyTest` macro |
| Swift Testing | Built-in (Xcode 16+) | Test framework integration | Modern replacement for XCTest. Better async support |
| swift-custom-dump | 1.3.3+ | Pretty-printing | Current dependency. Used for failure output |

**Confidence:** HIGH - All verified in `Package.swift`

---

### Concurrency Primitives

For thread-safe coverage/classification tracking:

| Approach | Use Case | Why |
|----------|----------|-----|
| `actor` | High-level state isolation | Clean API, automatic Sendable conformance, may have overhead |
| `OSAllocatedUnfairLock` | Low-level counters | Zero allocation, fastest, requires `@unchecked Sendable` |
| `Mutex` (Swift 6.2+) | Shared mutable state | Standard library support, good ergonomics |

**Recommendation:** Use `OSAllocatedUnfairLock` for hot paths (coverage counters), `actor` for complex state (classification reports).

**Confidence:** HIGH - Performance-critical path requires lock-free atomics

**Source:** [Swift Concurrency and Testing - Swift Forums](https://forums.swift.org/t/swift-5-10-concurrency-and-xctest/69929)

---

### Data Structures

For efficient distribution tracking:

| Structure | Use Case | Rationale |
|-----------|----------|-----------|
| `Dictionary<String, Int>` | Classification counters | Simple, sufficient for <1000 labels |
| `OrderedDictionary` (Collections) | Tabulation tables | Preserve insertion order for reports |
| `Heap` (Collections) | Top-N classifications | Efficient for "show top 10 categories" |

**Recommendation:** Start with `Dictionary`, optimize if profiling shows bottlenecks.

**Confidence:** HIGH - Standard Swift collections sufficient

---

### Output Formatting

For test distribution reports:

| Approach | Use Case | Why |
|----------|----------|-----|
| Plain text | Terminal output | QuickCheck compatibility, easy to read |
| Structured logging | Swift Testing integration | `Issue.record()` API for rich diagnostics |
| Markdown tables | CI/CD reports | GitHub Actions summary output |

**Recommendation:** Support all three via pluggable reporters. Default to plain text.

**Confidence:** HIGH - Multi-format output is table stakes

---

### Pattern: Property Combinators

For `cover`, `classify`, `label`, etc.:

```swift
// Fluent API via extensions
extension Property {
  func cover(...) -> Property<T> { /* wrap self */ }
  func classify(...) -> Property<T> { /* wrap self */ }
  func label(...) -> Property<T> { /* wrap self */ }
}

// Internal: Decorator pattern
struct CoverageProperty<T>: PropertyProtocol {
  let base: any PropertyProtocol<T>
  let requirements: [CoverageRequirement]

  func evaluate(_ value: T) -> PropertyEvaluation {
    let result = base.evaluate(value)
    // Track coverage
    return result
  }
}
```

**Recommendation:** Use protocol-based decorator pattern. Allows chaining combinators without exponential type explosion.

**Confidence:** HIGH - Standard functional design pattern

---

## What NOT to Use

### ❌ Third-Party Property Testing Frameworks

| Framework | Why Avoid |
|-----------|-----------|
| SwiftCheck | Archived (last update 2019), no Swift 6 support, no Sendable conformance |
| Fox | Objective-C first, clunky Swift API, unmaintained |
| Hedgehog (Haskell port) | No Swift port exists |

**Rationale:** Build on InvariantSwift's existing foundation. SwiftCheck is outdated and incompatible with Swift 6 strict concurrency.

**Confidence:** HIGH - Verified via package archives

**Source:** [SwiftCheck - GitHub](https://github.com/typelift/SwiftCheck)

---

### ❌ Unsafe Concurrency Patterns

| Pattern | Why Avoid |
|---------|-----------|
| `DispatchQueue` + shared mutable state | Data races, no Sendable checking |
| `NSLock` | Objective-C bridging overhead, not Sendable |
| Global mutable variables | Breaks Sendable guarantees |

**Rationale:** Swift 6 strict concurrency requires `Sendable` conformance. Use `actor` or `OSAllocatedUnfairLock`.

**Confidence:** HIGH - Swift 6 requirement

**Source:** [Swift 6 Concurrency Guide](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/)

---

### ❌ Runtime Reflection for Arbitrary Generation

| Approach | Why Avoid |
|----------|-----------|
| `Mirror` for auto-generating instances | Fragile, breaks with private fields, poor performance |
| `@dynamicMemberLookup` for generator DSL | Runtime overhead, no type safety |

**Rationale:** Use Swift macros (`@Arbitrary`) for compile-time generation. InvariantSwift already has this.

**Confidence:** HIGH - Existing macro infrastructure

---

### ❌ String-Based Code Generation

| Pattern | Why Avoid |
|---------|-----------|
| String interpolation for macro expansion | Breaks on complex syntax, no syntax checking |
| Template-based codegen | Fragile, hard to maintain |

**Rationale:** Use SwiftSyntax AST builders. InvariantSwift already follows this pattern.

**Confidence:** HIGH - Existing practice in `Sources/InvariantSwiftMacros/`

---

## Performance Considerations

### Benchmarking Strategy

For new features (`cover`, `classify`, etc.):

```swift
// Use existing Benchmark package
import Benchmark

let benchmarks = {
  Benchmark("Property with coverage") { benchmark in
    for _ in benchmark.scaledIterations {
      checkProperty(
        Property(generator: Gen<Int>.int) { $0 >= 0 }
          .cover(50, when: { $0 > 0 }, label: "positive")
      )
    }
  }

  Benchmark("Property baseline") { benchmark in
    for _ in benchmark.scaledIterations {
      checkProperty(
        Property(generator: Gen<Int>.int) { $0 >= 0 }
      )
    }
  }
}
```

**Target:** <10% overhead for coverage/classification tracking

**Confidence:** HIGH - Existing benchmark infrastructure in `Benchmarks/`

---

### Memory Constraints

For test statistics:

- **Classifications:** Bounded dictionary size (warn if >1000 unique labels)
- **Coverage requirements:** Fixed array size (one per `.cover()` call)
- **Shrink trees:** Already lazy in `ShrinkTree<T>`

**Confidence:** HIGH - Known constraints from QuickCheck usage patterns

---

## Installation & Dependencies

### Current Dependencies (from Package.swift)

```swift
.package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
.package(url: "https://github.com/swiftlang/swift-syntax", exact: "602.0.0"),
.package(url: "https://github.com/google/swift-benchmark", from: "0.1.2"),
```

**No new dependencies required** for P0-P2 features. Everything can be implemented with:
- Swift Standard Library
- Foundation (for `JSONEncoder` in reports)
- SwiftSyntax (existing, for macro support)

**Confidence:** HIGH - All features implementable in pure Swift 6

---

## Implementation Roadmap Implications

### Phase 1: Test Observability (P0)
- `cover` - 3 days
- `classify` - 2 days
- `label` - 1 day
- Integration tests - 2 days
- **Total: ~1 week**

### Phase 2: Enhanced Reporting (P1)
- `collect` - 2 days
- `tabulate` - 3 days
- `counterexample` - 1 day
- Reporter refactoring - 2 days
- **Total: ~1 week**

### Phase 3: Ergonomics (P2)
- Test modifiers (Positive, NonEmpty, etc.) - 1 week
- Integrated shrinking (research + prototype) - 2 weeks
- Stateful testing enhancements - 1 week
- Monadic property DSL - 3 days
- **Total: ~4 weeks**

**Total estimated effort:** 6-7 weeks for full QuickCheck feature parity

**Confidence:** MEDIUM - Estimates based on feature complexity and existing codebase familiarity

---

## Sources

### QuickCheck Documentation
- [Test.QuickCheck - Hackage](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck.html)
- [Test.QuickCheck.Property - Hackage](https://hackage.haskell.org/package/QuickCheck-2.10.1/docs/Test-QuickCheck-Property.html)
- [Test.QuickCheck.Modifiers - Hackage](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck-Modifiers.html)
- [Test.QuickCheck.Monadic - Hackage](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck-Monadic.html)
- [QuickCheck Manual - Chalmers](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html)

### Property-Based Testing Research
- [Hypothesis: Integrated Shrinking](https://hypothesis.works/articles/integrated-shrinking/)
- [quickcheck-state-machine - Hackage](https://hackage.haskell.org/package/quickcheck-state-machine)
- [Testing Monadic Code with QuickCheck - ACM](https://dl.acm.org/doi/10.1145/636517.636527)
- [Property-Based Testing in Swift - Medium](https://medium.com/@truizlop/property-based-testing-in-swift-using-swiftcheck-b5c58ef4d6f)

### Swift Concurrency & Testing
- [Swift 6 Concurrency Guide](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/)
- [XCTest Meets @MainActor](https://qualitycoding.org/xctest-mainactor/)
- [Swift Testing Documentation](https://developer.apple.com/xcode/swift-testing/)
- [Swift Actor Testing - Thumbtack Engineering](https://medium.com/thumbtack-engineering/swift-actor-in-unit-tests-9dc15498b631)

### Alternative Frameworks (Reference Only)
- [SwiftCheck - GitHub](https://github.com/typelift/SwiftCheck) (archived, not recommended)
- [Hypothesis - PyPI](https://pypi.org/project/hypothesis/)
- [FsCheck Documentation](https://fscheck.github.io/FsCheck/Properties.html)

---

## Confidence Summary

| Feature Category | Confidence | Reason |
|-----------------|------------|--------|
| QuickCheck feature list | HIGH | Official Hackage documentation |
| P0-P1 implementations | HIGH | Straightforward API mappings |
| P2 implementations | MEDIUM | Require design exploration (integrated shrinking, stateful) |
| Swift 6 compatibility | HIGH | All features implementable in pure Swift |
| Performance targets | MEDIUM | Need benchmarking to validate <10% overhead |
| Timeline estimates | MEDIUM | Based on feature complexity, not team velocity |

---

## Open Questions

1. **Integrated shrinking migration path:** Deprecate `Shrink<T>` immediately or run both systems in parallel?
   - **Recommendation:** Parallel for backward compatibility

2. **Reporter output format:** Plain text only or also Markdown/JSON?
   - **Recommendation:** Start with plain text, add structured output in P2

3. **Classification storage:** In-memory only or persist to disk for trend analysis?
   - **Recommendation:** In-memory for v2.0, add persistence in v2.1

4. **Stateful testing scope:** Full `quickcheck-state-machine` port or minimal enhancements?
   - **Recommendation:** Minimal for MVP (command sequences), defer parallel testing to v2.1

---

**Ready for roadmap creation.** This STACK.md provides prescriptive technology choices for implementing QuickCheck feature parity in InvariantSwift.
