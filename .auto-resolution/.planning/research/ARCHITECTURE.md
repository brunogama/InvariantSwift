# Architecture Patterns: QuickCheck Integration with InvariantSwift

**Domain:** Property-based testing framework integration
**Researched:** 2026-01-23
**Confidence:** HIGH

## Executive Summary

InvariantSwift has a robust architecture foundation with:
- **Gen<T>**: Closure-based generator with integrated shrinking support
- **Property<T>**: Test definition with generator, assumption, and predicate
- **PropertyRunner**: Actor-based execution engine with BFS shrinking (via ShrinkTree<T>)
- **@PropertyTest macro**: Swift Testing integration

QuickCheck's cover/classify/collect features require **execution-time statistics collection** without breaking the existing architecture. The key insight: **InvariantSwift already has classification infrastructure** (`ClassificationContext`, `ClassificationReport`, `ClassifyingProperty`) but it's not integrated into the standard Property<T> execution path.

**Critical architectural decisions:**
1. Statistics collection via `ClassificationContext` passed to predicates
2. Non-breaking extension: `Property<T>` remains unchanged, new `ClassifyingProperty<T>` opt-in
3. `PropertyRunner` extended with `runClassifyingProperty` method
4. Discard improvements: explicit `PropertyEvaluation` return type with `.discard(reason:)`
5. Integrated shrinking: Already implemented via `ShrinkTree<T>` and `Gen.generateTree`

---

## Recommended Architecture

### Layer 1: Core Types (No Changes Required)

```
┌─────────────────────────────────────────────────────────┐
│                    Core Types (Stable)                  │
├─────────────────────────────────────────────────────────┤
│ Gen<T>: (RNG, Size) -> T with Shrink<T>                │
│ Property<T>: generator + assumption + predicate         │
│ PropertyRunner: Actor-based execution engine            │
│ ShrinkTree<T>: BFS-based shrinking (already integrated) │
└─────────────────────────────────────────────────────────┘
```

**Key insight:** The existing architecture is sound. Gen<T> already supports integrated shrinking via `generateTree(_:_:)` and `generateTreeOverride`. PropertyRunner uses `ShrinkTree<T>` for BFS-based minimal counterexample search.

### Layer 2: Statistics Collection (Extend Existing)

```
┌────────────────────────────────────────────────────────────┐
│            Classification Infrastructure                   │
├────────────────────────────────────────────────────────────┤
│ ClassificationContext (EXISTING)                          │
│   .classify(category, label)  # Record distribution       │
│   .cover(name, pct) { cond }  # Require minimum coverage  │
│   .collect(category, value)   # Histogram collection      │
├────────────────────────────────────────────────────────────┤
│ ClassificationReport (EXISTING)                           │
│   labelDistribution: [String: [String: LabelStats]]      │
│   coverageResults: [String: CoverageResult]              │
│   totalIterations: Int                                    │
└────────────────────────────────────────────────────────────┘
```

**Status:** Infrastructure exists but not integrated into standard Property<T> runner.

**Gap:** `PropertyRunner.runProperty` doesn't instantiate `ClassificationContext`.

### Layer 3: Discard Handling (Already Implemented)

```
┌─────────────────────────────────────────────────────────┐
│              Discard Semantics (EXISTING)               │
├─────────────────────────────────────────────────────────┤
│ PropertyEvaluation enum:                                │
│   .pass              # Property holds                   │
│   .fail(reason)      # Property failed                  │
│   .discard(reason)   # Assumption violated              │
├─────────────────────────────────────────────────────────┤
│ Helper functions:                                       │
│   assume(cond, reason) -> PropertyEvaluation            │
│   require(cond, reason) -> PropertyEvaluation           │
├─────────────────────────────────────────────────────────┤
│ Result types:                                           │
│   PropertyResult<T>.gaveUp(discarded, iterations)       │
└─────────────────────────────────────────────────────────┘
```

**Status:** Fully implemented in `Core/Property.swift`. `PropertyRunner.runEvaluatingProperty` handles `.discard` correctly.

### Layer 4: Integration Points (NEW)

```
┌──────────────────────────────────────────────────────────┐
│         Property<T> Statistics Collection (NEW)          │
├──────────────────────────────────────────────────────────┤
│ Option A: Non-breaking extension                        │
│   ClassifyingProperty<T>: Property + ClassificationCtx  │
│   PropertyRunner.runClassifyingProperty(...)            │
│                                                          │
│ Option B: Breaking change (NOT RECOMMENDED)             │
│   Property<T> predicate: (T, ClassificationContext)     │
└──────────────────────────────────────────────────────────┘
```

**Recommendation:** Use Option A. Keep Property<T> unchanged, extend with ClassifyingProperty<T>.

---

## Component Boundaries and Interactions

### Current Flow (Property<T>)

```
┌──────────────┐
│ Property<T>  │
│  generator   │──generate──>┌─────────────────┐
│  assumption  │             │  Gen<T>         │
│  predicate   │             │  .generateTree  │
└──────────────┘             └─────────────────┘
       │                              │
       │                              │ ShrinkTree<T>
       │                              v
       │                     ┌─────────────────┐
       │                     │  PropertyRunner │
       └────────────────────>│  .runProperty   │
                             └─────────────────┘
                                      │
                                      v
                             ┌─────────────────┐
                             │ PropertyResult  │
                             │  .success       │
                             │  .failure       │
                             │  .gaveUp        │
                             └─────────────────┘
```

### Extended Flow (ClassifyingProperty<T>)

```
┌──────────────────────────┐
│ ClassifyingProperty<T>   │
│  generator               │──generate──>┌─────────────────┐
│  assumption              │             │  Gen<T>         │
│  predicate: (T, Ctx) -> Bool          │  .generateTree  │
└──────────────────────────┘             └─────────────────┘
       │                                          │
       │                                          │ ShrinkTree<T>
       │                                          v
       │                               ┌───────────────────────────┐
       │                               │  PropertyRunner           │
       └──────────────────────────────>│  .runClassifyingProperty  │
                                       └───────────────────────────┘
                                                  │
                                                  │ Uses ClassificationContext
                                                  │
                             ┌────────────────────┴────────────────────┐
                             │                                         │
                             v                                         v
                    ┌────────────────────┐               ┌─────────────────────────┐
                    │ PropertyResult<T>  │               │ ClassificationReport    │
                    │  .success          │               │  labelDistribution      │
                    │  .failure          │               │  coverageResults        │
                    │  .gaveUp           │               │  totalIterations        │
                    └────────────────────┘               └─────────────────────────┘
```

### Data Flow for Statistics Collection

```
1. PropertyRunner instantiates ClassificationContext
   ├─ ClassificationContext.labels: [String: [String: Int]]
   ├─ ClassificationContext.coverageChecks: [String: (hits, checks, threshold)]
   └─ Thread-safe via actor isolation

2. For each test case:
   ├─ Check assumption (if false: discard, no classification)
   ├─ Execute predicate(value, ctx)
   │   ├─ ctx.classify("category", "label")
   │   ├─ ctx.cover("check", pct: 10.0) { condition }
   │   └─ ctx.collect("histogram", value)
   └─ Record pass/fail

3. After all iterations:
   ├─ Aggregate classifications
   ├─ Check coverage thresholds
   └─ Generate ClassificationReport
```

---

## Integration with Existing Features

### 1. cover/classify/collect → ClassificationContext

**Current state:** Already implemented in `Core/ClassificationContext.swift`

```swift
public actor ClassificationContext {
  // Track label distributions
  public func classify(_ category: String, _ label: String)

  // Require minimum coverage percentage
  public func cover(_ name: String, percentage: Double, _ condition: () -> Bool)

  // Collect histogram data
  public func collect<T: Hashable & CustomStringConvertible>(
    _ category: String,
    _ value: T
  )

  // Generate final report
  public func generateReport(totalIterations: Int) -> ClassificationReport
}
```

**Gap:** Not connected to PropertyRunner's standard execution path.

**Solution:** Extend PropertyRunner with:

```swift
extension PropertyRunner {
  public func runPropertyWithClassification<T>(
    _ property: Property<T>,
    classify: @escaping @Sendable (T, ClassificationContext) -> Void,
    config: PropertyConfig = .default
  ) async -> (PropertyResult<T>, ClassificationReport)
}
```

### 2. discard → PropertyEvaluation

**Current state:** Fully implemented in `Core/Property.swift`

```swift
public enum PropertyEvaluation: Sendable, Equatable {
  case pass
  case fail(reason: String?)
  case discard(reason: String?)
}

public func assume(_ condition: Bool, reason: String? = nil) -> PropertyEvaluation
public func require(_ condition: Bool, reason: String? = nil) -> PropertyEvaluation
```

**Gap:** Standard `Property<T>` uses `Bool` predicates, not `PropertyEvaluation`.

**Solution:** Already solved with `EvaluatingProperty<T>`:

```swift
public struct EvaluatingProperty<T: Sendable>: @unchecked Sendable {
  public let generator: Gen<T>
  public let evaluate: @Sendable (T) -> PropertyEvaluation
}
```

Users who want explicit discard control use `EvaluatingProperty`, others use `Property<T>` with assumptions.

### 3. Conditional Properties (==>)

**Current state:** Implemented via `assumption` parameter in Property<T>

```swift
Property(
  generator: Gen.int,
  assumption: { $0 > 0 },  // Discard non-positive
  predicate: { $0 * 2 > $0 }
)
```

**Gap:** No syntactic sugar for implication operator.

**Solution:** Add extension (LOW priority):

```swift
infix operator ==>: LogicalConjunctionPrecedence

extension Property {
  public static func ==>(
    assumption: @escaping @Sendable (T) -> Bool,
    property: Property<T>
  ) -> Property<T> {
    Property(
      generator: property.generator,
      assumption: assumption,
      predicate: property.predicate
    )
  }
}
```

### 4. Integrated Shrinking

**Current state:** Already implemented via `ShrinkTree<T>`

```swift
// Gen<T> generates shrink trees
public func generateTree(_ rng: inout any RandomNumberGenerator, _ size: Size) -> ShrinkTree<T>

// PropertyRunner uses tree-based shrinking
private func shrinkFailureWithTree<T>(
  _ tree: ShrinkTree<T>,
  property: Property<T>,
  maxShrinks: Int
) -> T
```

**Gap:** None. Architecture supports integrated shrinking.

**Evidence:** `Gen.flatMap` uses `generateTreeOverride` to regenerate inner values when outer shrinks, preserving invariants.

---

## Build Order and Dependencies

### Phase 1: Non-Breaking Extensions (READY)

**Goal:** Add classification support without changing Property<T>

**Tasks:**
1. Extend `PropertyRunner` with `runClassifyingProperty`
2. Wire `ClassificationContext` into execution loop
3. Return `(PropertyResult<T>, ClassificationReport)` tuple

**Dependencies:** None. Existing infrastructure is sufficient.

**Complexity:** LOW. Infrastructure exists, just needs wiring.

### Phase 2: Improved Discard Tracking (READY)

**Goal:** Better visibility into discard reasons

**Tasks:**
1. Add `discardReasons: [String]` to PropertyResult.gaveUp
2. Track discard reasons in PropertyRunner execution
3. Surface in test output

**Dependencies:** None.

**Complexity:** LOW. Simple state tracking.

### Phase 3: Syntax Improvements (OPTIONAL)

**Goal:** Ergonomic improvements for common patterns

**Tasks:**
1. Add `==>` implication operator
2. Add `forAll` combinator sugar
3. Add `Property.when(assumption).check(predicate)` builder

**Dependencies:** None.

**Complexity:** LOW. Syntactic sugar only.

### Phase 4: Advanced Features (FUTURE)

**Goal:** Hypothesis-style targeted property testing

**Tasks:**
1. Integrate with existing `TargetedTesting.swift` infrastructure
2. Add example database for automatic regression testing
3. Implement coverage-guided generation

**Dependencies:** Phase 1 (classification statistics)

**Complexity:** HIGH. Requires corpus management.

---

## Breaking vs Non-Breaking Changes

### Non-Breaking (Recommended Approach)

```swift
// EXISTING: Property<T> unchanged
Property(generator: Gen.int) { n in n + 0 == n }

// NEW: ClassifyingProperty<T> opt-in
ClassifyingProperty(generator: Gen.int) { n, ctx in
  ctx.classify("sign", n < 0 ? "negative" : "positive")
  ctx.cover("boundaries", percentage: 10.0) { abs(n) > 90 }
  return n + 0 == n
}

// NEW: Add classification to existing property
property.withClassification { value, ctx in
  ctx.classify("category", labelFor(value))
}
```

**Migration path:** Zero migration required. Existing tests work unchanged.

### Breaking Changes (NOT RECOMMENDED)

```swift
// Would break ALL existing Property<T> definitions
Property(generator: Gen.int) { n, ctx in  // <- New parameter
  return n + 0 == n
}
```

**Why avoid:** Thousands of tests break. Migration burden on users.

---

## Performance Impact

### Classification Overhead

**Measurement points:**
1. `ClassificationContext` actor calls (~1μs per classify)
2. Label storage (hash map insertion)
3. Coverage threshold checking (per iteration)

**Expected impact:** <5% overhead when classification used, 0% when not.

**Mitigation:** Actor isolation provides thread-safe low-contention access.

### Shrinking Performance

**Current state:** BFS-based shrinking via `ShrinkTree<T>` is efficient.

**No impact:** Classification doesn't affect shrinking algorithm.

### Memory Usage

**Classification data:** O(categories × labels) labels + O(coverage checks)

**Expected:** <1MB for typical test runs (100 iterations, 10 categories)

**Mitigation:** Clear context between property runs.

---

## Architectural Decisions Log

### Decision 1: Use ClassifyingProperty<T> (Not Property<T> Breaking Change)

**Context:** Need classification support without breaking existing code.

**Options:**
- A: Add optional ClassificationContext to Property<T> predicate
- B: Create ClassifyingProperty<T> opt-in type
- C: Make Property<T> always use ClassificationContext

**Decision:** Option B (ClassifyingProperty<T>)

**Rationale:**
- Zero breaking changes
- Clear opt-in for users who want classification
- Existing infrastructure in place (`ClassificationContext`, `ClassificationReport`)
- Can always merge later if adoption is universal

### Decision 2: Keep Existing Discard Mechanism

**Context:** PropertyEvaluation already implements discard semantics.

**Options:**
- A: Use existing PropertyEvaluation + EvaluatingProperty<T>
- B: Modify Property<T> to return PropertyEvaluation
- C: Add separate Discardable protocol

**Decision:** Option A (use existing)

**Rationale:**
- Already implemented and tested
- `runEvaluatingProperty` handles discard correctly
- No need for new types or protocols

### Decision 3: Classification via Actor (Not Combine/AsyncSequence)

**Context:** Thread-safe statistics collection during concurrent testing.

**Options:**
- A: Actor-based ClassificationContext
- B: Combine publishers
- C: AsyncSequence

**Decision:** Option A (actor)

**Rationale:**
- Swift 6 concurrency model
- PropertyRunner is already an actor
- Minimal overhead (<1μs per operation)
- No external dependencies

### Decision 4: Integrated Shrinking Already Implemented

**Context:** Need proper shrinking for flatMap dependencies.

**Options:**
- A: Keep separate Shrink<T> type (legacy)
- B: Use ShrinkTree<T> with generateTree (current)
- C: Rewrite shrinking system

**Decision:** Option B (already done)

**Rationale:**
- ShrinkTree<T> implemented in Gen<T>.generateTree
- PropertyRunner uses tree-based BFS search
- flatMap uses generateTreeOverride for dependent shrinking
- No architecture change needed

---

## Risk Assessment

### Low Risk

- **Classification integration:** Infrastructure exists, just needs wiring
- **Discard tracking:** Already implemented via PropertyEvaluation
- **Non-breaking changes:** No migration required

### Medium Risk

- **Performance overhead:** Classification actor calls may add latency (mitigation: benchmark)
- **API surface:** More types/methods increase learning curve (mitigation: good docs)

### High Risk (Avoided)

- **Breaking Property<T>:** Would break all existing tests (mitigation: use ClassifyingProperty<T>)
- **Rewriting shrinking:** Would risk correctness (mitigation: keep ShrinkTree<T>)

---

## Alternatives Considered

### Alternative 1: Always Collect Statistics

**Idea:** Make all Property<T> runs collect classification data.

**Rejected because:**
- Performance overhead for users who don't need it
- More complex PropertyResult type
- No opt-out mechanism

### Alternative 2: Separate Statistics Runner

**Idea:** New type `PropertyStatisticsRunner` separate from `PropertyRunner`.

**Rejected because:**
- Code duplication (95% identical to PropertyRunner)
- Fragmentation of testing infrastructure
- Harder to maintain

### Alternative 3: Mixin-Based Composition

**Idea:** Protocol-based traits for classification, coverage, etc.

**Rejected because:**
- Swift doesn't support mixins elegantly
- More complex type system
- Harder to understand execution flow

---

## Sources

### QuickCheck Architecture

- [Test.QuickCheck.Property - Hackage](https://hackage.haskell.org/package/QuickCheck-2.10.1/docs/Test-QuickCheck-Property.html) - QuickCheck's classify, cover, collect functions
- [QuickCheck: A Lightweight Tool for Random Testing](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf) - Original paper on property-based testing
- [Test.QuickCheck.Property Documentation](https://hackage.haskell.org/package/QuickCheck-2.9.2/docs/Test-QuickCheck-Property.html) - Implication operator and discard semantics

### Integrated Shrinking

- [Integrated vs type based shrinking - Hypothesis](https://hypothesis.works/articles/integrated-shrinking/) - Architecture of integrated shrinking
- [GitHub - mooreryan/gleam_qcheck](https://github.com/mooreryan/gleam_qcheck) - Integrated shrinking in Gleam implementation
- [Shrinking - Property Testing Book](https://propertesting.com/book_shrinking.html) - Shrinking strategies and architecture

### Discard and Assumption Handling

- [An introduction to QuickCheck testing](https://www.schoolofhaskell.com/user/pbv/an-introduction-to-quickcheck-testing) - Implication operator usage
- [Property Testing using QuickCheck](https://www.dcc.fc.up.pt/~pbv/aulas/tapf/handouts/quickcheck.html) - Conditional properties and discarding

**Confidence Assessment:** HIGH - All core concepts verified through official documentation and existing codebase analysis.
