# Phase 3: Discard & Syntax Sugar - Research

**Researched:** 2026-01-23
**Domain:** QuickCheck implication operator (`==>`) and discard ratio tracking
**Confidence:** HIGH

## Summary

Phase 3 completes QuickCheck ergonomics with two small but high-impact features: the `==>` implication operator for conditional properties and discard ratio tracking to prevent over-filtering. Both features are well-defined in QuickCheck with 25+ years of proven usage. Implementation is straightforward because InvariantSwift already has the necessary infrastructure: `PropertyEvaluation.discard` for the implication operator and discard counting in `PropertyRunner`.

**Key insight:** These features are "developer experience" improvements, not new capabilities. The functionality already exists in different forms (`assume()`, `filter()`, `maxDiscarded`). Phase 3 provides QuickCheck-standard syntax and better feedback on discard problems.

**Primary recommendation:** Implement both features in a single focused sprint. The `==>` operator is syntactic sugar over existing `PropertyEvaluation`, and discard ratio tracking extends existing counters with threshold checking. Estimated effort: 3-5 days total (matching phase estimate).

## Standard Stack

### Core Infrastructure (Already Exists)

| Component | Location | Purpose | Reuse Strategy |
|-----------|----------|---------|----------------|
| `PropertyEvaluation` | `Core/Property.swift:66-82` | `.pass`, `.fail`, `.discard` outcomes | Use `.discard` for `==>` false case |
| `assume()` function | `Core/Property.swift:106-108` | Returns `.pass` or `.discard` | Model for `==>` semantics |
| Discard counting | `PropertyRunner`, `ClassifyingPropertyRunner` | `discarded` variable in run loops | Extend with ratio calculation |
| `PropertyConfig.maxDiscarded` | `Core/Property.swift:431` | Maximum discards before `.gaveUp` | Add ratio thresholds alongside |
| `PropertyResult.gaveUp` | `Core/Property.swift:198` | Reports discard count | Extend message with ratio |

### New Components Needed

| Component | Purpose | Location |
|-----------|---------|----------|
| `==>` operator | Implication syntax sugar | `Core/Property+Implication.swift` |
| `PropertyConfig.DiscardConfig` | Discard ratio thresholds | Extend `Core/Property.swift` |
| Discard ratio warnings | Emit suggestions when ratio is high | Extend `PropertyRunner` |

### No New Dependencies

Phase 3 requires zero external dependencies. All functionality builds on:
- Swift Standard Library (operators, closures)
- Existing `PropertyEvaluation` infrastructure
- Existing `PropertyRunner` discard counting

**Installation:** No changes needed.

## Architecture Patterns

### Recommended Project Structure

```
Sources/InvariantSwift/
├── Core/
│   ├── Property.swift              # EXTEND: DiscardConfig in PropertyConfig
│   ├── Property+Implication.swift  # NEW: ==> operator definition
│   ├── PropertyRunner+Discard.swift # NEW or EXTEND: Ratio tracking and warnings
```

**Alternative:** Integrate `==>` into existing `Property.swift` to avoid new files. Decision: separate file for clarity and SRP.

### Pattern 1: Implication Operator (`==>`)

**What:** QuickCheck-style implication that discards when precondition is false, evaluates consequent when true.

**When to use:** Express preconditions inline without modifying generator or using separate assumption.

**Example:**
```swift
// Source: QuickCheck manual - https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html

// QuickCheck Haskell:
// prop_sorted xs = not (null xs) ==> head (sort xs) == minimum xs

// InvariantSwift:
@PropertyTest
func testSortedHead(array: [Int]) -> PropertyEvaluation {
  !array.isEmpty ==> (array.sorted().first! == array.min()!)
}
```

**Type signature:**
```swift
// Source: QuickCheck Hackage - https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck.html
// (==>) :: Testable prop => Bool -> prop -> Property

// Swift implementation:
infix operator ==> : ImplicationPrecedence

precedencegroup ImplicationPrecedence {
  higherThan: AssignmentPrecedence
  lowerThan: ComparisonPrecedence
  associativity: right  // a ==> b ==> c means a ==> (b ==> c)
}

/// Implication operator for conditional properties.
///
/// If precondition is false, returns `.discard` (test case skipped).
/// If precondition is true, evaluates consequent and returns `.pass` or `.fail`.
///
/// - Parameters:
///   - precondition: Guard condition that must be true for test to be meaningful
///   - consequent: Property assertion to evaluate if precondition holds
///
/// - Returns: `.discard` if precondition false, `.pass`/`.fail` based on consequent
public func ==> (
  precondition: Bool,
  consequent: @autoclosure () -> Bool
) -> PropertyEvaluation {
  guard precondition else { return .discard(reason: nil) }
  return consequent() ? .pass : .fail(reason: nil)
}
```

**Key design decisions:**

1. **`@autoclosure` for consequent:** Short-circuit evaluation when precondition is false. Critical for performance and avoiding errors in consequent.

2. **Right associativity:** Matches QuickCheck semantics for chained implications. `a ==> b ==> c` means "if a, then (if b, then c)".

3. **Returns `PropertyEvaluation`:** Integrates with existing `EvaluatingProperty` runner. Alternative was returning `Bool`, but loses discard semantics.

4. **Precedence lower than comparison:** Allows `n > 0 ==> property` without parentheses. Higher than assignment for intuitive grouping.

### Pattern 2: Overloaded Implication for Different Return Types

**What:** Multiple `==>` overloads for different consequent types.

**When to use:** Support both `Bool` consequent (common case) and `PropertyEvaluation` consequent (explicit control).

**Example:**
```swift
// Bool consequent (common case)
!array.isEmpty ==> (array.first != nil)

// PropertyEvaluation consequent (explicit control)
n > 0 ==> require(n * 2 > n, reason: "doubling should increase")
```

**Implementation:**
```swift
// Overload 1: Bool consequent (syntactic sugar)
public func ==> (
  precondition: Bool,
  consequent: @autoclosure () -> Bool
) -> PropertyEvaluation {
  guard precondition else { return .discard(reason: nil) }
  return consequent() ? .pass : .fail(reason: nil)
}

// Overload 2: PropertyEvaluation consequent (explicit)
public func ==> (
  precondition: Bool,
  consequent: @autoclosure () -> PropertyEvaluation
) -> PropertyEvaluation {
  guard precondition else { return .discard(reason: nil) }
  return consequent()
}
```

### Pattern 3: Discard Ratio Tracking

**What:** Calculate and enforce limits on discard ratio (discards / successful iterations).

**When to use:** Prevent tests that silently filter out 95% of inputs, giving false confidence.

**Example:**
```swift
// Source: BurntSushi/quickcheck Rust - https://github.com/BurntSushi/quickcheck
// Default: 100 tests, max 10,000 attempts (100x ratio)

// InvariantSwift configuration:
let config = PropertyConfig(
  iterations: 100,
  discard: .init(
    warnRatio: 5.0,   // Warn if >5x discards per success
    failRatio: 10.0   // Fail if >10x discards per success
  )
)
```

**Implementation:**
```swift
extension PropertyConfig {
  /// Configuration for discard ratio tracking and enforcement.
  public struct DiscardConfig: Sendable, Equatable {
    /// Discard ratio above which a warning is emitted.
    ///
    /// Warning includes suggestion to redesign generator.
    /// Default: 5.0 (warn if more than 5 discards per successful test)
    public var warnRatio: Double

    /// Discard ratio above which the test fails.
    ///
    /// Default: 10.0 (fail if more than 10 discards per successful test)
    public var failRatio: Double

    /// Enable or disable discard ratio enforcement.
    ///
    /// When disabled, only `maxDiscarded` absolute limit is enforced.
    /// Default: true
    public var enforceRatio: Bool

    /// Default configuration: warn at 5x, fail at 10x.
    public static let `default` = Self(
      warnRatio: 5.0,
      failRatio: 10.0,
      enforceRatio: true
    )

    /// Lenient configuration: warn at 10x, fail at 50x.
    public static let lenient = Self(
      warnRatio: 10.0,
      failRatio: 50.0,
      enforceRatio: true
    )

    /// Disabled configuration: no ratio enforcement.
    public static let disabled = Self(
      warnRatio: .infinity,
      failRatio: .infinity,
      enforceRatio: false
    )
  }

  /// Discard ratio tracking configuration.
  public var discard: DiscardConfig
}
```

### Pattern 4: Actionable Discard Warnings

**What:** When discard ratio exceeds threshold, emit warning with actionable suggestions.

**When to use:** Always when ratio exceeds warnRatio.

**Example output:**
```
Warning: High discard ratio: 7.5x (750 discards / 100 iterations)

Common causes:
  - Filter condition too restrictive
  - Generator produces many invalid inputs
  - Precondition rarely satisfied

Suggestions:
  - Instead of: Gen.int.filter { $0 > 0 }
    Try:        Gen.int(in: 1...)

  - Instead of: array.isEmpty ==> property
    Try:        Gen.array(count: 1...) generator

Consider redesigning generator to produce valid inputs directly.
```

**Implementation:**
```swift
// In PropertyRunner after counting discards:
private func checkDiscardRatio(
  discarded: Int,
  successful: Int,
  config: PropertyConfig
) -> DiscardCheckResult {
  let ratio = successful > 0 ? Double(discarded) / Double(successful) : Double(discarded)

  if config.discard.enforceRatio && ratio > config.discard.failRatio {
    return .fail(formatDiscardFailure(ratio: ratio, discarded: discarded, successful: successful))
  }

  if ratio > config.discard.warnRatio {
    emitDiscardWarning(ratio: ratio, discarded: discarded, successful: successful)
    return .warn
  }

  return .ok
}

private enum DiscardCheckResult {
  case ok
  case warn
  case fail(String)
}
```

### Anti-Patterns to Avoid

**Anti-Pattern 1: Operator Precedence Confusion**
```swift
// BAD - Ambiguous without parentheses
n > 0 && n < 100 ==> n * 2 < 200

// GOOD - Clear grouping
(n > 0 && n < 100) ==> (n * 2 < 200)
```

**Prevention:** Document precedence clearly. `==>` is lower than comparison, so `n > 0 ==> property` works naturally, but compound conditions need parentheses.

**Anti-Pattern 2: Nested Implications**
```swift
// BAD - Hard to read, confusing semantics
a ==> b ==> c ==> d

// GOOD - Extract to named assumptions
let validInput = a && b && c
validInput ==> d
```

**Prevention:** Document that chained `==>` is discouraged. Use compound boolean conditions.

**Anti-Pattern 3: Ignoring Discard Warnings**
```swift
// BAD - Suppress warning without fixing root cause
let config = PropertyConfig(discard: .disabled)

// GOOD - Fix the generator
let validInputGen = Gen.int(in: 1...).filter { $0 < 100 }
```

**Prevention:** Warnings are actionable. Disabling should require explicit justification.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Conditional property | Manual if/else in predicate | `==>` operator | Cleaner syntax, proper discard tracking |
| Discard counting | Custom counter per property | `PropertyRunner` counters | Already implemented, thread-safe |
| Ratio calculation | Manual division | `DiscardConfig` helpers | Edge cases (div by zero, infinity) handled |
| Warning formatting | String concatenation | Structured formatter | Consistent output, actionable suggestions |

**Key insight:** Both features extend existing infrastructure. The temptation to "do it differently" should be resisted.

## Common Pitfalls

### Pitfall 1: Over-Restrictive Preconditions

**What goes wrong:** `==>` with rarely-true precondition causes test to give up or trigger discard ratio failure.

**Why it happens:** Developer uses implication instead of designing generator.

**How to avoid:**
- If precondition is satisfied <10% of the time, redesign generator
- Use `classify` first to measure precondition frequency
- Prefer targeted generators over implication filtering

**Warning signs:**
- Discard ratio > 5x
- Test gives up with "too many discards"
- Test passes quickly with few iterations

**Example:**
```swift
// BAD: Precondition satisfied ~0.01% of the time
(n == Int.max) ==> (n + 1 < n)  // Almost always discards

// GOOD: Generate boundary values directly
let boundaryGen = Gen.frequency([
  (1, Gen.pure(Int.max)),
  (1, Gen.pure(Int.min)),
  (98, Gen.int)
])
```

### Pitfall 2: Confusing `==>` with `&&`

**What goes wrong:** Using `==>` when logical AND is appropriate, or vice versa.

**Why it happens:** Similar appearance, different semantics.

**How to avoid:**
- `==>` DISCARDS when left side is false (test not counted)
- `&&` FAILS when either side is false (test counts as failure)

**Example:**
```swift
// ==> semantics (DISCARD if precondition false):
!array.isEmpty ==> (array.first != nil)
// If array is empty: DISCARD (not counted)
// If array is non-empty and first is nil: FAIL

// && semantics (FAIL if either side false):
!array.isEmpty && (array.first != nil)
// If array is empty: FAIL
// If array is non-empty and first is nil: FAIL
```

### Pitfall 3: Not Monitoring Discard Ratios

**What goes wrong:** Test "passes" but only ran 5 meaningful iterations because 95% were discarded.

**Why it happens:** No visibility into discard statistics.

**How to avoid:**
- Enable discard ratio warnings (default)
- Review test output for warnings
- Use classification to verify input distribution

**Warning signs:**
- Test runs suspiciously fast
- `.gaveUp` results with many discards
- Warnings about high discard ratio

### Pitfall 4: Disabling Ratio Enforcement Without Investigation

**What goes wrong:** Developer disables warnings without fixing root cause.

**Why it happens:** Warnings feel like noise, not signal.

**How to avoid:**
- Treat discard warnings as test failures to investigate
- Document why ratio is necessarily high (if legitimate)
- Consider targeted testing for edge cases

**Example:**
```swift
// BAD: Hide the problem
let config = PropertyConfig(discard: .disabled)

// GOOD: Investigate and document
// This property intentionally tests rare conditions.
// Ratio is high because we're testing boundary behavior.
let config = PropertyConfig(discard: .lenient)

// BETTER: Use targeted generator
let rareCaseGen = Gen.frequency([
  (99, Gen.int(in: 1...1000)),  // Common case
  (1, Gen.int(in: Int.max-10...Int.max))  // Rare case
])
```

### Pitfall 5: Thread Safety with Discard Counting

**What goes wrong:** Race condition when counting discards in parallel execution.

**Why it happens:** Mutable counter accessed from multiple threads.

**How to avoid:**
- Use actor isolation (existing `PropertyRunner` pattern)
- Increment counter atomically
- Aggregate results after parallel execution

**Prevention:** Already handled by existing `PropertyRunner` design. New code follows same pattern.

## Code Examples

### Example 1: Basic Implication Operator

```swift
// Source: QuickCheck manual - https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html
import InvariantSwift

// Property: Non-empty arrays have a first element
@PropertyTest
func testNonEmptyArrayHasFirst(array: [Int]) -> PropertyEvaluation {
  !array.isEmpty ==> (array.first != nil)
}

// Property: Sorted non-empty arrays have minimum at first position
@PropertyTest
func testSortedMinimum(array: [Int]) -> PropertyEvaluation {
  !array.isEmpty ==> (array.sorted().first! == array.min()!)
}
```

### Example 2: Chained Preconditions

```swift
// Multiple preconditions combined
@PropertyTest
func testDivisionByNonZero(a: Int, b: Int) -> PropertyEvaluation {
  (b != 0) ==> ((a / b) * b + (a % b) == a)
}

// Compound precondition (preferred over chaining)
@PropertyTest
func testBoundedRange(n: Int) -> PropertyEvaluation {
  (n > 0 && n < 100) ==> (n * 2 < 200)
}
```

### Example 3: Discard Ratio Configuration

```swift
// Default configuration (warn at 5x, fail at 10x)
let defaultConfig = PropertyConfig()

// Custom configuration
let customConfig = PropertyConfig(
  iterations: 100,
  discard: .init(warnRatio: 3.0, failRatio: 5.0, enforceRatio: true)
)

// Lenient configuration for rare edge cases
let lenientConfig = PropertyConfig(
  discard: .lenient  // warn at 10x, fail at 50x
)

// Run property with configuration
let runner = PropertyRunner(seed: Seed.random)
let result = runner.runProperty(property, config: customConfig)
```

### Example 4: Integration with Classification

```swift
// Combine implication with classification to diagnose discard issues
@PropertyTest
func testPositiveMultiplication(n: Int) -> PropertyEvaluation {
  n > 0 ==> (n * 2 > n)
}
.classify(when: { $0 > 0 }, label: "positive")
.classify(when: { $0 <= 0 }, label: "non-positive (discarded)")

// Output shows:
// positive: 100%
// non-positive (discarded): 0%
// (if classifier runs before discard)

// OR with EvaluatingProperty to track discards:
let property = EvaluatingProperty(generator: Gen.int) { n in
  guard n > 0 else { return .discard(reason: "need positive") }
  return n * 2 > n ? .pass : .fail(reason: "doubling failed")
}
// Discard reason appears in statistics
```

### Example 5: Warning Output Format

```swift
// When running property with high discard ratio:
let property = Property(generator: Gen.int) { n in
  n == 42  // Only passes for n == 42!
}
.filter { $0 == 42 }  // 99.99%+ discards

let result = runPropertySynchronously(property)
// Output:
// Warning: High discard ratio: 9999.0x (9999 discards / 1 iteration)
//
// Common causes:
//   - Filter condition too restrictive
//   - Generator produces many invalid inputs
//
// Suggestions:
//   - Instead of: Gen.int.filter { $0 == 42 }
//     Try:        Gen.pure(42)
//
// Consider redesigning generator to produce valid inputs directly.
```

## State of the Art

| Feature | Old Approach | Current Approach | When Changed | Impact |
|---------|--------------|------------------|--------------|--------|
| Conditional properties | Manual if/else in predicate | `==>` operator | QuickCheck 1.0 (2000) | Standard PBT syntax |
| Discard tracking | Silent discards, `.gaveUp` only | Ratio warnings + configurable limits | Hypothesis (2013) | Prevents false confidence |
| Precondition syntax | `assume()` function | `==>` sugar + `assume()` | Swift-specific | Both available for flexibility |
| Discard messages | "Gave up after N discards" | Actionable suggestions with fix examples | Modern PBT (2020s) | Developer experience |

**Deprecated/outdated:**
- **Silent discards:** Early PBT frameworks didn't warn about high discard ratios. Modern frameworks (Hypothesis, jqwik) enforce limits.
- **Fixed discard limits:** QuickCheck's `maxDiscarded` is absolute. Ratio-based limits (relative to iterations) are more informative.

**Current best practices (2026):**
- Ratio-based discard limits (not just absolute counts)
- Actionable warnings with fix suggestions
- Classification to diagnose discard patterns
- Both `==>` syntax and `assume()` function available

## Open Questions

### Question 1: Operator Symbol Choice

**What we know:**
- QuickCheck uses `==>` for implication
- Swift allows custom operators with this syntax
- No conflict with existing Swift operators

**What's unclear:**
- Should we also provide `.implies()` method as alternative?
- Is `==>` recognizable to non-QuickCheck users?

**Recommendation:** Implement `==>` as primary (QuickCheck standard). Add `.implies()` method later if users request it. Document the operator prominently.

### Question 2: Default Discard Ratios

**What we know:**
- QuickCheck Rust: 100x max attempts per success (effectively 100x ratio limit)
- Hypothesis: configurable, warns when discarding many
- InvariantSwift: Currently has `maxDiscarded` (absolute), no ratio

**What's unclear:**
- What ratios match typical Swift usage?
- Should defaults be strict or lenient?

**Recommendation:** Start with **5x warn, 10x fail** (stricter than QuickCheck Rust). Provide `.lenient` preset for edge case testing. Measure typical ratios in dogfood tests and adjust if needed.

### Question 3: Discard Reason Tracking

**What we know:**
- `PropertyEvaluation.discard(reason:)` supports optional reason string
- Currently not aggregated in reports

**What's unclear:**
- Should discard reasons be tracked per-category like classification?
- Would this add too much overhead?

**Recommendation:** Track discard reasons in `PropertyResult` (simple counter per reason). Defer fancy visualization to Phase 5 (Polish). Core tracking is valuable for debugging.

### Question 4: Integration with `filter()`

**What we know:**
- `Property.filter()` exists and modifies assumption
- `==>` returns `PropertyEvaluation`
- Both cause discards but at different levels

**What's unclear:**
- Should `filter()` discards count toward ratio?
- How to distinguish generator-level vs property-level discards?

**Recommendation:** All discards (from `filter()`, `assume()`, `==>`) count toward the same ratio. This is the conservative approach - if total discards are high, the developer needs to investigate regardless of source.

## Sources

### Primary (HIGH confidence)

- [QuickCheck Manual - Implications](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html) - Official `==>` documentation and semantics
- [QuickCheck Hackage - Test.QuickCheck](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck.html) - Type signature: `(==>) :: Testable prop => Bool -> prop -> Property`
- [QuickCheck Rust - GitHub](https://github.com/BurntSushi/quickcheck) - Discard handling: "if quickcheck can't find 100 valid tests after trying 10,000 times, then it will give up"
- [RipTutorial - QuickCheck Implication](https://riptutorial.com/haskell/example/4413/using-implication-------to-check-properties-with-preconditions) - Usage examples
- InvariantSwift codebase:
  - `Core/Property.swift:66-82` - `PropertyEvaluation` enum with `.discard`
  - `Core/Property.swift:106-108` - `assume()` function implementation
  - `Core/Property.swift:431` - `PropertyConfig.maxDiscarded`

### Secondary (MEDIUM confidence)

- [Swift Custom Operators - SwiftLee](https://www.avanderlee.com/swift/custom-operators-swift/) - Operator declaration syntax
- [Swift Operator Declarations - Apple Docs](https://developer.apple.com/documentation/swift/operator-declarations) - Precedence groups
- [Property-Based Testing in Practice (PDF)](https://andrewhead.info/assets/pdf/pbt-in-practice.pdf) - "Counts of discarded test cases help the developer catch problems early"
- [Hypothesis Python - assume()](https://hypothesis.works/articles/what-is-property-based-testing/) - Discard mechanism

### Tertiary (LOW confidence)

- [School of Haskell - QuickCheck Tutorial](https://www.schoolofhaskell.com/user/pbv/an-introduction-to-quickcheck-testing) - Historical context
- `.planning/research/PITFALLS.md` - Pitfall 4: Over-Filtering with Assumptions

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - `==>` is QuickCheck standard with 25+ years of usage; existing infrastructure verified
- Architecture: **HIGH** - Design follows established patterns from Phases 1-2
- Pitfalls: **HIGH** - Documented extensively in QuickCheck manual and research
- Discard ratios: **MEDIUM** - Defaults based on QuickCheck Rust, may need adjustment

**Research date:** 2026-01-23
**Valid until:** 90 days (stable features, minimal churn expected)

**Key dependencies:**
- Phase 1-2 completion (classification infrastructure for diagnostics)
- Existing `PropertyEvaluation` enum with `.discard` case
- Existing `PropertyRunner` discard counting

**Verification checklist:**
- [x] `==>` semantics verified in QuickCheck documentation
- [x] `PropertyEvaluation.discard` exists in codebase
- [x] Discard counting exists in `PropertyRunner`
- [x] Swift custom operator syntax verified
- [x] Precedence groups understood
- [x] Zero new dependencies required

**Next steps:**
- Proceed to Phase 3 planning (PLAN.md creation)
- Focus on `==>` operator first (simpler, higher impact)
- Extend `PropertyConfig` with `DiscardConfig`
- Add discard ratio checking to `PropertyRunner`
- Create comprehensive tests including dogfood tests
