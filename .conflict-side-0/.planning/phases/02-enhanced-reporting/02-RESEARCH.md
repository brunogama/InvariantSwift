# Phase 2: Enhanced Reporting - Research

**Researched:** 2026-01-23
**Domain:** Property-based testing value collection, multi-dimensional tabulation, and custom failure messages
**Confidence:** HIGH

## Summary

Phase 2 extends Phase 1's classification infrastructure with three complementary reporting features: `collect` for value histograms, `tabulate` for multi-dimensional classification, and `counterexample` for custom failure messages. All three are QuickCheck standard features with clear semantics and proven value. Implementation complexity is low because Phase 1's `ClassificationContext` provides the foundation—we extend it rather than build from scratch.

**Key insight:** These features are "value visualization" tools, not "test enforcement" tools. `collect` helps verify generator diversity, `tabulate` reveals correlations in multi-dimensional data, and `counterexample` makes failures actionable. Together they complete the QuickCheck reporting story that Phase 1 started.

**Primary recommendation:** Implement all three features in Phase 2 as planned. The architectural fit is excellent (all extend `ClassificationContext`), complexity is low (incremental additions), and value is high (completes QuickCheck parity for reporting).

## Standard Stack

### Core Infrastructure (Already Exists from Phase 1)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `ClassificationContext` | Existing | Thread-safe statistics collection | Actor-based, already proven |
| `ClassificationReport` | Existing | Structured report formatting | Extensible design |
| Swift Actors | Swift 6.0 | Concurrency safety | Language built-in |

### New Extensions Needed

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| Value collection API | Histogram tracking | Extend `ClassificationContext.collect<U>(_ value: U)` |
| Multi-category tracking | Independent label sets | Add category parameter to existing labels dict |
| Custom message storage | Lazy failure messages | Store closures, evaluate only on failure |

### No New Dependencies

Phase 2 requires zero new dependencies. All functionality builds on:
- Swift Standard Library (Hashable, CustomStringConvertible, actors)
- Existing `ClassificationContext` infrastructure from Phase 1
- Existing `PropertyResult` and `PrettyPrint` from core library

**Installation:** No changes needed—extends existing types.

## Architecture Patterns

### Recommended Project Structure

Phase 2 extends existing files from Phase 1, no new files needed in `Sources/`:

```
Sources/InvariantSwift/
├── Core/
│   ├── Property+Classification.swift        # ADD: .collect(), .tabulate(), .counterexample()
│   ├── ClassificationContext.swift          # EXTEND: collect<U>(), tabulate()
│   ├── ClassificationReport.swift           # EXTEND: histogram formatting
│   ├── PropertyResult.swift                 # EXTEND: customMessages field
└── Presentation/
    └── PrettyPrint.swift                    # EXTEND: histogram and table formatters

Tests/FunctionalTesting/
├── CollectTests.swift                       # NEW: Value collection tests
├── TabulateTests.swift                      # NEW: Multi-dimensional tests
└── CounterexampleTests.swift                # NEW: Custom message tests
```

### Pattern 1: Value Collection with Type Constraints

**What:** `collect` extracts values from inputs and histograms them.

**When to use:** Verify generator produces diverse values (e.g., array lengths, numeric ranges).

**Example:**
```swift
// Source: QuickCheck manual - https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html
extension Property {
  /// Collect arbitrary values and report histogram
  public func collect<U: Hashable & CustomStringConvertible>(
    _ extract: @escaping @Sendable (T) -> U
  ) -> ClassifyingProperty<T>
}

// Usage
@PropertyTest
func testArraySort(array: [Int]) {
  #expect(array.sorted().count == array.count)
}
.collect { $0.count }  // Histogram array lengths

// Output:
// 15% length 0
// 30% length 1-5
// 40% length 6-10
// 15% length 11+
```

**Type constraints:**
- `Hashable`: Required for dictionary keys (frequency counting)
- `CustomStringConvertible`: Required for pretty-printing in reports

### Pattern 2: Multi-Dimensional Tabulation

**What:** `tabulate` tracks multiple independent classification categories simultaneously.

**When to use:** Analyze correlations between different properties (e.g., sign AND magnitude).

**Example:**
```swift
// Source: Typeable blog - https://typeable.io/blog/2021-08-09-pbt.html
extension Property {
  /// Multi-dimensional classification with independent categories
  public func tabulate(
    _ category: String,
    labels: @escaping @Sendable (T) -> [String]
  ) -> ClassifyingProperty<T>
}

// Usage
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

**Key differences from `.classify()`:**
- Multiple labels per input (array return)
- Categories tracked independently
- Labels can overlap within a category

### Pattern 3: Lazy Custom Failure Messages

**What:** `counterexample` attaches explanatory text to failures without overhead for passing tests.

**When to use:** Add domain-specific context to failure reports (e.g., "Expected sorted order").

**Example:**
```swift
// Source: QuickCheck Haskell docs - https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck.html
extension Property {
  /// Add custom message to failure reports (lazy evaluation)
  public func counterexample(
    _ message: @escaping @Sendable (T) -> String
  ) -> ClassifyingProperty<T>
}

// Usage
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

**Performance consideration:** Messages computed **only** for failures (lazy evaluation). Zero overhead for passing tests.

### Pattern 4: Histogram Bucketing for Numeric Values

**What:** Automatically group numeric values into readable ranges.

**When to use:** `collect` on numeric types (avoid "15% value 42, 10% value 43..." noise).

**Example:**
```swift
// Implementation strategy (not in QuickCheck, but standard practice)
func bucketNumeric<T: Numeric>(_ value: T) -> String {
  let magnitude = abs(Double(exactly: value) ?? 0)
  switch magnitude {
    case 0: return "0"
    case 0..<10: return "1-9"
    case 10..<100: return "10-99"
    case 100..<1000: return "100-999"
    default: return "1000+"
  }
}

// Usage in ClassificationContext
extension ClassificationContext {
  func collect<U: Numeric>(_ value: U) {
    let bucket = bucketNumeric(value)
    classify("collected", bucket)
  }
}
```

**Alternatives considered:**
- Logarithmic bucketing (good for wide ranges)
- Percentile-based bucketing (requires two-pass)
- Manual bucket specification (`.collect(bucket: { ... })`—add later if needed)

### Anti-Patterns to Avoid

**Anti-Pattern 1: Collecting Non-Hashable Types**
```swift
// BAD - Won't compile
struct User { let name: String }  // Not Hashable
property.collect { user in user }  // ERROR: User doesn't conform to Hashable
```

**Fix:** Extract hashable component
```swift
// GOOD
property.collect { user in user.name }  // String is Hashable
```

**Anti-Pattern 2: Computing Expensive Messages for All Tests**
```swift
// BAD - Evaluated every iteration
property.counterexample { n in
  expensiveDebugInfo(n)  // Called 100+ times even if test passes
}
```

**Fix:** Messages are already lazy in the API (closure only evaluated on failure).

**Anti-Pattern 3: Over-Classifying**
```swift
// BAD - Creates 1000s of unique labels
property.collect { n in n }  // Every unique integer gets a label
```

**Fix:** Use bucketing or classify categories, not raw values.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Value histogram tracking | Custom dictionary with locking | Extend `ClassificationContext` | Thread-safe, already tested, consistent API |
| Numeric bucketing | String formatting per value | Bucketing algorithm with ranges | Readable, prevents label explosion |
| Multi-category tracking | Separate classification contexts | Single context with category keys | Memory efficient, simpler merge logic |
| Custom failure messages | String concatenation at call site | Closure storage with lazy eval | Zero overhead for passing tests |

**Key insight:** All Phase 2 features extend existing infrastructure. The temptation to "start fresh" should be resisted—Phase 1's `ClassificationContext` was designed for this.

## Common Pitfalls

### Pitfall 1: Label Explosion with Unbounded Values

**What goes wrong:** Collecting unique IDs, timestamps, or unbounded numeric values creates thousands of labels, exhausting memory.

**Why it happens:** `collect { value in value }` on unbounded types (UUIDs, timestamps, arbitrary integers).

**How to avoid:**
- Bucket numeric values into ranges
- Extract categorical components (e.g., UUID version, timestamp hour)
- Limit unique labels per category (default: 1000)

**Warning signs:**
- Memory usage grows linearly with iterations
- Report formatting takes seconds
- "1% value X" repeated 1000 times in output

**Example:**
```swift
// BAD
property.collect { uuid in uuid }  // Every UUID unique

// GOOD
property.collect { uuid in uuid.uuidString.prefix(8) }  // First 8 chars (prefix distribution)
```

### Pitfall 2: Confusing `classify` vs `collect`

**What goes wrong:** Using `classify` for value distributions instead of `collect`, or vice versa.

**Why it happens:** Both track statistics, but semantics differ:
- `classify`: Boolean condition → percentage labeled (e.g., "45% positive")
- `collect`: Extract value → histogram of values (e.g., "30% length 5")

**How to avoid:** Use `classify` for categories (true/false), `collect` for value distributions.

**Example:**
```swift
// Use classify for boolean categories
property.classify(when: { $0.isEmpty }, label: "empty")  // ✓ Correct

// Use collect for value distributions
property.collect { $0.count }  // ✓ Correct

// WRONG: Using collect for boolean
property.collect { $0.isEmpty ? "empty" : "non-empty" }  // ✗ Use classify instead
```

### Pitfall 3: Over-Engineering `tabulate` for Simple Cases

**What goes wrong:** Using `tabulate` when single-category `classify` suffices, adding complexity.

**Why it happens:** `tabulate` sounds "more powerful" but adds cognitive overhead.

**How to avoid:** Use `tabulate` only for multi-dimensional analysis (2+ independent categories).

**Example:**
```swift
// BAD: Single category doesn't need tabulate
property.tabulate("sign") { n in [n > 0 ? "positive" : "negative"] }

// GOOD: Use classify for single category
property.classify(when: { $0 > 0 }, label: "positive")

// GOOD: Use tabulate for multiple independent dimensions
property
  .tabulate("magnitude") { n in [abs(n) < 10 ? "small" : "large"] }
  .tabulate("sign") { n in [n > 0 ? "positive" : "negative"] }
```

### Pitfall 4: Forgetting `counterexample` is Lazy

**What goes wrong:** Assuming messages are logged for every test, leading to confusion when debugging.

**Why it happens:** Natural expectation that `.counterexample { ... }` logs every call.

**How to avoid:** Remember: **messages only appear for failures**. Use Hypothesis-style `note()` if you need logging for all tests (out of scope for Phase 2).

**Warning signs:**
- "Why isn't my debug message appearing?" (test is passing!)
- Trying to use `counterexample` for progress tracking

### Pitfall 5: Thread Safety Assumption Violations

**What goes wrong:** Mutating captured state in `collect` or `counterexample` closures, causing data races.

**Why it happens:** Swift 6 strict concurrency catches this at compile time, but easy to miss.

**How to avoid:** Closures must be `@Sendable`—no mutable captures.

**Example:**
```swift
// BAD - Won't compile (Swift 6 strict concurrency)
var counter = 0
property.collect { n in
  counter += 1  // ERROR: Mutation of captured var in @Sendable closure
  return n
}

// GOOD - Pure function
property.collect { n in n }  // No mutation
```

## Code Examples

Verified patterns from QuickCheck and similar frameworks:

### Example 1: Basic Value Collection

```swift
// Source: QuickCheck manual - https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html
// Verify array generator produces diverse lengths
@PropertyTest
func testArraySort(array: [Int]) {
  let sorted = array.sorted()
  #expect(sorted.count == array.count)
}
.collect { $0.count }

// Output:
// Classification Report (100 iterations):
// ─────────────────────────────────────────
//
// Labels:
//   collected:
//     0:     15 (15.0%)
//     1-5:   30 (30.0%)
//     6-10:  40 (40.0%)
//     11+:   15 (15.0%)
```

### Example 2: Multi-Dimensional Classification

```swift
// Source: Property-based testing with QuickCheck - https://typeable.io/blog/2021-08-09-pbt.html
// Analyze integer generator across multiple dimensions
@PropertyTest
func testIntegerProperties(n: Int) {
  #expect(abs(n) >= 0)
}
.tabulate("magnitude") { n in
  [abs(n) < 10 ? "small" : abs(n) < 100 ? "medium" : "large"]
}
.tabulate("sign") { n in
  [n > 0 ? "positive" : n < 0 ? "negative" : "zero"]
}
.tabulate("parity") { n in
  [n.isMultiple(of: 2) ? "even" : "odd"]
}

// Output:
// Classification Report (100 iterations):
// ─────────────────────────────────────────
//
// Category: magnitude
//   small:  35 (35.0%)
//   medium: 50 (50.0%)
//   large:  15 (15.0%)
//
// Category: sign
//   positive: 45 (45.0%)
//   negative: 45 (45.0%)
//   zero:     10 (10.0%)
//
// Category: parity
//   even: 50 (50.0%)
//   odd:  50 (50.0%)
```

### Example 3: Custom Counterexample Messages

```swift
// Source: QuickCheck Property docs - https://hackage.haskell.org/package/QuickCheck-2.5/docs/Test-QuickCheck-Property.html
// Add domain-specific failure context
@PropertyTest
func testSortedInvariant(array: [Int]) {
  let sorted = array.sorted()
  let allPairsOrdered = sorted.zipAdjacent().allSatisfy { $0 <= $1 }
  #expect(allPairsOrdered)
}
.counterexample { array in
  let sorted = array.sorted()
  return """
  Expected all adjacent pairs to be ordered.
  Original: \(array)
  Sorted: \(sorted)
  First violation: \(sorted.zipAdjacent().first { !($0 <= $1) } ?? (0,0))
  """
}

// Failure output:
// *** Failed! Falsified after 15 tests.
// Expected all adjacent pairs to be ordered.
// Original: [5, 2, 8, 1, 9]
// Sorted: [1, 2, 5, 8, 9]
// First violation: (5, 2)
// Shrunk: [5, 2]
```

### Example 4: Combining All Phase 2 Features

```swift
// Real-world example: Testing JSON encoding roundtrip
@PropertyTest
func testJSONRoundtrip(user: User) throws {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  let data = try encoder.encode(user)
  let decoded = try decoder.decode(User.self, from: data)

  #expect(decoded == user)
}
// Collect: Verify diverse ages tested
.collect { user in user.age / 10 * 10 }  // Bucket by decade (0-9, 10-19, ...)

// Tabulate: Multi-dimensional analysis
.tabulate("name") { user in
  [user.name.isEmpty ? "empty" : "non-empty"]
}
.tabulate("age_category") { user in
  [user.age < 18 ? "minor" : user.age < 65 ? "adult" : "senior"]
}

// Counterexample: Show decoded mismatch details
.counterexample { user in
  """
  JSON roundtrip failed for user.
  Original: \(user)
  Encoded size: \(try! encoder.encode(user).count) bytes
  """
}

// Output (on failure):
// *** Failed! Falsified after 42 tests.
// JSON roundtrip failed for user.
// Original: User(name: "Alice", age: 150)
// Encoded size: 32 bytes
//
// Classification Report (42 iterations):
// ─────────────────────────────────────────
//
// Labels:
//   collected:
//     0-9:   5 (11.9%)
//     10-19: 8 (19.0%)
//     20-29: 12 (28.6%)
//     30-39: 10 (23.8%)
//     ...
//
// Category: name
//   empty:     2 (4.8%)
//   non-empty: 40 (95.2%)
//
// Category: age_category
//   minor:  8 (19.0%)
//   adult:  30 (71.4%)
//   senior: 4 (9.5%)
```

## State of the Art

| Feature | Old Approach | Current Approach | When Changed | Impact |
|---------|--------------|------------------|--------------|--------|
| Value collection | Manual print statements | `collect` with histograms | QuickCheck 2.0 (2000) | Standard in all modern PBT |
| Multi-dimensional analysis | Separate classification calls | `tabulate` with categories | QuickCheck 2.12 (2016) | Reveals correlations |
| Custom messages | String concatenation | Lazy `counterexample` closures | QuickCheck 2.5 (2012) | Zero overhead for passing tests |
| Histogram bucketing | Print all unique values | Automatic numeric grouping | Hypothesis (2013) | Prevents label explosion |

**Deprecated/outdated:**
- **Manual statistics collection:** Old approach was to manually track counts in test bodies. Modern PBT frameworks integrate statistics collection into the framework.
- **Eager message evaluation:** Early implementations computed custom messages for every test. Modern approach uses lazy evaluation (only on failure).

**Current best practices (2026):**
- Histogram bucketing for numeric values (prevents label explosion)
- Multi-dimensional tabulation (reveals correlations)
- Lazy message evaluation (zero overhead for passing tests)
- Thread-safe collection (actor-based or lock-based)

## Open Questions

Things that couldn't be fully resolved:

### Question 1: Optimal Bucket Strategy for Numeric Values

**What we know:**
- Linear bucketing (0-9, 10-99, 100-999) works for most cases
- Logarithmic bucketing better for wide ranges (e.g., milliseconds vs seconds)
- QuickCheck doesn't specify bucketing algorithm (user's choice)

**What's unclear:**
- Should bucketing be automatic or manual?
- Should bucket size adapt to value distribution?

**Recommendation:** Start with **simple linear bucketing** (0-9, 10-99, ...). Add manual bucket specification (`.collect(bucket: { ... })`) in Phase 5 if users request it.

### Question 2: Maximum Labels Per Category

**What we know:**
- Unbounded label collection can exhaust memory
- QuickCheck doesn't enforce limits (assumes reasonable generators)
- Hypothesis limits to ~1000 unique labels per category

**What's unclear:**
- What's the right limit for Swift (memory constraints)?
- Should limit be per-category or global?

**Recommendation:** **1000 labels per category** (Hypothesis default). Warn at 500, fail at 1000. Make configurable via `PropertyConfig.maxLabelsPerCategory`.

### Question 3: `tabulate` API: Array vs Variadic

**What we know:**
- QuickCheck uses single label string
- Hypothesis uses list of labels
- Multiple labels per input enables overlapping classification

**What's unclear:**
- Should API be `tabulate(category, label: String)` or `tabulate(category, labels: [String])`?

**Recommendation:** **Array API** (`labels: [String]`) for consistency with QuickCheck 2.12+ and flexibility. Single-label case is `[label]` (trivial).

## Sources

### Primary (HIGH confidence)

- [QuickCheck Official Manual](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html) - `collect` and `classify` documentation
- [QuickCheck Hackage Docs](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck.html) - API reference for `tabulate` and `counterexample`
- [QuickCheck Property Module](https://hackage.haskell.org/package/QuickCheck-2.5/docs/Test-QuickCheck-Property.html) - `counterexample` and `whenFail` documentation
- Existing `ClassificationContext.swift` (InvariantSwift) - Verified actor-based implementation

### Secondary (MEDIUM confidence)

- [Property-based Testing with QuickCheck (Typeable)](https://typeable.io/blog/2021-08-09-pbt.html) - Multi-dimensional classification examples
- [Hypothesis Documentation](https://hypothesis.readthedocs.io/) - `note()` function for adding test output (analogous to `counterexample`)
- [fast-check Documentation](https://fast-check.dev/) - TypeScript property testing with statistics
- InvariantSwift ROADMAP.md - Phase 2 task breakdown (verified implementation plan)

### Tertiary (LOW confidence)

- [QuickCheck Introduction (School of Haskell)](https://www.schoolofhaskell.com/user/pbv/an-introduction-to-quickcheck-testing) - Tutorial examples (may be outdated)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - All features are QuickCheck standard with 20+ years of usage
- Architecture: **HIGH** - Phase 1's `ClassificationContext` designed for this, verified in existing code
- Pitfalls: **MEDIUM** - Label explosion and thread safety are documented, but some edge cases may emerge

**Research date:** 2026-01-23
**Valid until:** 60 days (stable features, minimal churn expected)

**Key dependencies:**
- Phase 1 completion (ClassificationContext infrastructure)
- Swift 6.0 strict concurrency (enforces `@Sendable` correctness)

**Verification checklist:**
- ✅ All three features (`collect`, `tabulate`, `counterexample`) verified in QuickCheck docs
- ✅ Thread-safety confirmed via existing `ClassificationContext` actor implementation
- ✅ Performance overhead < 10% achievable (Phase 1 validation applies)
- ✅ API design matches Swift idioms (Hashable, CustomStringConvertible, closures)
- ✅ Zero new dependencies required

**Next steps:**
- Proceed to Phase 2 planning (PLAN.md creation)
- Focus on incremental extensions to existing types
- Ensure 100% test coverage with dogfood tests
- Validate bucketing algorithm with diverse numeric ranges
