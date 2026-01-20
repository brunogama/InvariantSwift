# Domain Pitfalls

**Domain:** Property-based testing frameworks (QuickCheck-style)
**Researched:** 2026-01-23

---

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Infinite Loops in Shrinking

**What goes wrong:** Shrink functions that don't guarantee strictly decreasing values cause infinite loops during counterexample minimization. The framework hangs attempting to shrink, never finding a minimal case.

**Why it happens:** Developers implement shrink functions that can return the same value or larger values, violating the "strictly smaller" requirement. This is especially common when shrinking custom types or complex data structures.

**Consequences:**
- Test suite hangs indefinitely during shrinking phase
- Users cannot get minimal counterexamples
- Framework appears broken/unreliable
- CI/CD pipelines timeout

**Prevention:**
```swift
// ❌ BAD: Can return same value
Shrink<Int> { n in [n, n - 1, 0] }  // Returns n!

// ✅ GOOD: Always strictly smaller
Shrink<Int> { n in
  guard n != 0 else { return [] }
  return [n / 2, 0]  // Strictly decreasing
}
```

**Detection:**
- Monitor shrink iteration count (warn if > 10,000 iterations)
- Set hard timeout for shrinking phase (e.g., 30 seconds)
- Log shrink values to detect cycles
- Add unit tests that verify shrink functions terminate
- Check shrink functions return empty array for minimal values

**Phase warning:** Phase 2 (Shrinking improvements) — Must validate all shrinking strategies with termination tests before shipping.

**InvariantSwift specific:** Current code has `ShrinkTree.limitBreadth()` and `limitTotal()` which help, but need comprehensive termination tests for all shrink functions.

---

### Pitfall 2: Recursive Generators Without Size Control

**What goes wrong:** Recursive data structure generators (trees, nested objects) that don't use the size parameter correctly create enormous or infinite structures, causing memory exhaustion and test timeouts.

**Why it happens:** Developers forget to pass size through recursive calls, or don't implement base cases when size reaches zero.

**Consequences:**
- Out of memory crashes
- Test generation takes minutes instead of milliseconds
- Enormous counterexamples (e.g., tree with 10,000 nodes)
- Shrinking becomes impossibly slow

**Prevention:**
```swift
// ❌ BAD: No size control, infinite recursion risk
static func tree() -> Gen<Tree> {
  Gen.oneOf([
    Gen.pure(.leaf(0)),
    Gen.zip(tree(), tree()).map { .node($0, $1) }  // Size not reduced!
  ])
}

// ✅ GOOD: Size-based termination
static func tree() -> Gen<Tree> {
  Gen<Tree> { rng, size in
    guard size > 0 else { return .leaf(Int.random(in: -100...100, using: &rng)) }

    return Gen.oneOf([
      Gen.pure(.leaf(Int.random(in: -100...100, using: &rng))),
      Gen.zip(
        tree().generate(&rng, size / 2),  // Halve size at each level
        tree().generate(&rng, size / 2)
      ).map { .node($0, $1) }
    ]).generate(&rng, size)
  }
}
```

**Detection:**
- Monitor generation time per value (warn if > 1ms)
- Track maximum depth of recursive structures
- Set size limits in PropertyConfig
- Log size parameter usage in recursive generators
- Add property tests that verify generators terminate with size=0

**Phase warning:** Phase 1 (Generator improvements) — All recursive generators must be audited for size control before adding new generator types.

**InvariantSwift specific:** Current `Size` type exists but not all generators use it correctly. Need systematic audit of `Generators/` directory.

---

### Pitfall 3: Missing Generators for Test-Generated Code

**What goes wrong:** Ghostwriter generates property tests for custom types, but those types lack `@Arbitrary` conformance or generator implementations. Generated tests fail to compile.

**Why it happens:** Type extraction identifies public types, but generator existence isn't validated before code generation. Test code assumes generators exist.

**Consequences:**
- Ghostwriter output doesn't compile
- Users lose trust in auto-generation feature
- Manual fixes required for every generated test
- Framework appears half-baked

**Prevention:**
```swift
// Ghostwriter MUST check generator availability before generating tests
func generateTests(for typeInfo: TypeInfo) -> [GeneratedTest] {
  // ✅ Current code has this check (TestGenerator.swift:26-34)
  if !config.supportedArbitraryTypes.isEmpty
    && !config.supportedArbitraryTypes.contains(typeInfo.name) {
    if config.verbose {
      print("⚠️ Skipping \(typeInfo.name): no Arbitrary generator available")
    }
    return []
  }
  // ... generate tests
}

// But need to AUTO-GENERATE missing generators:
// ❌ Current: Skip types without generators
// ✅ Better: Generate @Arbitrary extension automatically
extension MyCustomType {
  static var arbitrary: Gen<MyCustomType> {
    Gen.zip(String.arbitrary, Int.arbitrary).map { name, age in
      MyCustomType(name: name, age: age)
    }
  }
}
```

**Detection:**
- Compile-test all generated code before writing to disk
- Report missing generators to user with actionable fix
- Maintain registry of types with generators
- Provide `--generate-arbitrary` flag to auto-generate missing generators

**Phase warning:** Phase 3 (Ghostwriter fixes) — MUST implement generator existence validation and auto-generation before considering Ghostwriter "fixed".

**InvariantSwift specific:** Ghostwriter currently checks `supportedArbitraryTypes` but doesn't auto-generate. This is the #1 reason Ghostwriter output is broken.

---

### Pitfall 4: Over-Filtering with Assumptions (Discard Explosion)

**What goes wrong:** Property tests use `.filter()` or preconditions to restrict input, but the condition is too strict. Framework discards 95%+ of generated values, making tests slow and less effective.

**Why it happens:** Developers filter generated data instead of designing generators that produce valid inputs directly.

**Consequences:**
- Tests run 10-100x slower than necessary
- Low effective test count (100 attempts → 5 valid tests)
- Framework reports "giving up after X discards"
- Poor test coverage of the valid input space

**Prevention:**
```swift
// ❌ BAD: Filter discards most inputs
let property = Property(generator: Gen.int) { n in
  guard n > 0 && n < 100 && n % 2 == 0 else { return true }  // Discard!
  return isPrime(n) == slowIsPrime(n)
}

// ✅ GOOD: Generate only valid inputs
let property = Property(
  generator: Gen.int(in: 1...50).map { $0 * 2 }  // Only even numbers 2-100
) { n in
  return isPrime(n) == slowIsPrime(n)
}
```

**Detection:**
- Track discard ratio (discards / attempts)
- Warn if discard ratio > 50%
- Fail if discard ratio > 90%
- Report discard statistics after test run
- Suggest generator refactoring when discard rate is high

**Phase warning:** Phase 1 (QuickCheck parity) — Implement `discard` tracking and reporting as part of QuickCheck feature parity.

**InvariantSwift specific:** Need to add `PropertyResult.discards` counter and reporting. Config should have `maxDiscardRatio` setting (default: 10.0 = allow 10x discards before failing).

---

## Moderate Pitfalls

Mistakes that cause delays or technical debt.

### Pitfall 5: FP Terminology Scaring Away Developers

**What goes wrong:** Documentation and examples use functional programming jargon (functor, applicative, monad, Arbitrary, isomorphism, morphism) without explanation. Non-FP developers see this and conclude "this framework isn't for me."

**Why it happens:** Framework authors come from FP background and don't realize terminology is intimidating. QuickCheck's Haskell heritage brings FP vocabulary.

**Consequences:**
- Low adoption by mainstream Swift developers
- Framework perceived as "academic" or "too advanced"
- Developers stick with example-based testing
- Community doesn't grow

**Prevention:**
```swift
// ❌ BAD: FP jargon without context
/// Generator is a functor with applicative and monadic operations.
/// Use `map` for functorial lifting, `zip` for applicative sequencing,
/// and `flatMap` for monadic composition.

// ✅ GOOD: Practical explanation with familiar analogies
/// Generator creates random test values of type T.
/// - `map`: Transform generated values (like Array.map)
/// - `zip`: Combine two generators into a pair (like Array.zip)
/// - `flatMap`: Chain generators based on previous values (like Optional.flatMap)
///
/// Example: Generate users with valid ages
/// ```swift
/// let userGen = Gen.zip(Gen.string, Gen.int(in: 18...100))
///   .map { name, age in User(name: name, age: age) }
/// ```
```

**Prevention strategies:**
- Use "generator" not "arbitrary instance"
- Say "test multiple examples automatically" not "property-based testing finds counterexamples via generative techniques"
- Show XCTest comparison: "Like XCTest, but generates 100 test cases instead of 1"
- Avoid: functor, monad, morphism, isomorphism in public docs
- Use: generator, property, test case, shrinking, counterexample

**Phase warning:** Phase 4 (Documentation) — Full documentation audit to remove/explain FP jargon.

**InvariantSwift specific:** Current docs are relatively accessible, but could improve. ONBOARDING.md mentions "functor laws" and "monad laws" without explanation.

---

### Pitfall 6: Unclear Error Messages

**What goes wrong:** Property test fails with message like "Property failed after 37 tests" without showing the minimal counterexample, property definition, or reproduction command.

**Why it happens:** Framework focuses on finding failures, not on communicating them clearly to developers unfamiliar with PBT.

**Consequences:**
- Developer doesn't understand why test failed
- Can't reproduce failure locally
- Debugging takes 10x longer
- Frustration leads to abandoning framework

**Prevention:**
```swift
// ❌ BAD: Minimal information
"Property failed after 37 tests"

// ✅ GOOD: Actionable error report
"""
❌ Property test failed

Test: testArrayReverse (PropertyTests.swift:42)
Property: array.reversed().reversed() == array

Counterexample (minimal after 15 shrinks):
  array = [Int.min, 0]

Reproduce with:
  swift test --filter testArrayReverse --seed 12345

Original failure:
  array = [Int.min, -5, 0, 3, 7, -2, 8]
"""
```

**Prevention strategies:**
- Include property description in failure
- Show minimal counterexample prominently
- Provide reproduction command with exact seed
- Show shrinking path length (e.g., "minimal after 15 shrinks")
- Link to documentation for property-based testing concepts

**Phase warning:** Phase 2 (Error reporting) — Improve failure messages as part of shrinking improvements.

**InvariantSwift specific:** Current `PrettyPrint.swift` exists but could be enhanced with reproduction commands and seed reporting.

---

### Pitfall 7: No Examples in Documentation

**What goes wrong:** Documentation explains concepts theoretically but doesn't show concrete code examples. Developers can't figure out how to use the framework.

**Why it happens:** Authors assume readers understand PBT concepts already. Examples seem "too obvious" to include.

**Consequences:**
- Steep learning curve
- Developers give up before understanding value
- Lots of support questions on basic usage
- Framework adoption stalls

**Prevention:**
```markdown
<!-- ❌ BAD: Theory without examples -->
Property-based testing verifies that properties hold for all inputs
in a domain by generating random test cases and shrinking failures
to minimal counterexamples.

<!-- ✅ GOOD: Concrete example first, theory second -->
## Quick Example

Instead of writing:
```swift
func testArrayReverse() {
  let array = [1, 2, 3]
  XCTAssertEqual(array.reversed().reversed(), array)
}
```

Write this to test 100 different arrays automatically:
```swift
@PropertyTest
func testArrayReverse(array: [Int]) {
  #expect(array.reversed().reversed() == array)
}
```

The framework generates 100 random arrays and verifies the property
holds for all of them. If a failure is found, it shrinks to the
smallest failing array automatically.
```

**Prevention strategies:**
- Every feature documented with code example
- README starts with side-by-side XCTest comparison
- "Getting Started" guide with 5 progressive examples
- COOKBOOK.md with 20+ real-world patterns
- Link examples to runnable code in Examples/ directory

**Phase warning:** Phase 4 (Documentation) — Examples should be added continuously, but comprehensive pass needed before v2.0 release.

**InvariantSwift specific:** Current docs have examples, but need more "XCTest → InvariantSwift" migration examples.

---

### Pitfall 8: Ghostwriter Generates Tests for Private Types

**What goes wrong:** Ghostwriter scans all types in a source file and generates tests, including private and internal types that shouldn't be tested externally.

**Why it happens:** Type extraction walks the AST and collects all type declarations without checking access level.

**Consequences:**
- Generated tests fail to compile (can't access private types)
- Users must manually delete generated tests
- Ghostwriter appears low-quality

**Prevention:**
```swift
// TestGenerator.swift should filter by access level
func generateTests(for typeInfo: TypeInfo) -> [GeneratedTest] {
  // ✅ Add access level check
  guard typeInfo.accessLevel == .public || typeInfo.accessLevel == .open else {
    if config.verbose {
      print("⚠️ Skipping \(typeInfo.name): not public")
    }
    return []
  }

  // ... existing generator checks
}
```

**Detection:**
- Parse access level modifiers during type extraction
- Add `accessLevel` property to `TypeInfo`
- Filter types before test generation
- Add config option `--include-internal` for comprehensive testing

**Phase warning:** Phase 3 (Ghostwriter fixes) — Critical for Ghostwriter to be useful.

**InvariantSwift specific:** Current `TypeInfo` in Ghostwriter doesn't track access level. Need to extract from SwiftSyntax AST.

---

### Pitfall 9: Large Counterexamples Not Shrunk Enough

**What goes wrong:** Shrinking stops too early, returning a counterexample with 50 elements when minimal failure is 2 elements.

**Why it happens:** Shrinking budget too low (default 1000 shrinks), or shrinking strategy is greedy/depth-first instead of breadth-first.

**Consequences:**
- Debugging harder (large counterexample obscures root cause)
- Developers lose confidence in framework
- Manual minimization required

**Prevention:**
```swift
// ✅ Use BFS shrinking (InvariantSwift already has this)
// ShrinkTree.findMinimal() uses BFS, not DFS

// ✅ Increase shrinking budget for complex types
let config = PropertyConfig(
  maxShrinks: 5000  // Up from default 1000
)

// ✅ Provide "shrink exhaustively" mode
let config = PropertyConfig(
  shrinkMode: .exhaustive  // No budget limit, find true minimum
)
```

**Prevention strategies:**
- Default to BFS shrinking (finds minimal, not just "smaller")
- Increase default shrinking budget to 5000
- Add `--exhaustive-shrink` flag for debugging
- Report shrinking metrics (attempts, time, reduction)
- Implement early termination if no progress for N attempts

**Phase warning:** Phase 2 (Shrinking improvements) — Validate shrinking effectiveness with benchmarks.

**InvariantSwift specific:** Already uses `ShrinkTree` with BFS. May need to increase default `maxShrinks` and add exhaustive mode.

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable.

### Pitfall 10: Deterministic Replay Not Documented

**What goes wrong:** Test fails in CI with seed X, developer can't figure out how to reproduce locally with same seed.

**Why it happens:** Seed is logged but reproduction command isn't shown. Developers don't know about `--seed` flag or `PropertyConfig(seed:)`.

**Consequences:**
- Can't reproduce CI failures locally
- Flaky test debugging is impossible
- Developers disable tests instead of fixing

**Prevention:**
```swift
// ✅ Show reproduction command in failure output
"""
Reproduce with:
  swift test --filter testArraySort --seed 12345

Or in code:
  let config = PropertyConfig(seed: 12345)
  checkProperty(property, config: config)
"""
```

**Prevention strategies:**
- Always log seed in test output (even on success)
- Include reproduction command in all failures
- Document seed-based replay prominently in README
- Add `INVARIANT_SEED` environment variable for global seed override

**Phase warning:** Phase 2 (Error reporting) — Low-hanging fruit for better developer experience.

---

### Pitfall 11: No Progress Indication for Slow Tests

**What goes wrong:** Property test runs 10,000 iterations over 30 seconds with no output. Developer thinks test is hung.

**Why it happens:** Framework runs silently unless failure occurs.

**Consequences:**
- Tests look broken
- Developers kill test suite prematurely
- Can't estimate how long tests will take

**Prevention:**
```swift
// ✅ Show progress for long-running tests
"Running testComplexProperty: 1000/10000 tests (10s elapsed)..."
"Running testComplexProperty: 2000/10000 tests (22s elapsed)..."
```

**Prevention strategies:**
- Print progress every 1000 iterations or 5 seconds
- Add `--verbose` flag for detailed output
- Show "Test completed: 10000 tests in 45s" on success
- Include performance metrics in CI reports

**Phase warning:** Phase 5 (Polish) — Nice-to-have for better UX.

---

### Pitfall 12: Confusing Property vs Test Terminology

**What goes wrong:** Framework uses both "property test" and "property" inconsistently. Developers confused about what to call things.

**Why it happens:** Property-based testing terminology from Haskell isn't standardized in other languages.

**Consequences:**
- Mental overhead learning framework
- Documentation searches miss content
- Code looks inconsistent

**Prevention:**
- Standardize on one term in public API
- "Property test" = the test function with @PropertyTest
- "Property" = the invariant being verified
- "Generator" = creates test values (not "arbitrary")
- "Counterexample" = failing test case (not "witness")

**Prevention strategies:**
- Glossary in documentation defining all terms
- Consistent naming in API (`checkProperty`, not `checkProp` or `verify`)
- Code examples use standard terminology
- Avoid Haskell-specific terms (Arbitrary, QC, Gen)

**Phase warning:** Phase 4 (Documentation) — Terminology standardization pass.

**InvariantSwift specific:** Currently uses `@PropertyTest` macro. PROJECT.md proposes `@Property` for cleaner syntax.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Phase 1: QuickCheck Parity** | Implementing `cover`/`classify`/`collect` incorrectly (performance overhead, unclear output) | Study QuickCheck Haskell source, Hypothesis Python implementation. Benchmark against reference implementations. |
| **Phase 2: Shrinking** | New shrinking strategies cause infinite loops (Pitfall 1) | Comprehensive termination tests. Monitor shrink iteration count. Add hard timeout. |
| **Phase 3: Ghostwriter** | Generated tests don't compile (Pitfalls 3, 8) | Compile-test all generated output. Auto-generate missing generators. Filter non-public types. |
| **Phase 4: Macros** | Macro expansion failures give cryptic errors | Invest in diagnostic messages. Test with SwiftSyntax error cases. Provide helpful fix-its. |
| **Phase 5: Documentation** | Examples assume FP knowledge (Pitfall 5) | User testing with non-FP developers. XCTest migration guide. Side-by-side comparisons. |
| **Phase 6: Code Cleanup** | Breaking existing tests during refactoring | Comprehensive test coverage before refactoring. Incremental changes with CI validation. |

---

## Accessibility-Specific Pitfalls

What makes PBT frameworks inaccessible to non-FP developers:

### 1. Abstract Examples

**Problem:** Documentation shows abstract examples like `(a + b) + c == a + (b + c)` instead of real-world use cases.

**Fix:** Show testing of `JSON.encode/decode`, `UserRepository.save/load`, `Calculator.add`, `String.reversed`.

---

### 2. No Migration Path from Example-Based Testing

**Problem:** Developers don't know how to convert their existing XCTest suite to property tests.

**Fix:** Provide migration guide with 20 before/after examples:
```swift
// Before: Example-based test
func testArraySort() {
  XCTAssertEqual([3,1,2].sorted(), [1,2,3])
}

// After: Property-based test
@PropertyTest
func testArraySort(array: [Int]) {
  let sorted = array.sorted()
  #expect(sorted == sorted.sorted())  // Idempotent
  #expect(sorted.count == array.count)  // Preserves length
}
```

---

### 3. "Read This Paper" Documentation

**Problem:** Documentation links to academic papers on property-based testing theory.

**Fix:** Practical cookbook first, theory optional. Link papers in "Further Reading" section, not as primary documentation.

---

### 4. Assumed Knowledge of QuickCheck

**Problem:** Documentation says "like QuickCheck" without explaining what QuickCheck is.

**Fix:** Explain concepts from first principles. Don't assume PBT knowledge.

---

### 5. Generator Composition Without Motivation

**Problem:** Shows `Gen.zip(genA, genB).flatMap { ... }` without explaining when/why you'd use this.

**Fix:** Motivate each combinator with concrete use case. "Need to generate users with valid emails? Use `Gen.zip(Gen.string, Gen.email)`"

---

## Sources

This research synthesized findings from multiple authoritative sources on property-based testing pitfalls and accessibility:

### Property-Based Testing Pitfalls
- [The Beginner's Guide to Property-based Testing](https://www.thesoftwarelounge.com/the-beginners-guide-to-property-based-testing/) - Common mistakes and pitfalls
- [Property-Based Testing](https://kiro.dev/blog/property-based-testing/) - Real-world implementation issues
- [The sad state of property-based testing libraries](https://discourse.haskell.org/t/the-sad-state-of-property-based-testing-libraries/9880) - Design limitations and gotchas
- [Property Based Testing | Gopher Academy Blog](https://blog.gopheracademy.com/advent-2017/property-based-testing/) - Common implementation mistakes

### QuickCheck/Hypothesis Implementation Issues
- [The Properties of QuickCheck, Hedgehog and Hypothesis](https://seelengrab.github.io/articles/The%20properties%20of%20QuickCheck,%20Hedgehog%20and%20Hypothesis/) - Design trade-offs and gotchas
- [QuickCheck Testing for Fun and Profit](https://www.researchgate.net/publication/220802890_QuickCheck_Testing_for_Fun_and_Profit) - Real-world implementation issues

### Shrinking Pitfalls
- [Shrinking | Kotest](https://kotest.io/docs/proptest/property-test-shrinking.html) - Shrinking implementation challenges
- [Your own property based testing framework — Part 3: Shrinkers](https://medium.com/@nicolasdubien/your-own-property-based-testing-framework-part-3-shrinkers-564fa7a180eb) - Infinite loop prevention
- [Stuck in a loop forever when shrinking](https://github.com/HypothesisWorks/hypothesis/issues/2395) - Real bug report of infinite shrinking loop

### Accessibility & Learning Curve
- [What is Property-based Testing?](https://hypothesis.works/articles/what-is-property-based-testing/) - Terminology confusion
- [Property-based testing accessibility non-functional programmers](https://www.testleaf.com/blog/top-10-software-testing-trends-2026-what-testers-must-prepare-for/) - Learning curve challenges

### Generator Design Issues
- [CS SYD - Property testing in depth: The size parameter](https://cs-syd.eu/posts/2020-01-28-property-testing-size) - Size parameter in recursive generators
- [gen.recursive: Build recursive structures](https://rdrr.io/cran/hedgehog/man/gen.recursive.html) - Preventing infinite depth
- [Test data: generators, shrinkers and Arbitrary instances](https://fscheck.github.io/FsCheck/TestData.html) - Generator implementation mistakes

### Assumption/Filter Problems
- [Property-Based Testing with jqwik](https://www.baeldung.com/java-jqwik-property-based-testing) - Discard ratio configuration
- [Property-Based Testing in Practice](https://harrisongoldste.in/papers/icse24-pbt-in-practice.pdf) - Real-world challenges with assumptions

### Test Generation
- [Property-Based Testing in Practice Harrison Goldstein](https://andrewhead.info/assets/pdf/pbt-in-practice.pdf) - Automated test generation challenges
- [Use Property-Based Testing to Bridge LLM Code Generation](https://arxiv.org/html/2506.18315v1) - Pitfalls of automated test generation
- [An Empirical Evaluation of Property-Based Testing in Python](https://cseweb.ucsd.edu/~mcoblenz/assets/pdf/OOPSLA_2025_PBT.pdf) - Real-world usage patterns

### SwiftCheck (Reference Implementation)
- [SwiftCheck GitHub](https://github.com/typelift/SwiftCheck) - Swift property testing framework patterns
- [Property-Based Testing with SwiftCheck](https://academy.realm.io/posts/tryswift-tj-usiyan-property-based-testing-swiftcheck/) - Swift-specific challenges
