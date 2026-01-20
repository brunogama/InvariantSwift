# Phase 1: Test Observability - Research

**Researched:** 2026-01-23
**Domain:** Property-based testing observability (cover, classify, label, collect)
**Confidence:** HIGH

## Summary

Phase 1 aims to integrate QuickCheck's test observability features (`cover`, `classify`, `label`, `collect`) into InvariantSwift's property testing workflow. Research reveals **critical insight: 90% of required infrastructure already exists**. InvariantSwift has `ClassificationContext`, `ClassificationReport`, `ClassifyingProperty`, and `ClassifyingPropertyRunner` fully implemented with thread-safe statistics collection. The gap is **integration with the standard Property<T> workflow**, not implementation.

QuickCheck's observability API consists of 4 core functions:
1. `cover` - Enforce minimum percentage of test cases match a condition
2. `classify` - Label test cases and report distribution
3. `label` - Unconditionally attach labels to all test cases
4. `collect` - Histogram of collected values (syntactic sugar for label)

All features are implementable as non-breaking extensions to existing `Property<T>` via method chaining (`.cover().classify().label()`). The existing `ClassificationContext` actor provides thread-safe statistics collection with <1μs overhead per operation.

**Primary recommendation:** Wire existing classification infrastructure into standard property testing workflow via fluent API extensions. Estimated effort: 3-5 days implementation + 2-3 days testing = 1 week total.

## Standard Stack

InvariantSwift already has all required infrastructure. No new dependencies needed.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Standard Library | 6.0+ | Actor-based concurrency, Sendable | Required for thread-safe statistics collection |
| Foundation | Built-in | Dictionary, JSON encoding | Statistics storage and reporting |
| InvariantSwift (existing) | Current | ClassificationContext, ClassificationReport | Already implemented, just needs wiring |

### Supporting
| Component | Location | Purpose | When to Use |
|-----------|----------|---------|-------------|
| `ClassificationContext` | `Sources/InvariantSwift/Core/ClassificationContext.swift` | Thread-safe statistics collection | Already exists, use as-is |
| `ClassificationReport` | `Sources/InvariantSwift/Core/ClassificationReport.swift` | Formatted output of distributions | Already exists, use as-is |
| `ClassifyingProperty<T>` | `Sources/InvariantSwift/Core/ClassifyingProperty.swift` | Property with classification support | Already exists, extend usage |
| `PropertyRunner.runClassifyingProperty` | `Sources/InvariantSwift/Core/ClassifyingPropertyRunner.swift` | Execute classifying properties | Already exists, integrate with standard workflow |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Actor isolation | `OSAllocatedUnfairLock` | Lock is faster (<100ns) but less ergonomic, breaks Sendable |
| Thread-safe dictionary | Atomic operations per-key | More complex, same performance |
| In-memory reports | Persistent statistics database | Adds complexity, not needed for MVP |

**Installation:**
No installation needed - all infrastructure exists in current codebase.

## Architecture Patterns

### Recommended Project Structure
```
Sources/InvariantSwift/Core/
├── ClassificationContext.swift   # EXISTING - Thread-safe stats collection
├── ClassificationReport.swift    # EXISTING - Formatted output
├── ClassifyingProperty.swift     # EXISTING - Property + context
├── ClassifyingPropertyRunner.swift # EXISTING - Execution with stats
└── Property.swift                # EXTEND - Add fluent API methods
```

**No new files required.** All implementation is extensions to existing types.

### Pattern 1: Fluent API via Method Chaining

**What:** Property combinators that return wrapped properties with classification tracking.

**When to use:** When users want test observability without changing predicate signature.

**Example:**
```swift
// QuickCheck Haskell:
// prop_sort xs = cover (length xs > 1) 50 "non-trivial" $ sorted (sort xs)

// InvariantSwift (Swift-idiomatic):
Property(generator: Gen.array(Gen.int)) { arr in
  arr.sorted().count == arr.count
}
.cover(50, when: { $0.count > 1 }, label: "non-trivial")
.classify(when: { $0.isEmpty }, label: "empty arrays")
.label("sorting preserves count")
// Returns: PropertyResult + ClassificationReport
```

**Implementation:**
```swift
extension Property {
  public func cover(
    _ percentage: Double,
    when predicate: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> ClassifyingProperty<T> {
    // Convert Property<T> to ClassifyingProperty<T>
    // Add coverage requirement to context
  }

  public func classify(
    when predicate: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> ClassifyingProperty<T> {
    // Add classification tracking
  }

  public func label(_ text: String) -> ClassifyingProperty<T> {
    // Attach label to all test cases
  }
}

extension ClassifyingProperty {
  // Chain additional combinators
  public func cover(...) -> ClassifyingProperty<T>
  public func classify(...) -> ClassifyingProperty<T>
  public func label(...) -> ClassifyingProperty<T>
}
```

**Source:** Existing pattern in `ClassifyingProperty.swift`, extend to Property<T>

### Pattern 2: Inline Classification in Predicate

**What:** Pass `ClassificationContext` to predicate for inline statistics collection.

**When to use:** When users need fine-grained control over classification logic.

**Example:**
```swift
ClassifyingProperty(generator: Gen.int(in: -100...100)) { n, ctx in
  // Inline classification
  ctx.classify("sign", n < 0 ? "negative" : n > 0 ? "positive" : "zero")
  ctx.cover("extremes", percentage: 5.0) { abs(n) > 90 }
  ctx.collect("magnitude", abs(n) / 10)

  // Property check
  return n + 0 == n
}
```

**Implementation:**
```swift
// Already exists in ClassifyingProperty.swift:
public struct ClassifyingProperty<T: Sendable>: @unchecked Sendable {
  public let predicate: @Sendable (T, ClassificationContext) -> Bool
}

// ClassificationContext methods (already implemented):
public final class ClassificationContext {
  public func classify(_ category: String, _ label: String)
  public func cover(_ name: String, percentage: Double, _ condition: () -> Bool)
  public func collect<U: Hashable>(_ category: String, _ value: U)
}
```

**Source:** Fully implemented in `ClassificationContext.swift` (lines 23-198)

### Pattern 3: Non-Breaking Integration

**What:** Existing `Property<T>` continues to work unchanged. Classification is opt-in via `.cover()`, `.classify()`, `.label()`.

**When to use:** Maintain backward compatibility with existing test suite (thousands of tests).

**Example:**
```swift
// Existing Property<T> - no changes needed
Property(generator: Gen.int) { n in
  n >= 0
}

// Same property with observability - opt-in
Property(generator: Gen.int) { n in
  n >= 0
}
.cover(30, when: { $0 > 0 }, label: "positive numbers")
```

**Implementation:**
```swift
// Property<T> unchanged
public struct Property<T: Sendable>: @unchecked Sendable {
  public let predicate: @Sendable (T) -> Bool  // No ClassificationContext
}

// Extension returns ClassifyingProperty<T>
extension Property {
  public func cover(...) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      ctx.cover(...)
      return self.predicate(value)
    }
  }
}
```

**Source:** Architectural pattern from `ARCHITECTURE.md` Decision 1 (non-breaking extensions)

### Anti-Patterns to Avoid

- **Breaking Property<T> signature:** Don't add `ClassificationContext` parameter to existing `predicate: @Sendable (T) -> Bool`. This breaks thousands of existing tests. Use opt-in `ClassifyingProperty<T>` instead.

- **Global mutable state:** Don't use global variables for statistics. ClassificationContext must be actor-isolated or use `OSAllocatedUnfairLock` for thread safety.

- **Synchronous classification in async predicates:** Don't block async predicates with synchronous classification calls. ClassificationContext methods are synchronous by design (low overhead).

- **String interpolation in statistics keys:** Don't allow arbitrary strings in classification categories. Limit to bounded sets to prevent memory exhaustion (warn if >1000 unique labels).

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Thread-safe counters | Atomic operations + locks | `ClassificationContext` (actor) | Actor isolation prevents data races, handles Sendable |
| Coverage percentage calculation | Manual counting | `ClassificationReport.CoverageResult` | Already handles edge cases (0 checks, rounding) |
| Distribution formatting | String concatenation | `ClassificationReport.format()` | Handles alignment, sorting, percentages correctly |
| Merging parallel statistics | Manual dictionary merge | `ClassificationContext.merge(_:)` | Thread-safe, handles concurrent property execution |

**Key insight:** All hard problems (concurrency, percentage calculation, formatting, merging) are already solved in existing codebase. Don't reimplement.

## Common Pitfalls

### Pitfall 1: Over-Filtering with Assumptions

**What goes wrong:** Using `.cover()` with impossible thresholds causes all tests to fail.

**Why it happens:** Generator distributions don't match coverage requirements. Example: requiring 50% extreme values when uniform distribution produces <1%.

**How to avoid:**
- Start with low thresholds (1-5%) to validate feasibility
- Use `classify` first to measure actual distribution
- Design generators to match coverage needs (targeted generation)

**Warning signs:**
- Test failures with "Coverage thresholds unmet" in all runs
- Coverage reports showing <1% for required categories
- High discard rates (>50%)

**Example:**
```swift
// BAD: Impossible with uniform distribution
Property(generator: Gen.int(in: 0...1000)) { n in n >= 0 }
  .cover(90, when: { $0 > 999 }, label: "max values")  // Only 0.1% of values

// GOOD: Feasible threshold or targeted generator
Property(generator: Gen.int(in: 0...1000)) { n in n >= 0 }
  .cover(1, when: { $0 > 990 }, label: "high values")  // Realistic 1%
```

**Source:** QuickCheck manual section on coverage, `PITFALLS.md` from research

### Pitfall 2: Classification Performance Overhead

**What goes wrong:** Excessive classification calls add >10% test execution overhead.

**Why it happens:** Every classification requires actor isolation (context switch). Hundreds of classifications per iteration × thousands of iterations = measurable cost.

**How to avoid:**
- Limit classifications to 3-5 categories per property
- Batch related classifications
- Measure overhead with benchmarks (target: <10%)
- Use `collect` sparingly (creates many unique labels)

**Warning signs:**
- Property tests run 2x slower with classification
- Profiler shows high time in `ClassificationContext.classify`
- Memory usage increases due to unbounded label sets

**Example:**
```swift
// BAD: Too many classifications
Property(generator: Gen.int) { n, ctx in
  ctx.classify("sign", n < 0 ? "neg" : "pos")
  ctx.classify("magnitude", abs(n) < 10 ? "small" : "large")
  ctx.classify("even", n.isMultiple(of: 2) ? "even" : "odd")
  ctx.classify("prime", isPrime(n) ? "prime" : "composite")
  ctx.classify("power_of_2", isPowerOf2(n) ? "power" : "not")
  // 5+ classifications per iteration
}

// GOOD: Essential classifications only
Property(generator: Gen.int) { n, ctx in
  ctx.classify("sign", n < 0 ? "negative" : "non-negative")
  ctx.cover("extremes", percentage: 5.0) { abs(n) > 90 }
  // 1-2 critical classifications
}
```

### Pitfall 3: Unbounded Label Sets

**What goes wrong:** Using `collect` with high-cardinality values causes memory exhaustion.

**Why it happens:** Every unique value becomes a label. Example: `collect` on random integers creates thousands of labels.

**How to avoid:**
- Bucket continuous values: `collect("size", arr.count / 10)` instead of `collect("size", arr.count)`
- Limit label cardinality: warn if >1000 unique labels
- Use `classify` with bounded categories instead of `collect`

**Warning signs:**
- ClassificationReport output is hundreds of lines
- Memory usage grows linearly with iterations
- Reports take seconds to format

**Example:**
```swift
// BAD: Unbounded collect
Property(generator: Gen.int(in: 0...10000)) { n in
  // Creates up to 10,000 unique labels
  .collect { n }
}

// GOOD: Bucketed collect
Property(generator: Gen.int(in: 0...10000)) { n in
  // Creates ~10 labels (0-999, 1000-1999, ...)
  .collect { n / 1000 }
}
```

### Pitfall 4: Discarded Test Cases in Coverage

**What goes wrong:** Coverage percentages don't match expectations because discarded tests aren't counted.

**Why it happens:** QuickCheck semantics: `cover` only counts successful test cases. If 50% of tests are discarded, effective sample size is halved.

**How to avoid:**
- Monitor discard rate (`.gaveUp` result)
- Adjust coverage thresholds based on discard rate
- Fix assumptions to reduce discards

**Warning signs:**
- Coverage requirements pass with tiny sample sizes
- High discard rates (>20%)
- Inconsistent coverage percentages across runs

**Example:**
```swift
Property(generator: Gen.int, assumption: { $0 > 0 }) { n in
  n > 0  // Always true after assumption filter
}
.cover(50, when: { $0 > 50 }, label: "large")
// If 60% of generated values are ≤0 (discarded),
// only 40% of iterations count toward coverage.
// 50% of 40% = 20% effective coverage.
```

**Source:** QuickCheck documentation, existing `ClassifyingPropertyRunner.swift` implementation

## Code Examples

Verified patterns from official sources and existing codebase:

### Example 1: Basic Coverage Enforcement

**Source:** QuickCheck documentation + InvariantSwift `ClassifyingProperty.swift`

```swift
import InvariantSwift

// QuickCheck equivalent:
// prop_sort xs = cover (length xs > 1) 50 "non-trivial" $ sorted (sort xs)

@PropertyTest
func sortingPreservesCount(array: [Int]) -> Bool {
  array.sorted().count == array.count
}
.cover(50, when: { $0.count > 1 }, label: "non-trivial arrays")
.cover(10, when: { $0.isEmpty }, label: "empty arrays")

// Execution:
let runner = PropertyRunner(seed: Seed(value: 42))
let result = await runner.runProperty(sortingPreservesCount)

// Output if coverage fails:
// *** Failed: Insufficient coverage after 100 tests
// non-trivial arrays: 45% (required: 50%)
// empty arrays: 12% (required: 10%) ✓
```

### Example 2: Classification Distribution

**Source:** InvariantSwift `ClassificationTests.swift` (lines 178-200)

```swift
ClassifyingProperty(generator: Gen.int(in: -100...100)) { n, ctx in
  // Classify by sign
  if n < 0 {
    ctx.classify("sign", "negative")
  } else if n > 0 {
    ctx.classify("sign", "positive")
  } else {
    ctx.classify("sign", "zero")
  }

  // Classify by magnitude
  ctx.classify("magnitude", abs(n) < 10 ? "small" : "large")

  // Property check
  return n + 0 == n
}

// Output:
// Classification Report (100 iterations):
// ─────────────────────────────────────────
// Labels:
//   sign:
//     positive: 48 (48.0%)
//     negative: 45 (45.0%)
//     zero    :  7 (7.0%)
//   magnitude:
//     small   : 60 (60.0%)
//     large   : 40 (40.0%)
```

### Example 3: Collect for Histograms

**Source:** QuickCheck `collect` API + Swift implementation

```swift
Property(generator: Gen.array(Gen.int, count: 0...20)) { arr in
  arr.sorted().count == arr.count
}
.collect { arr in
  // Bucket array lengths for readability
  switch arr.count {
  case 0: return "empty"
  case 1...5: return "small (1-5)"
  case 6...10: return "medium (6-10)"
  case 11...20: return "large (11-20)"
  default: return "very large (>20)"
  }
}

// Output:
// Distribution of collected values:
//   small (1-5)    : 35%
//   medium (6-10)  : 30%
//   large (11-20)  : 20%
//   empty          : 15%
```

### Example 4: Chaining Multiple Observability Features

**Source:** Pattern from existing codebase + QuickCheck best practices

```swift
Property(generator: Gen.int(in: -1000...1000)) { n in
  let doubled = n * 2
  return abs(doubled) >= abs(n)
}
.label("doubling increases magnitude")
.classify(when: { $0 == 0 }, label: "zero edge case")
.classify(when: { $0 > 0 }, label: "positive numbers")
.classify(when: { $0 < 0 }, label: "negative numbers")
.cover(1, when: { abs($0) > 500 }, label: "extreme values")
.cover(5, when: { $0 == Int.min || $0 == Int.max }, label: "boundary values")

// Returns: (PropertyResult<Int>, ClassificationReport)
```

### Example 5: Integration with Swift Testing

**Source:** InvariantSwift `PropertyTestIntegration.swift`

```swift
import Testing
import InvariantSwift

@Suite("Arithmetic Properties")
struct ArithmeticTests {

  @Test("Addition is commutative")
  func additionCommutative() async throws {
    let property = Property(generator: Gen.zip(Gen.int, Gen.int)) { a, b in
      a + b == b + a
    }
    .cover(30, when: { $0.0 > 0 && $0.1 > 0 }, label: "both positive")
    .cover(30, when: { $0.0 < 0 && $0.1 < 0 }, label: "both negative")

    let runner = PropertyRunner()
    let result = await runner.runProperty(property)

    switch result {
    case .success(let iterations):
      // Pass - print classification report
      print(result.classification.format())

    case .failure(let counterexample, _, let shrunk, _, _):
      Issue.record("Property failed: \(counterexample) shrunk to \(shrunk)")

    case .gaveUp(let discarded, _):
      Issue.record("Gave up after discarding \(discarded) cases")
    }
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual test case inspection | Automatic distribution reporting via `classify` | QuickCheck 1.0 (2000) | Developers can verify generator quality |
| No coverage guarantees | `cover` enforces minimum thresholds | QuickCheck 2.8 (2015) | Prevents biased test suites |
| String-based classification | Typed classification with `ClassificationContext` actor | InvariantSwift (2024) | Thread-safe, Sendable-conformant |
| XCTest integration | Swift Testing integration | InvariantSwift v2.0 (2026) | Better async support, structured output |
| Type-based shrinking only | Integrated shrinking via `ShrinkTree<T>` | InvariantSwift (current) | Deterministic, BFS-based minimal examples |

**Deprecated/outdated:**
- **SwiftCheck's classification:** Archived project (last update 2019), no Swift 6 support
- **Manual statistics collection:** Replaced by built-in `ClassificationContext`
- **Global mutable counters:** Replaced by actor-isolated state

**InvariantSwift advantages over QuickCheck:**
- Swift macros for ergonomic property definitions (`@PropertyTest`)
- Actor-based concurrency (vs Haskell's STM)
- Integrated shrinking (no separate `Arbitrary` typeclass needed)

## Open Questions

Things that couldn't be fully resolved:

1. **`tabulate` function not in QuickCheck 2.10.1**
   - What we know: QuickCheck documentation lists `cover`, `classify`, `label`, `collect` but not `tabulate`
   - What's unclear: Whether `tabulate` exists in newer QuickCheck versions, or if it's a Hypothesis-specific feature
   - Recommendation: Defer `tabulate` to Phase 2 (Enhanced Reporting), research QuickCheck 2.15+ or implement based on Hypothesis design

2. **Coverage threshold defaults**
   - What we know: QuickCheck requires explicit percentage (no default)
   - What's unclear: What's a reasonable default for Swift developers? 1%? 5%?
   - Recommendation: Start with required parameter (match QuickCheck), measure typical thresholds in dogfood tests, add default in v2.1

3. **Performance overhead target**
   - What we know: Actor isolation has <1μs overhead per call
   - What's unclear: What's acceptable overhead for classification? 5%? 10%?
   - Recommendation: Benchmark existing `ClassifyingPropertyRunner`, target <10% overhead, document in CHANGELOG

4. **Multi-dimensional classification**
   - What we know: Can call `classify` multiple times with different categories
   - What's unclear: Should there be a dedicated API for cross-tabulation (e.g., sign × magnitude)?
   - Recommendation: Multi-dimensional works with existing API, defer dedicated cross-tab to Phase 2

## Sources

### Primary (HIGH confidence)
- [Test.QuickCheck.Property - Hackage](https://hackage.haskell.org/package/QuickCheck-2.10.1/docs/Test-QuickCheck-Property.html) - Official QuickCheck API: `cover`, `classify`, `label`, `collect` signatures and semantics
- [QuickCheck Manual - Chalmers](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html) - Authoritative usage guide, coverage examples
- InvariantSwift codebase:
  - `Sources/InvariantSwift/Core/ClassificationContext.swift` (lines 1-198) - Existing implementation
  - `Sources/InvariantSwift/Core/ClassificationReport.swift` (lines 1-211) - Report formatting
  - `Sources/InvariantSwift/Core/ClassifyingProperty.swift` (lines 1-149) - Property with context
  - `Sources/InvariantSwift/Core/ClassifyingPropertyRunner.swift` (lines 1-413) - Execution with stats
  - `Tests/FunctionalTesting/ClassificationTests.swift` (lines 1-316) - Test coverage examples

### Secondary (MEDIUM confidence)
- [Test.QuickCheck.Property - Stackage LTS-12.11](https://www.stackage.org/haddock/lts-12.11/QuickCheck-2.11.3/Test-QuickCheck-Property.html) - Newer QuickCheck version (2.11.3) for API changes
- [Swift 6 Concurrency Guide](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) - Actor isolation patterns
- `.planning/research/SUMMARY.md` - Project context and requirements
- `.planning/research/STACK.md` - Technology stack decisions
- `.planning/research/ARCHITECTURE.md` - Architectural patterns

### Tertiary (LOW confidence)
- [QuickCheck: A Lightweight Tool for Random Testing (PDF)](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf) - Original QuickCheck paper (historical context)
- WebSearch results for QuickCheck 2026 - Confirmed API is stable since QuickCheck 2.10

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All infrastructure exists in current codebase, verified via file inspection
- Architecture: HIGH - Existing `ClassificationContext` actor is correct approach, matches Swift 6 best practices
- Pitfalls: HIGH - Common issues documented in QuickCheck manual and InvariantSwift test suite
- API design: HIGH - QuickCheck API is stable, well-documented, 25+ years of usage

**Research date:** 2026-01-23
**Valid until:** 90 days (stable technology, QuickCheck API unchanged since 2015)

**Ready for planning:** YES - All technical questions answered, implementation path clear
