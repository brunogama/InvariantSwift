# Project Research Summary

**Project:** InvariantSwift v2.0 QuickCheck Feature Parity
**Domain:** Property-based testing framework for Swift
**Researched:** 2026-01-23
**Confidence:** HIGH

## Executive Summary

InvariantSwift v2.0 aims for QuickCheck feature parity while maintaining accessibility for Swift developers without functional programming backgrounds. Current implementation has robust foundations (60% QuickCheck parity): generators with integrated shrinking, property testing infrastructure, macros, stateful testing, and example database. The critical gap is **test observability** — the framework lacks QuickCheck's `cover`, `classify`, `collect`, `label`, and `tabulate` functions that let developers verify their tests are actually exercising the right code paths.

The recommended approach prioritizes test observability (P0), then enhanced reporting (P1), then ergonomics (P2). This sequencing delivers immediate value (developers can see what their tests are doing) while building on solid architectural foundations. Key architectural insight: InvariantSwift already has `ClassificationContext` and `ClassificationReport` infrastructure but it's not integrated into the standard `Property<T>` execution path. Integration is straightforward via non-breaking extensions.

The primary risk is over-focusing on advanced features (coverage-guided fuzzing, SMT solvers, function generators) at the expense of basic observability. Mitigation: strict P0/P1/P2 prioritization with P0 blocking v2.0 release. Secondary risk: alienating Swift developers with FP jargon in documentation. Mitigation: comprehensive doc pass with XCTest migration examples and accessibility testing with non-FP developers.

## Cross-Document Insights

### Pattern: "Already Implemented, Just Not Connected"

A surprising finding across all research: many "missing" features are actually implemented but not integrated. Examples:
- **Classification** (`STACK.md`): `ClassificationContext`, `ClassificationReport`, `ClassifyingProperty` exist but aren't wired to `PropertyRunner`
- **Discard semantics** (`ARCHITECTURE.md`): `PropertyEvaluation.discard` fully implemented, just needs syntax sugar (`==>`)
- **Integrated shrinking** (`STACK.md` + `ARCHITECTURE.md`): `ShrinkTree<T>` with BFS already works, no rewrite needed

**Implication:** Implementation phases should be 30% coding, 70% integration and testing. Many features are "wire up existing infrastructure" not "build from scratch."

### Tension: Accessibility vs QuickCheck Parity

`FEATURES.md` emphasizes accessibility for Swift developers unfamiliar with FP, while `STACK.md` lists QuickCheck features using Haskell terminology (`Arbitrary`, `CoArbitrary`, `Monadic`). This tension appears in:
- **Modifiers** (`STACK.md`): QuickCheck has `Positive<T>`, `NonEmpty<T>` wrappers, but `FEATURES.md` flags these as "verbose in Swift"
- **Terminology** (`PITFALLS.md`): Using "functor", "monad", "morphism" hurts adoption
- **API design** (`ARCHITECTURE.md`): Should `Property<T>` expose FP combinators or builder patterns?

**Resolution:** Use Swift-idiomatic APIs with QuickCheck parity underneath. Example: `Gen.zip().map()` instead of `applicative.ap()`. Reserve FP terms for implementation details, not public API.

### Surprising Finding: Table Stakes Have Evolved

`FEATURES.md` research shows what was "advanced" in 2015 is now baseline:
- **Integrated shrinking**: Was QuickCheck research topic, now expected (Hypothesis, fast-check)
- **Example database**: Hypothesis innovation, now table stakes for CI/CD
- **Stateful testing**: Was niche, now required for real systems
- **Macros**: InvariantSwift's Swift macros advantage is huge (no other Swift PBT has this)

**Implication:** InvariantSwift is well-positioned. Already has advanced features (stateful testing, example database, macros) that competitors lack. Closing the observability gap makes it best-in-class.

### Architectural Consistency Validates Approach

`ARCHITECTURE.md` analysis confirms InvariantSwift's design choices align with modern PBT best practices:
- **Gen<T> with ShrinkTree**: Matches Hypothesis/Hedgehog integrated shrinking
- **Actor-based PropertyRunner**: Swift 6 concurrency done right
- **Size parameter threading**: Prevents infinite recursion (critical per `PITFALLS.md`)
- **Non-breaking extensions**: `ClassifyingProperty<T>` opt-in matches Swift evolution philosophy

No major architectural changes needed. Extend, don't rewrite.

## Feature Priority Matrix

| Feature | Complexity | Value | Architectural Fit | Risk | Priority |
|---------|-----------|-------|-------------------|------|----------|
| **P0 (MVP Blockers)** |
| `cover` (coverage enforcement) | Low | High | ✅ Use ClassificationContext | Low | **P0** |
| `classify` (test distribution) | Low | High | ✅ Use ClassificationContext | Low | **P0** |
| `label` (test labeling) | Low | High | ✅ Use ClassificationContext | Low | **P0** |
| **P1 (QuickCheck Parity)** |
| `collect` (value histograms) | Low | High | ✅ Use ClassificationContext | Low | **P1** |
| `tabulate` (multi-dimensional) | Medium | Medium | ✅ Use ClassificationContext | Low | **P1** |
| `counterexample` (custom messages) | Low | High | ✅ Extend PropertyResult | Low | **P1** |
| Statistics reporting | Medium | High | ✅ ClassificationReport output | Low | **P1** |
| `==>` syntax sugar | Low | Medium | ✅ Operator overload | Low | **P1** |
| **P2 (DX Improvements)** |
| Test modifiers (Positive, NonEmpty) | Medium | Low | ⚠️ Verbose in Swift | Medium | **P2** |
| Enhanced error messages | Medium | Medium | ✅ Extend PrettyPrint | Low | **P2** |
| Progress indicators | Low | Low | ✅ PropertyRunner logging | Low | **P2** |
| **P3 (Defer)** |
| CoArbitrary (function generators) | Very High | Very Low | ❌ Breaks accessibility | High | **P3** |
| Monadic property DSL | High | Medium | ⚠️ Already have async | Medium | **P3** |
| Advanced targeted testing | Very High | Medium | ⚠️ Platform limitations | High | **P3** |

**Key insight:** All P0 and P1 features are low complexity with high value. This is the "high value, low complexity" quadrant. Execute these first.

## Technology Decisions

### Decision 1: Classification Collection Mechanism

**Question:** How to collect coverage/classification statistics thread-safely?

**Options:**
1. `actor ClassificationContext` (existing)
2. `OSAllocatedUnfairLock<[String: Int]>` (lower overhead)
3. `Combine` publishers (reactive)

**Recommendation:** **Option 1 (actor)** — Already implemented, Swift 6 concurrency model, <1μs overhead per operation.

**Rationale:** `STACK.md` shows <10% performance target is achievable with actors. `ARCHITECTURE.md` confirms PropertyRunner is already an actor, so consistent model. No new dependencies.

**Sources:** `STACK.md` section "Concurrency Primitives", `ARCHITECTURE.md` "Decision 3"

---

### Decision 2: Property Extension Strategy (Breaking vs Non-Breaking)

**Question:** Add classification to existing `Property<T>` or create new type?

**Options:**
1. Break `Property<T>` to add `ClassificationContext` parameter
2. New `ClassifyingProperty<T>` opt-in type (existing)
3. Always-on classification with opt-out

**Recommendation:** **Option 2 (ClassifyingProperty<T>)** — Zero migration burden, clear opt-in, can merge later if universal.

**Rationale:** `ARCHITECTURE.md` "Decision 1" confirms this approach. `PITFALLS.md` warns against breaking changes that disable tests. Non-breaking preserves thousands of existing tests.

**Sources:** `ARCHITECTURE.md` section "Breaking vs Non-Breaking Changes", `PITFALLS.md` accessibility pitfalls

---

### Decision 3: Shrinking Strategy

**Question:** Rewrite shrinking to match Hypothesis/Hedgehog or keep current approach?

**Options:**
1. Rewrite to pure integrated shrinking (no `Shrink<T>` type)
2. Keep current `ShrinkTree<T>` with BFS (existing)
3. Hybrid with both type-based and integrated

**Recommendation:** **Option 2 (keep ShrinkTree<T>)** — Already implemented correctly, no benefit to rewrite, high risk.

**Rationale:** `ARCHITECTURE.md` confirms integrated shrinking via `ShrinkTree<T>` is already working. `STACK.md` shows flatMap uses `generateTreeOverride` for dependent shrinking (preserves invariants). `PITFALLS.md` warns infinite loops in shrinking are critical — current implementation avoids this with BFS.

**Sources:** `ARCHITECTURE.md` "Decision 4", `STACK.md` "Improved Shrinking", `PITFALLS.md` "Pitfall 1"

---

### Decision 4: Ghostwriter Generator Validation

**Question:** How to handle types without generators in Ghostwriter?

**Options:**
1. Skip types without generators (current)
2. Auto-generate `@Arbitrary` extensions
3. Fail with error message

**Recommendation:** **Option 2 (auto-generate)** — Eliminates #1 Ghostwriter complaint, makes output actually compile.

**Rationale:** `PITFALLS.md` Pitfall 3 identifies this as critical. `STACK.md` shows Swift macros can analyze types and generate conformances. `FEATURES.md` shows Ghostwriter is a differentiator — must work reliably.

**Sources:** `PITFALLS.md` section "Pitfall 3", `STACK.md` "Ghostwriter", `FEATURES.md` "Differentiators"

---

### Decision 5: Documentation Terminology

**Question:** Use QuickCheck terminology or Swift-native terms?

**Options:**
1. Match QuickCheck exactly (`Arbitrary`, `CoArbitrary`, `Monadic`)
2. Swift-idiomatic (`Generator`, `Property`, `Async`)
3. Hybrid (FP terms in implementation, Swift terms in docs)

**Recommendation:** **Option 2 (Swift-native)** — Critical for accessibility, no downside to Swift developers.

**Rationale:** `PITFALLS.md` Pitfall 5 shows FP terminology scares away mainstream Swift developers. `FEATURES.md` emphasizes target users are "Swift developers without FP background." `STACK.md` shows all QuickCheck features are expressible in Swift-native terms.

**Sources:** `PITFALLS.md` "Pitfall 5", `FEATURES.md` "Accessibility Impact Analysis"

## Phase Sequencing Recommendations

### Phase 1: Test Observability (P0) — 1-2 weeks

**Rationale:** Missing test observability is the critical gap preventing users from knowing if their property tests are valuable. Hypothesis and QuickCheck both treat this as table stakes. All infrastructure (`ClassificationContext`) exists, just needs wiring.

**Delivers:**
- `Property.cover(percentage, when:, label:)` — Enforce minimum coverage thresholds
- `Property.classify(when:, label:)` — Label test case distribution
- `Property.label(_:)` — Unconditional labeling
- Integration with `PropertyRunner.runClassifyingProperty`
- Basic statistics output in test reports

**Addresses features from FEATURES.md:**
- Table stakes: "Test Case Classification & Coverage" (critical gap)

**Uses stack from STACK.md:**
- Swift Standard Library (actors for thread-safety)
- Existing `ClassificationContext`, `ClassificationReport` types

**Implements from ARCHITECTURE.md:**
- Extend `PropertyRunner` with classification execution path
- Wire `ClassificationContext` into iteration loop
- Return `(PropertyResult<T>, ClassificationReport)` tuple

**Avoids pitfalls from PITFALLS.md:**
- Pitfall 5 (FP terminology): Use Swift-native API (`cover`, not `checkCoverage`)
- Pitfall 6 (unclear errors): Report coverage failures distinctly

**Dependencies:** None. Infrastructure exists.

**Research flag:** ✅ Standard patterns, skip additional research

---

### Phase 2: Enhanced Reporting (P1) — 1-2 weeks

**Rationale:** Building on Phase 1, add remaining QuickCheck observability features. These improve debugging workflow (counterexample messages) and test quality verification (collect, tabulate). Low complexity, high value.

**Delivers:**
- `Property.collect(_:)` — Histogram of collected values
- `Property.tabulate(category:, labels:)` — Multi-dimensional distribution
- `Property.counterexample(_:)` — Custom failure messages
- Enhanced `ClassificationReport` with tables and histograms
- Pretty-printed statistics output (QuickCheck-style)

**Addresses features from FEATURES.md:**
- Table stakes: "Value Collection", "Counterexample Strings"
- P1: Enhanced debugging experience

**Uses stack from STACK.md:**
- `swift-custom-dump` (existing dependency) for pretty-printing
- `Dictionary<String, [String: Int]>` for distribution tracking

**Implements from ARCHITECTURE.md:**
- Extend `ClassificationContext` with histogram support
- Add counterexample field to `PropertyResult.failure`
- Implement table formatting in `ClassificationReport.prettyPrint()`

**Avoids pitfalls from PITFALLS.md:**
- Pitfall 6 (unclear errors): Counterexample messages make failures actionable
- Pitfall 7 (no examples): Each feature documented with concrete examples

**Dependencies:** Phase 1 (ClassificationContext integration)

**Research flag:** ✅ Standard patterns, skip additional research

---

### Phase 3: Discard Improvements & Syntax Sugar (P1) — 3-5 days

**Rationale:** Small quality-of-life improvements that complete QuickCheck parity. Discard tracking prevents Pitfall 4 (over-filtering). Syntax sugar (`==>`) makes conditional properties ergonomic.

**Delivers:**
- `==>` implication operator for conditional properties
- Discard ratio tracking and warnings
- `PropertyResult.gaveUp(discardReasons:)` with detailed reasons
- `PropertyConfig.maxDiscardRatio` configuration

**Addresses features from FEATURES.md:**
- Table stakes: "Conditional Properties (Discard)" with syntax sugar
- P1: Better developer experience for assumptions

**Uses stack from STACK.md:**
- Existing `PropertyEvaluation.discard(reason:)` infrastructure
- Swift operator overloading for `==>`

**Implements from ARCHITECTURE.md:**
- Add discard reason tracking to `PropertyRunner`
- Extend `PropertyResult` with discard statistics
- Implement `==>` operator extension on `Property<T>`

**Avoids pitfalls from PITFALLS.md:**
- Pitfall 4 (discard explosion): Track ratio, warn at 50%, fail at 90%
- Pitfall 6 (unclear errors): Show which assumptions are discarding

**Dependencies:** None (extends existing infrastructure)

**Research flag:** ✅ Standard patterns, skip additional research

---

### Phase 4: Ghostwriter Fixes (P1) — 1 week

**Rationale:** Ghostwriter is a differentiator (only Hypothesis has this), but current implementation has critical issues: generates tests for private types, missing generators, doesn't compile. Fixing these makes Ghostwriter production-ready.

**Delivers:**
- Access level filtering (skip private/internal types)
- Auto-generation of missing `@Arbitrary` conformances
- Compile-test all generated output before writing
- `--generate-arbitrary` flag to create generator boilerplate
- Better error messages for unsupported types

**Addresses features from FEATURES.md:**
- Differentiator: "Ghostwriter (Auto-Test Generation)" — currently broken
- Accessibility: Lower barrier to entry by generating working code

**Uses stack from STACK.md:**
- SwiftSyntax 602.0.0 (existing) for AST analysis
- Type analysis to extract access levels and member types

**Implements from ARCHITECTURE.md:**
- Add `accessLevel` property to `TypeInfo` extraction
- Implement generator existence validation
- Add compile-test step to `TestGenerator`

**Avoids pitfalls from PITFALLS.md:**
- Pitfall 3 (missing generators): Auto-generate instead of skip
- Pitfall 8 (private types): Filter by access level before generation

**Dependencies:** None (isolated to Ghostwriter plugin)

**Research flag:** ⚠️ Needs API research for complex generic types

---

### Phase 5: Error Messages & Progress (P2) — 3-5 days

**Rationale:** Polish pass to improve developer experience. Better error messages reduce debugging time. Progress indicators prevent "is this test hung?" confusion. Low complexity, measurable impact.

**Delivers:**
- Enhanced failure messages with reproduction commands
- Seed logging in all test output
- Progress indicators for long-running tests
- Shrinking metrics (attempts, reduction percentage)
- `INVARIANT_SEED` environment variable

**Addresses features from FEATURES.md:**
- P2: "Enhanced error messages" for better DX
- Accessibility: Make debugging property test failures approachable

**Uses stack from STACK.md:**
- Existing `PrettyPrint.swift` infrastructure
- Swift Testing `Issue.record()` integration

**Implements from ARCHITECTURE.md:**
- Extend `PropertyResult` with metrics
- Add progress logging to `PropertyRunner`
- Enhance `PrettyPrint` with reproduction commands

**Avoids pitfalls from PITFALLS.md:**
- Pitfall 10 (no replay docs): Show reproduction command in every failure
- Pitfall 11 (no progress): Log every 1000 iterations or 5 seconds

**Dependencies:** None

**Research flag:** ✅ Standard patterns, skip additional research

---

### Phase 6: Documentation & Examples (P2) — 1 week

**Rationale:** Accessibility depends on excellent documentation. XCTest migration guide lowers adoption barrier. Cookbook provides copy-paste solutions. Terminology standardization prevents confusion.

**Delivers:**
- XCTest → InvariantSwift migration guide (20 examples)
- Expanded COOKBOOK.md (real-world patterns)
- Glossary of terms (no FP jargon)
- "Getting Started" tutorial (5 progressive examples)
- Side-by-side QuickCheck comparison for experienced users

**Addresses features from FEATURES.md:**
- Accessibility: Target users are "Swift developers without FP background"
- All features documented with concrete examples

**Uses stack from STACK.md:**
- Documentation.docc (Swift Package Manager docs)
- Markdown with code examples

**Implements from ARCHITECTURE.md:**
- Document all new APIs from Phases 1-3
- Explain classification/coverage concepts from first principles

**Avoids pitfalls from PITFALLS.md:**
- Pitfall 5 (FP terminology): Audit all docs, remove/explain jargon
- Pitfall 7 (no examples): Every concept has 2+ concrete examples
- Pitfall 12 (terminology): Standardize on Swift-native terms

**Dependencies:** Phases 1-3 (document new features)

**Research flag:** ⚠️ Needs user testing with non-FP developers

---

### Phase 7: Code Cleanup (P3) — Optional, Post-v2.0

**Rationale:** Tech debt cleanup and performance optimization. Defer until after v2.0 to focus on features. Includes removing disabled tests, consolidating duplicate code, benchmarking.

**Delivers:**
- Remove `.disabled` test files or fix/re-enable
- Consolidate `RegressionBank.swift` (exists in two places)
- Performance benchmarks for classification overhead
- Removed unused Advanced/ features (SMT, LibFuzzer integration)

**Dependencies:** All previous phases (regression tests for cleanup)

**Research flag:** ⚠️ Needs profiling to identify bottlenecks

---

### Phase Ordering Rationale

1. **Observability first** (Phases 1-3): Without classification/coverage, users can't verify their tests are valuable. This is the critical blocker.
2. **Ghostwriter second** (Phase 4): Differentiating feature that's currently broken. Fix before v2.0.
3. **Polish third** (Phases 5-6): Improve DX and accessibility. Can iterate post-v2.0 if time-constrained.
4. **Cleanup last** (Phase 7): Tech debt doesn't block users. Defer to v2.1.

**Dependency flow:**
```
Phase 1 (Observability) → Phase 2 (Reporting)
                       ↘
                         Phase 3 (Discard)
                       ↗
Phase 4 (Ghostwriter) — independent
Phase 5 (Errors) ← depends on Phase 1-3 (new features to document)
Phase 6 (Docs) ← depends on Phase 1-5 (all features implemented)
Phase 7 (Cleanup) ← depends on all (regression tests)
```

**Risk mitigation:**
- All P0/P1 features in Phases 1-4 are low complexity (high confidence)
- Each phase delivers working, tested features (incremental value)
- Non-breaking changes allow parallel development on existing features
- Phase 4 (Ghostwriter) is isolated (can slip without blocking others)

## Open Questions for Requirements Phase

### 1. Classification API Naming

**Question:** Match QuickCheck function names exactly or use Swift-idiomatic names?

**Options:**
- QuickCheck: `classify`, `collect`, `cover`
- Swift-idiomatic: `categorize`, `track`, `requireCoverage`

**Recommendation:** Match QuickCheck for discoverability, but add Swift doc comments explaining concepts.

**Needs user input:** Developer preference survey?

---

### 2. Coverage Percentage Defaults

**Question:** What's the right default minimum coverage percentage?

**Options:**
- QuickCheck: No default (must specify)
- Hypothesis: 100% of labeled categories must have ≥1 example
- Proposal: 1% minimum (just ensure category exists)

**Recommendation:** Start with 1% (permissive), let users increase. Warn but don't fail.

**Needs validation:** Run on existing InvariantSwift tests to see typical distributions.

---

### 3. Ghostwriter Arbitrary Generation Strategy

**Question:** How much type inference for auto-generated `@Arbitrary` conformances?

**Options:**
1. Simple: Generate for structs with all `Generatable` members only
2. Medium: Infer generators for Arrays, Optionals, nested types
3. Aggressive: Use reflection/macros to generate for any type

**Recommendation:** Start with Option 1 (simple), expand based on feedback.

**Needs research:** Evaluate macro-based arbitrary generation (compile-time vs runtime).

---

### 4. Discard Ratio Thresholds

**Question:** What discard ratio should trigger warnings vs failures?

**Current QuickCheck:** Gives up after 10x iterations (e.g., 1000 discards for 100 test goal)

**Options:**
- Conservative: Warn at 2x, fail at 5x
- Standard: Warn at 5x, fail at 10x (match QuickCheck)
- Permissive: Warn at 10x, never fail (just log)

**Recommendation:** Start with QuickCheck defaults (10x fail), make configurable.

**Needs validation:** Check discard rates in existing InvariantSwift tests.

---

### 5. Progress Indicator Verbosity

**Question:** When to show progress for property tests?

**Options:**
1. Never (silent unless failure)
2. Always (every test shows progress)
3. Conditional (only if test runs >5 seconds or >1000 iterations)
4. Opt-in (`@PropertyTest(verbose: true)`)

**Recommendation:** Option 3 (conditional) — silent for fast tests, informative for slow.

**Needs user input:** CI/CD environments may want different behavior than local dev.

## Confidence Assessment

| Area | Confidence | Notes |
|------|-----------|-------|
| Stack | **HIGH** | All technologies verified in `Package.swift`, well-documented. No new dependencies needed for P0/P1 features. |
| Features | **HIGH** | QuickCheck features exhaustively cataloged with official Hackage docs. Hypothesis/fast-check comparisons validate priorities. |
| Architecture | **HIGH** | Existing codebase analysis shows solid foundations. `ClassificationContext` already exists. Non-breaking extension path is clear. |
| Pitfalls | **MEDIUM-HIGH** | Common pitfalls well-documented across PBT frameworks. InvariantSwift-specific risks identified via codebase inspection. Some unknowns in Ghostwriter type inference. |

**Overall confidence:** **HIGH** — Ready for roadmap creation and implementation.

### What We're Confident About

1. **P0/P1 features are low risk**: All use existing infrastructure (`ClassificationContext`, `PropertyEvaluation`), no architectural changes.
2. **Non-breaking approach is correct**: Thousands of existing tests preserved, clear migration path.
3. **Shrinking works**: `ShrinkTree<T>` BFS implementation is correct, no rewrite needed.
4. **QuickCheck feature list is complete**: Official Hackage documentation provides authoritative feature catalog.
5. **Phase sequencing is sound**: Dependencies validated, critical path (observability) prioritized.

### What Needs Validation

1. **Performance overhead**: Classification actor calls may add latency. Need benchmarks to validate <10% target.
2. **Ghostwriter type inference**: Auto-generating `@Arbitrary` for complex generics may be difficult. Scope needs refinement.
3. **Documentation accessibility**: Need user testing with Swift developers unfamiliar with PBT to validate terminology and examples.
4. **Discard ratio defaults**: Need to measure existing test suite to calibrate warnings/failures.
5. **Coverage percentage defaults**: 1% may be too permissive or too strict. Needs empirical data.

### Gaps to Address During Planning

1. **Generator existence registry**: How to track which types have generators? Static analysis? Runtime registry? Affects Ghostwriter Phase 4.
2. **Compile-test infrastructure**: Need automated way to validate Ghostwriter output compiles. SwiftPM plugin? Macro expansion test?
3. **Multi-platform progress indicators**: Terminal output works locally, but CI/CD may need structured logs. Design needed.
4. **Example database integration**: ISP-0004 implemented, but how to integrate with classification? Replay saved examples with coverage tracking?
5. **Targeted testing cross-platform**: LLVM coverage macOS-only. Alternatives for Linux/iOS? Defer or research source-based heuristics?

## Sources

### Primary (HIGH confidence)

**QuickCheck (Haskell reference implementation):**
- [Test.QuickCheck.Property - Hackage](https://hackage.haskell.org/package/QuickCheck-2.10.1/docs/Test-QuickCheck-Property.html) — `cover`, `classify`, `collect`, `label` official API
- [Test.QuickCheck.Modifiers - Hackage](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck-Modifiers.html) — Type modifiers (Positive, NonEmpty)
- [QuickCheck Manual - Chalmers](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html) — Authoritative usage guide

**Hypothesis (Python leader):**
- [Hypothesis Documentation](https://hypothesis.readthedocs.io/en/latest/) — Stateful testing, example database
- [Integrated Shrinking Article](https://hypothesis.works/articles/integrated-shrinking/) — Architecture comparison
- [Hypothesis Example Database](https://hypothesis.readthedocs.io/en/latest/database.html) — Persistence design

**fast-check (TypeScript):**
- [fast-check Documentation](https://fast-check.dev/) — Modern PBT patterns
- [Shrinking Guide](https://fast-check.dev/docs/core-blocks/arbitraries/shrinking/) — Hybrid shrinking approach

**InvariantSwift Codebase:**
- `Sources/InvariantSwift/Core/Property.swift` — PropertyEvaluation, discard semantics
- `Sources/InvariantSwift/Core/ClassificationContext.swift` — Existing classification infrastructure
- `Sources/InvariantSwift/Ghostwriter/TestGenerator.swift` — Current Ghostwriter implementation
- `Package.swift` — Dependency verification

### Secondary (MEDIUM confidence)

**Property-based testing best practices:**
- [Hypothesis: What is Property-Based Testing?](https://hypothesis.works/articles/what-is-property-based-testing/) — Conceptual foundation
- [jqwik User Guide](https://jqwik.net/docs/current/user-guide.html) — Java PBT patterns
- [Property Testing Book](https://propertesting.com/book_shrinking.html) — Shrinking strategies

**Swift concurrency:**
- [Swift 6 Concurrency Guide](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) — Actor usage patterns
- [Swift Forums: Testing with Actors](https://forums.swift.org/t/swift-5-10-concurrency-and-xctest/69929) — Testing concurrency

**Framework comparisons:**
- [PBT Frameworks Comparison - GitHub](https://github.com/jmid/pbt-frameworks) — Feature matrix
- [In Praise of Property-Based Testing](https://increment.com/testing/in-praise-of-property-based-testing/) — Industry adoption

### Tertiary (LOW confidence, needs validation)

**Ghostwriter implementation:**
- [Property-Based Testing in Practice (PDF)](https://andrewhead.info/assets/pdf/pbt-in-practice.pdf) — Challenges in automated test generation
- User testing needed to validate auto-generated arbitrary conformances

**Accessibility research:**
- Swift developer surveys on PBT familiarity (not found, needs primary research)
- Effectiveness of XCTest migration guides (anecdotal, needs validation)

---

*Research completed: 2026-01-23*
*Ready for roadmap: yes*
*Next step: Create phased roadmap with detailed requirements for P0 features*
