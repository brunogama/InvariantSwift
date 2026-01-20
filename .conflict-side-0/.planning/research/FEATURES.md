# Feature Landscape: Property-Based Testing Frameworks

**Domain:** Property-based testing frameworks
**Researched:** 2026-01-23
**Focus:** InvariantSwift v2.0 feature parity with QuickCheck/Hypothesis
**Target users:** Swift developers without functional programming background

---

## Executive Summary

Property-based testing frameworks have evolved from academic functional programming tools (QuickCheck 2000) to mainstream testing infrastructure (Hypothesis, fast-check, jqwik). InvariantSwift v2.0 aims for QuickCheck feature parity while prioritizing accessibility for Swift developers unfamiliar with FP concepts.

**Key finding:** The gap between "table stakes" and "advanced" has narrowed. What was cutting-edge in 2015 (integrated shrinking, stateful testing, example database) is now expected baseline functionality.

---

## Table Stakes Features

Features users expect. Missing = users leave for SwiftCheck/Hypothesis.

### 1. Random Data Generation
**What:** Composable generators for standard types with size control
**Why expected:** Core primitive of property-based testing
**Complexity:** Medium (higher-kinded types, size parameter threading)
**InvariantSwift status:** ✅ IMPLEMENTED (Gen<T>, all standard library types)
**Accessibility impact:** HIGH - Swift developers understand this (similar to Codable)

| Feature | QuickCheck | Hypothesis | fast-check | InvariantSwift |
|---------|-----------|-----------|-----------|----------------|
| Primitives (Int, String, Bool) | ✅ | ✅ | ✅ | ✅ |
| Collections (Array, Set, Dict) | ✅ | ✅ | ✅ | ✅ |
| Combinators (map, flatMap, filter) | ✅ | ✅ | ✅ | ✅ |
| Custom generators | ✅ | ✅ | ✅ | ✅ |
| Size control | ✅ | ✅ | ✅ | ✅ |

**Sources:**
- [QuickCheck Manual](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html)
- [Hypothesis Documentation](https://hypothesis.readthedocs.io/en/latest/)
- [fast-check Documentation](https://fast-check.dev/)

---

### 2. Automatic Shrinking
**What:** Minimize failing examples to simplest counterexample
**Why expected:** Without shrinking, property tests are unusable (giant random failures)
**Complexity:** High (requires shrink trees or integrated approach)
**InvariantSwift status:** ✅ IMPLEMENTED (integrated shrinking via replay)
**Accessibility impact:** HIGH - "It just works" makes PBT usable

| Approach | Frameworks | Pros | Cons |
|----------|-----------|------|------|
| Type-based (explicit Shrink<T>) | SwiftCheck, QuickCheck < 2.14 | Composable | Doesn't preserve invariants |
| Integrated (replay RNG choices) | Hypothesis, InvariantSwift | Preserves invariants | Harder to implement |
| Hybrid | fast-check | Best of both | Complex |

**Key insight:** Integrated shrinking is now table stakes (not advanced). Users expect shrinking to "just work" without manual Shrink instances.

**Sources:**
- [Hypothesis: Integrated vs Type-based Shrinking](https://hypothesis.works/articles/integrated-shrinking/)
- [fast-check Shrinking Guide](https://fast-check.dev/docs/core-blocks/arbitraries/shrinking/)

---

### 3. Test Case Classification & Coverage
**What:** Label test cases, verify distribution, enforce coverage requirements
**Why expected:** Without classification, you don't know what you're testing
**Complexity:** Low (data collection) to Medium (coverage enforcement)
**InvariantSwift status:** ⚠️ PARTIAL (needs `cover`, `classify`, `collect` equivalents)
**Accessibility impact:** HIGH - Shows users "is my test any good?"

**QuickCheck API (Haskell):**
```haskell
-- label: Attach label for reporting
label :: Testable prop => String -> prop -> Property

-- collect: Label with value (auto-converts to string)
collect :: (Show a, Testable prop) => a -> prop -> Property

-- classify: Conditional labeling
classify :: Testable prop => Bool -> String -> prop -> Property

-- cover: Enforce minimum coverage (FAILS if not met)
cover :: Testable prop => Bool -> Int -> String -> prop -> Property
```

**Hypothesis API (Python):**
```python
from hypothesis import event, target

@given(st.integers())
def test_with_classification(x):
    event(f"x is positive: {x > 0}")  # Collect statistics
    target(abs(x))  # Optimize towards maximizing this value
```

**InvariantSwift v2.0 needs:**
- `Property.classify(condition, label)` - Statistics reporting
- `Property.cover(condition, percent, label)` - Enforce coverage
- `Property.collect(value)` - Auto-label by value
- Statistics output in test reports

**Sources:**
- [QuickCheck Property Functions](https://hackage.haskell.org/package/QuickCheck-2.10.1/docs/Test-QuickCheck-Property.html)
- [Hypothesis event() Documentation](https://hypothesis.readthedocs.io/en/latest/details.html)

---

### 4. Conditional Properties (Discard)
**What:** Express preconditions; discard invalid test cases
**Why expected:** Real-world properties have preconditions
**Complexity:** Low (implementation) to Medium (discard budget management)
**InvariantSwift status:** ✅ IMPLEMENTED (via `filter`, needs `==>` syntax)
**Accessibility impact:** MEDIUM - Familiar to Swift developers (guard/if let)

**QuickCheck syntax:**
```haskell
prop_sorted xs =
    not (null xs) ==>
    head (sort xs) == minimum xs
```

**Hypothesis syntax:**
```python
from hypothesis import assume

@given(st.lists(st.integers()))
def test_sorted(xs):
    assume(len(xs) > 0)  # Discard empty lists
    assert sorted(xs)[0] == min(xs)
```

**InvariantSwift needs:**
- `Property.requires(_ condition: Bool)` or `==>` operator
- Smart discard budget (Hypothesis: 10x iterations, then fail)
- Warning when too many discards (suggests generator issue)

---

### 5. Reproducibility (Seeds)
**What:** Re-run tests with same random seed for debugging
**Why expected:** Debugging random failures requires determinism
**Complexity:** Low (pass seed to RNG)
**InvariantSwift status:** ✅ IMPLEMENTED (`@PropertyTest(seed:)`, `@Reproduce`)
**Accessibility impact:** HIGH - Critical for debugging workflow

**All frameworks support:**
- Fixed seed for deterministic runs
- Seed printed on failure
- Seed in test configuration

**InvariantSwift advantage:** `@Reproduce` macro goes further than competitors (includes shrink path + serialized input).

**Sources:**
- [fast-check Seed Documentation](https://fast-check.dev/docs/core-blocks/runners/#seed)
- ISP-0004 (InvariantSwift example database proposal)

---

### 6. Configurable Iteration Count
**What:** Control number of test cases generated (default ~100)
**Why expected:** Trade speed vs coverage; CI needs faster runs
**Complexity:** Low
**InvariantSwift status:** ✅ IMPLEMENTED (`@PropertyTest(iterations:)`)
**Accessibility impact:** LOW - Standard testing concept

---

### 7. Test Framework Integration
**What:** Works with existing test runners (XCTest, Swift Testing)
**Why expected:** Friction kills adoption; must fit existing workflows
**Complexity:** Low (but platform-specific)
**InvariantSwift status:** ✅ IMPLEMENTED (Swift Testing via `@Test`)
**Accessibility impact:** CRITICAL - No adoption without this

**fast-check advantage:** Works with any JS test runner (Jest, Mocha, Vitest) without special integration.

---

## Differentiators

Features that set InvariantSwift apart. Not expected, but highly valued.

### 1. Stateful Testing / State Machine DSL
**What:** Generate sequences of operations; verify invariants hold
**Why valuable:** Most real systems are stateful (DBs, UIs, APIs)
**Complexity:** High (operation generation, precondition tracking)
**InvariantSwift status:** ✅ IMPLEMENTED (`@RuleBasedTest` macro, ISP-0003)
**Accessibility impact:** HIGH - DSL makes stateful testing approachable

**Comparison:**

| Framework | Approach | Accessibility |
|-----------|----------|--------------|
| QuickCheck | Manual command generation | LOW - requires FP experience |
| Hypothesis | `@rule` decorator DSL | HIGH - declarative |
| fast-check | `fc.commands()` API | MEDIUM - imperative |
| jqwik | Actions API | MEDIUM - Java verbosity |
| **InvariantSwift** | `@RuleBasedTest` macro | HIGH - Swift-native DSL |

**Example (Hypothesis-style):**
```swift
@RuleBasedTest
struct DatabaseSpec {
    var model: [String: Data] = [:]
    let database = Database()

    @Bundle var knownKeys: [String]

    @Rule(into: \.knownKeys)
    func generateKey(@Gen(.alphanumeric) key: String) -> String { key }

    @Rule
    @Precondition { !$0.knownKeys.isEmpty }
    func write(key: KeyRef, value: Data) {
        database.write(key: key.value, value: value)
        model[key.value] = value
    }

    @Invariant
    func modelMatches() -> Bool {
        model.allSatisfy { database.read(key: $0.key) == $0.value }
    }
}
```

**Why this differentiates:** Most Swift developers struggle with stateful testing. Macro DSL makes it declarative and type-safe.

**Sources:**
- [Hypothesis Stateful Testing](https://hypothesis.readthedocs.io/en/latest/stateful.html)
- [jqwik Stateful Testing](https://jqwik.net/docs/current/user-guide.html)
- ISP-0003 (InvariantSwift rule-based testing proposal)

---

### 2. Example Database (Failure Persistence)
**What:** Auto-save failing examples; re-run on next test; share across team
**Why valuable:** CI flakiness, team collaboration, regression prevention
**Complexity:** Medium (SQLite + serialization)
**InvariantSwift status:** ✅ IMPLEMENTED (ISP-0004, `.invariant/examples.db`)
**Accessibility impact:** HIGH - Eliminates "flaky test" perception

**Comparison:**

| Framework | Persistence | Git-Friendly | Sharing |
|-----------|-------------|--------------|---------|
| Hypothesis | ✅ SQLite | ✅ Directory mode | ✅ Seed + path |
| fast-check | ✅ File | ❌ | ✅ Seed + path |
| SwiftCheck | ❌ | ❌ | ❌ |
| **InvariantSwift** | ✅ SQLite | ✅ Directory mode | ✅ `@Reproduce` macro |

**InvariantSwift advantage:**
- `@Reproduce(seed:, path:, input:)` macro for one-line reproduction
- Directory mode for version control
- Auto-check saved failures before random generation

**Sources:**
- [Hypothesis Example Database](https://hypothesis.readthedocs.io/en/latest/database.html)
- ISP-0004 (InvariantSwift example database proposal)

---

### 3. Macros for Reduced Boilerplate
**What:** `@PropertyTest`, `@Arbitrary`, `@RuleBasedTest` macros generate testing code
**Why valuable:** Less boilerplate = faster adoption
**Complexity:** Very High (Swift macros + type analysis)
**InvariantSwift status:** ✅ IMPLEMENTED (Swift 5.9+ macros)
**Accessibility impact:** CRITICAL - Makes PBT feel like regular unit testing

**Example:**
```swift
// Without macro (verbose)
@Test
func testSorting() {
    let property = Property(generator: Gen<[Int]>.array(Gen<Int>.int)) { array in
        let sorted = array.sorted()
        return sorted.count == array.count
    }
    await checkProperty(property)
}

// With macro (natural)
@PropertyTest
func testSorting(array: [Int]) {
    let sorted = array.sorted()
    #expect(sorted.count == array.count)
}
```

**Why this differentiates:** No other Swift PBT framework has macro support. Huge DX improvement.

---

### 4. Ghostwriter (Auto-Test Generation)
**What:** Analyze code, suggest property tests automatically
**Why valuable:** Lowers barrier to entry; teaches users what to test
**Complexity:** Very High (static analysis + code generation)
**InvariantSwift status:** ✅ IMPLEMENTED (ISP-0009, Ghostwriter plugin)
**Accessibility impact:** HIGH - Helps users who don't know what properties to write

**Example:**
```bash
$ swift package ghostwrite MyModule/Calculator.swift

Generated test suggestions:

// Inverse property for add/subtract
@PropertyTest
func testAddSubtractInverse(a: Int, b: Int) {
    let calc = Calculator()
    let sum = calc.add(a, b)
    #expect(calc.subtract(sum, b) == a)
}

// Commutativity of multiplication
@PropertyTest
func testMultiplyCommutative(a: Int, b: Int) {
    let calc = Calculator()
    #expect(calc.multiply(a, b) == calc.multiply(b, a))
}
```

**Comparison:** Only Hypothesis has Ghostwriter. InvariantSwift ports this to Swift.

**Sources:**
- [Hypothesis Ghostwriter](https://hypothesis.readthedocs.io/en/latest/ghostwriter.html)
- ISP-0009 (InvariantSwift Ghostwriter proposal)

---

### 5. Faker Integration (Domain Generators)
**What:** Realistic data generators (names, emails, addresses, etc.)
**Why valuable:** Testing with realistic data finds different bugs than random data
**Complexity:** Medium (data corpus + localization)
**InvariantSwift status:** ✅ IMPLEMENTED (ISP-0010, Faker generators)
**Accessibility impact:** MEDIUM - Useful for app developers

**Example:**
```swift
@PropertyTest
func testUserProfile(
    @Gen(.name) name: String,
    @Gen(.email) email: String,
    @Gen(.age(18...100)) age: Int
) {
    let profile = UserProfile(name: name, email: email, age: age)
    #expect(profile.isValid)
}
```

**Why this differentiates:** Bridges gap between unit testing (specific examples) and property testing (random data).

---

### 6. Targeted Property Testing (Coverage-Guided)
**What:** Use feedback (code coverage, metrics) to guide input generation
**Why valuable:** Explores state space more efficiently than pure random
**Complexity:** Very High (requires instrumentation)
**InvariantSwift status:** ⚠️ PARTIAL (ISP-0008, macOS only via LLVM coverage)
**Accessibility impact:** LOW - Advanced users only

**Hypothesis feature:** `target()` function optimizes towards maximizing a metric
```python
@given(st.integers())
def test_find_bug(x):
    target(abs(x - 1000))  # Guides towards x=1000
    assert buggy_function(x)  # Bug only triggers near 1000
```

**InvariantSwift status:** Needs more work. Complex to implement cross-platform.

**Sources:**
- [Hypothesis Targeted Testing](https://hypothesis.readthedocs.io/en/latest/details.html)
- ISP-0008 (InvariantSwift targeted testing proposal)

---

## QuickCheck Feature Mapping

Comprehensive mapping of QuickCheck features to InvariantSwift v2.0.

| QuickCheck Feature | Category | Priority | InvariantSwift Status | Notes |
|-------------------|----------|----------|----------------------|-------|
| **Core Testing** |
| `forAll` (explicit generator) | Table stakes | P0 | ✅ `Property(generator:)` | Core API |
| `==>` (implication/discard) | Table stakes | P0 | ⚠️ Need syntax sugar | `filter` exists, needs `==>` |
| Automatic shrinking | Table stakes | P0 | ✅ Integrated shrinking | Better than QC |
| Seed control | Table stakes | P0 | ✅ `@PropertyTest(seed:)` | |
| Iteration count | Table stakes | P0 | ✅ `@PropertyTest(iterations:)` | |
| **Classification** |
| `label` | Table stakes | P1 | ❌ TODO v2.0 | |
| `collect` | Table stakes | P1 | ❌ TODO v2.0 | |
| `classify` | Table stakes | P1 | ❌ TODO v2.0 | |
| `cover` | Table stakes | P1 | ❌ TODO v2.0 | Coverage enforcement |
| `checkCoverage` | Table stakes | P1 | ❌ TODO v2.0 | |
| **Generators** |
| `Gen.choose` | Table stakes | P0 | ✅ `.int(in:)` | |
| `Gen.oneof` | Table stakes | P0 | ✅ `.oneOf` | |
| `Gen.frequency` | Table stakes | P0 | ✅ `.frequency` | |
| `Gen.elements` | Table stakes | P0 | ✅ `.element(of:)` | |
| `Gen.listOf` | Table stakes | P0 | ✅ `.array` | |
| `Gen.sized` | Table stakes | P0 | ✅ Via `Size` param | |
| `Gen.resize` | Table stakes | P1 | ⚠️ Manual via Gen | |
| **Type Classes** |
| `Arbitrary` typeclass | Table stakes | P0 | ✅ `Generatable` + `@Arbitrary` | |
| `CoArbitrary` | Advanced | P3 | ❌ Low priority | Functional generators |
| **Combinators** |
| `Gen.map` | Table stakes | P0 | ✅ | |
| `Gen.flatMap` (bind) | Table stakes | P0 | ✅ `.flatMap` | |
| `Gen.ap` (applicative) | Advanced | P3 | ⚠️ Via zip | Exists but not idiomatic |
| **Modifiers** |
| `Positive<T>` | Advanced | P2 | ⚠️ Via `.int(in: 1...)` | |
| `NonEmpty<T>` | Advanced | P2 | ⚠️ Via `.array(count: 1...)` | |
| `Blind<T>` (no Show) | Advanced | P3 | ❌ N/A | Swift has CustomDebugStringConvertible |
| **Advanced** |
| Stateful testing | Differentiator | P1 | ✅ `@RuleBasedTest` | Better than QC |
| Example database | Differentiator | P1 | ✅ ISP-0004 | QC doesn't have this |
| Parallel testing | Advanced | P2 | ⚠️ Via Swift Concurrency | |
| Conjunctions (`(.&.)`) | Advanced | P2 | ⚠️ Manual via multiple `#expect` | |

**Priority levels:**
- **P0:** Must have for v2.0 (table stakes)
- **P1:** Should have for v2.0 (high value)
- **P2:** Nice to have (post-v2.0)
- **P3:** Low priority (research)

---

## Anti-Features

Features to deliberately NOT build (they hurt accessibility).

### 1. CoArbitrary / Function Generators
**What:** Generate random functions `(A) -> B`
**Why avoid:**
- Requires advanced FP concepts (higher-kinded types)
- Debugging is nightmare (how do you print a function?)
- Rarely used even in Haskell community
- Swift's type system makes this awkward
**Instead:** Provide concrete function generators for common cases (e.g., endomorphisms)

**Sources:**
- [QuickCheck CoArbitrary](https://hackage.haskell.org/package/QuickCheck-2.10.1/docs/Test-QuickCheck-Arbitrary.html#t:CoArbitrary)

---

### 2. Overly Mathematical API
**What:** Terms like "monoid", "semigroup", "applicative functor"
**Why avoid:**
- Alienates Swift developers unfamiliar with FP
- Swift community values pragmatism over theory
- Same functionality can be expressed with familiar terms
**Instead:** Use Swift-native terminology (map, flatMap, combine)

**Example of BAD API:**
```swift
// ❌ Too mathematical
let gen = Gen.applicative.ap(Gen.pure(+), Gen.int, Gen.int)

// ✅ Clear to Swift devs
let gen = Gen.zip(Gen<Int>.int, Gen<Int>.int).map(+)
```

---

### 3. Separate Shrink Type Class
**What:** Manual `Shrink<T>` instances alongside `Arbitrary<T>`
**Why avoid:**
- Type-based shrinking doesn't preserve invariants (huge gotcha)
- Integrated shrinking is superior (Hypothesis proved this)
- Extra boilerplate hurts adoption
**Instead:** Integrated shrinking by default, manual shrink only for advanced users

**Sources:**
- [Hypothesis: Why Integrated Shrinking is Better](https://hypothesis.works/articles/integrated-shrinking/)

---

### 4. Overly Generic Modifiers
**What:** Types like `Positive<T>`, `NonEmpty<T>`, `InRange<T>`
**Why avoid:**
- Harder to debug (wrapped types in errors)
- Less readable than generator combinators
- Swift's type system makes this verbose
**Instead:** Generator combinators: `.int(in: 1...)`, `.array(count: 1...)`

**Example:**
```swift
// ❌ Verbose with modifiers
@PropertyTest
func test(x: Positive<NonZero<Int>>) { ... }

// ✅ Clear with generator syntax
@PropertyTest
func test(@Gen(.int(in: 1...)) x: Int) { ... }
```

---

### 5. CLI-Only Interface
**What:** Requiring terminal commands to run property tests
**Why avoid:**
- Xcode is primary Swift IDE
- Developers expect Xcode test navigator to work
- CI/CD integration must be seamless
**Instead:** First-class Swift Testing integration with `@Test` macro

---

## Feature Dependencies

```mermaid
graph TD
    A[Random Generation] --> B[Shrinking]
    A --> C[Conditional Properties]
    A --> D[Classification]

    B --> E[Example Database]
    D --> F[Coverage Enforcement]

    A --> G[Stateful Testing]
    B --> G
    C --> G

    G --> H[Rule-Based DSL]

    A --> I[Targeted Testing]
    D --> I

    J[Macros] --> K[@PropertyTest]
    J --> H
    J --> L[@Arbitrary]

    M[Faker] --> A
```

**Critical path for MVP:**
1. Random Generation (DONE)
2. Shrinking (DONE)
3. Classification (TODO - blocks Coverage)
4. Coverage Enforcement (TODO)
5. Conditional Properties sugar (TODO - `==>`)

**Post-MVP:**
6. Enhanced Targeted Testing (platform limitations)
7. Advanced modifiers (low priority)

---

## MVP Recommendation

For InvariantSwift v2.0, prioritize:

### Must Have (P0)
1. ✅ Random generation (DONE)
2. ✅ Integrated shrinking (DONE)
3. ✅ Seed control (DONE)
4. ✅ Swift Testing integration (DONE)
5. ❌ **Classification API** (`classify`, `collect`, `label`) - CRITICAL GAP
6. ❌ **Coverage enforcement** (`cover`) - CRITICAL GAP
7. ⚠️ **Conditional properties** (`==>` syntax) - NEEDS SUGAR

### Should Have (P1)
8. ✅ Stateful testing (`@RuleBasedTest`) - DONE
9. ✅ Example database (ISP-0004) - DONE
10. ✅ Ghostwriter (ISP-0009) - DONE
11. ✅ Faker integration (ISP-0010) - DONE
12. ❌ **Statistics reporting** - TODO (renders classification useful)

### Nice to Have (P2)
13. Enhanced error messages (custom Shrink hints)
14. Parallel property execution
15. Targeted testing improvements (cross-platform)

### Defer (P3)
16. CoArbitrary (function generators)
17. Applicative combinators (too FP)
18. Advanced modifiers (verbose in Swift)

---

## Complexity Assessment

| Feature | Implementation Complexity | Maintenance Burden | User Complexity |
|---------|--------------------------|-------------------|----------------|
| **Table Stakes** |
| Random generation | Medium | Low | Low |
| Shrinking | Very High | Medium | Very Low (invisible) |
| Classification | Low | Low | Low |
| Coverage | Medium | Low | Medium |
| Conditional (`==>`) | Low | Low | Low |
| Seeds | Low | Low | Low |
| **Differentiators** |
| Stateful testing | Very High | High | Medium (DSL helps) |
| Example database | Medium | Medium | Low (automatic) |
| Macros | Very High | High | Very Low (just works) |
| Ghostwriter | Very High | Very High | Low (CLI tool) |
| Faker | Medium | Medium | Low |
| Targeted testing | Very High | Very High | Medium |

**Takeaway:**
- Classification/Coverage are LOW complexity, HIGH value - do these first
- Stateful testing is HIGH complexity but DONE - huge win
- Targeted testing is HIGH complexity, MEDIUM value - improve incrementally

---

## Accessibility Impact Analysis

**Question:** Will non-FP Swift developers understand this?

| Feature | FP Concepts Required | Swift-Native Alternative | Accessibility Rating |
|---------|---------------------|-------------------------|---------------------|
| Generators | Functor (map) | Collection.map | ⭐⭐⭐⭐⭐ High |
| flatMap | Monad | Swift flatMap | ⭐⭐⭐⭐ Medium-High |
| `==>` operator | Implication | guard/if let | ⭐⭐⭐ Medium |
| Shrinking | Laziness | Hidden implementation | ⭐⭐⭐⭐⭐ High |
| Stateful testing | State monad | @RuleBasedTest macro | ⭐⭐⭐⭐⭐ High |
| Classification | N/A | Familiar testing concept | ⭐⭐⭐⭐⭐ High |
| CoArbitrary | Higher-kinded types | No alternative | ⭐ Very Low |

**Accessibility Winners:**
1. `@PropertyTest` macro - feels like `@Test`
2. `@RuleBasedTest` - declarative DSL, no monad knowledge needed
3. Integrated shrinking - completely invisible
4. Faker generators - concrete, understandable data

**Accessibility Risks:**
1. `==>` operator - unfamiliar to non-FP devs (but learnable)
2. Generator combinators - "why not just make random data?"
3. Classification - "what's the point?" (needs good docs)

**Mitigation:**
- Excellent documentation with Swift-native examples
- Cookbook recipes for common patterns
- Ghostwriter to teach by example
- Error messages that explain concepts

---

## Competitive Analysis

| Framework | Language | Strengths | Weaknesses | Accessibility |
|-----------|----------|-----------|------------|--------------|
| **QuickCheck** | Haskell | Original, mathematically pure | FP-heavy, old shrinking | ⭐⭐ Low |
| **SwiftCheck** | Swift | Ports QuickCheck | Unmaintained, no macros | ⭐⭐ Low |
| **Hypothesis** | Python | Integrated shrinking, stateful, example DB | Python-only | ⭐⭐⭐⭐⭐ High |
| **fast-check** | JS/TS | Fast, TypeScript support | JS ecosystem only | ⭐⭐⭐⭐ High |
| **jqwik** | Java | JUnit integration, stateful | Maintenance mode, Java verbosity | ⭐⭐⭐ Medium |
| **InvariantSwift** | Swift | Macros, stateful DSL, example DB, Ghostwriter | New, limited resources | ⭐⭐⭐⭐⭐ High |

**InvariantSwift's niche:** Best-in-class accessibility for Swift developers while matching Hypothesis feature parity.

---

## Real-World Impact

### Bugs Found by Feature

| Feature | Bug Type Example | Severity |
|---------|-----------------|----------|
| Random generation | Edge cases (Int.max, empty arrays) | High |
| Shrinking | Minimal reproduction (from 1000 items to 3) | Critical (debugging) |
| Stateful testing | Race conditions, state machine bugs | Critical |
| Classification | Bias in generators, missing edge cases | Medium |
| Coverage | Insufficient testing of error paths | Medium |
| Example database | Regression detection | High |
| Targeted testing | Deep bugs requiring specific sequences | Very High |

**Sources:**
- [Hypothesis: Bugs Found in Production Systems](https://hypothesis.works/)
- [jqwik: Model-Based Testing](https://jqwik.net/property-based-testing.html)

---

## Feature Prioritization Matrix

```
High Value, Low Complexity:
├─ ⭐ Classification (collect, label, classify)
├─ ⭐ Coverage enforcement (cover)
└─ ⭐ Conditional syntax (==>)

High Value, High Complexity:
├─ ✅ Stateful testing (DONE)
├─ ✅ Example database (DONE)
├─ ✅ Macros (DONE)
└─ ⚠️ Targeted testing (incremental improvement)

Low Value, Low Complexity:
├─ Generator modifiers (Positive<T>)
└─ Additional combinators

Low Value, High Complexity:
├─ CoArbitrary
└─ Advanced type-level features
```

**Action:** Focus on top-left quadrant (high value, low complexity) for v2.0.

---

## Sources

### Property-Based Testing Frameworks

- [QuickCheck Official Documentation](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck.html)
- [Jesper Cockx - Introduction to QuickCheck](https://jesper.sikanda.be/posts/quickcheck-intro.html)
- [QuickCheck Manual](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html)
- [Hypothesis Official Documentation](https://hypothesis.readthedocs.io/en/latest/)
- [fast-check Official Documentation](https://fast-check.dev/)
- [SwiftCheck GitHub Repository](https://github.com/typelift/SwiftCheck)
- [jqwik Official Website](https://jqwik.net/)
- [jqwik User Guide](https://jqwik.net/docs/current/user-guide.html)

### Feature-Specific Research

- [Hypothesis: Integrated vs Type-based Shrinking](https://hypothesis.works/articles/integrated-shrinking/)
- [QuickCheck Property Functions](https://hackage.haskell.org/package/QuickCheck-2.10.1/docs/Test-QuickCheck-Property.html)
- [Hypothesis Example Database](https://hypothesis.readthedocs.io/en/latest/database.html)
- [fast-check Seed and Path](https://fast-check.dev/docs/core-blocks/runners/#seed)
- [Hypothesis Stateful Testing](https://hypothesis.readthedocs.io/en/latest/stateful.html)
- [Model-Based Testing with jqwik](https://johanneslink.net/model-based-testing/)

### Framework Comparisons

- [GitHub: PBT Frameworks Comparison](https://github.com/jmid/pbt-frameworks)
- [Property-Based Testing Tools Gist](https://gist.github.com/npryce/4147916)
- [In Praise of Property-Based Testing](https://increment.com/testing/in-praise-of-property-based-testing/)
- [F# for Fun and Profit: Introduction to PBT](https://fsharpforfunandprofit.com/pbt/)

### Academic and Industry

- [QuickCheck: An Automatic Testing Tool for Haskell](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html)
- [Property-Based Testing in Practice (PDF)](https://andrewhead.info/assets/pdf/pbt-in-practice.pdf)
- [Hypothesis Works Articles](https://hypothesis.works/articles/)
- [Docker: Model-Based Testing with Testcontainers and Jqwik](https://www.docker.com/blog/model-based-testing-testcontainers-jqwik/)

---

## Open Questions

1. **Classification API design:** Should we match QuickCheck's function names exactly, or use more Swift-idiomatic names?
   - `classify` vs `categorize`?
   - `collect` vs `track`?
   - `cover` vs `requireCoverage`?

2. **Coverage defaults:** What's the right default minimum coverage percentage?
   - QuickCheck: No default (must specify)
   - Hypothesis: 100% of labeled categories must have at least 1 example
   - Proposal: 1% minimum (just ensure category exists), explicit for higher

3. **Targeted testing priority:** Should we invest heavily in LLVM coverage integration, or accept macOS-only limitation?
   - Alternative: Source-based heuristics (branch counting) for cross-platform
   - Decision: Incremental improvement, don't block v2.0

4. **Faker scope:** How many domain generators are "enough"?
   - Current: Names, emails, addresses, phone numbers
   - Potential: Financial (IBAN, credit cards), Technical (IP addresses, UUIDs)
   - Decision: Start minimal, expand based on user feedback

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|-----------|-------|
| Table stakes features | HIGH | Well-established across all frameworks |
| QuickCheck mapping | HIGH | Official documentation clear |
| Hypothesis features | HIGH | Excellent documentation, active project |
| Accessibility impact | MEDIUM | Based on Swift community experience, not empirical data |
| Competitive positioning | MEDIUM | SwiftCheck unmaintained; no other Swift PBT |
| Complexity estimates | MEDIUM | Based on similar features in Hypothesis/fast-check |

**Verification needed:**
- User testing with Swift developers unfamiliar with PBT
- Performance benchmarks for classification overhead
- Real-world stateful testing case studies
