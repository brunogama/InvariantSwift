# InvariantSwift Implementation Roadmap - Task Breakdown

**Document Status**: Active Task Planning
**Last Updated**: January 16, 2026
**Total Tasks**: 124 granular sub-tasks across 9 milestones
**MVP Scope**: Milestones 0-3 (Steps 1-4, ~54 tasks)
**Extension Scope**: Milestones 4-9 (Steps 5-9, ~70 tasks)

---

## Quick Navigation

- [Milestone 0: Naming & Public API](#milestone-0-naming--public-api-stabilization) - 12 tasks
- [Milestone 1: Core Generator & Shrinking](#milestone-1-core-generator--shrinking-engine) - 18 tasks
- [Milestone 2: Swift Testing Integration](#milestone-2-swift-testing-integration) - 14 tasks
- [Milestone 3: @PropertyTest Macro](#milestone-3-propertytestmacro) - 15 tasks
- [Milestone 4: Process Isolation](#milestone-4-process-isolation--crash-capture) - 12 tasks
- [Milestone 5: CLI & Plugin](#milestone-5-cli-tool--spm-plugin) - 13 tasks
- [Milestone 6: Model-Based Testing](#milestone-6-model-based-testing) - 14 tasks
- [Milestone 7: Coverage-Guided Testing](#milestone-7-coverage-guided-testing-input-space-focus) - 16 tasks
- [Milestone 8: Invariant Mining](#milestone-8-invariant-mining-optional) - 14 tasks

[Master Dependency Graph](#master-dependency-graph)

---

## Milestone 0: Naming & Public API Stabilization

**Target**: Establish production-ready public API and naming conventions
**Effort**: 12 tasks / ~40 hours
**MVP Critical**: YES - Foundation for all downstream work

### 0.1 Audit Current Public API

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.1 |
| **Title** | Audit and document all public APIs |
| **Objective** | Create comprehensive inventory of all public types, functions, and protocols currently exposed |
| **Acceptance Criteria** | ✓ Document lists all 80+ public symbols<br>✓ Categorize by module (Core, Generators, Advanced)<br>✓ Mark for keep/rename/deprecate<br>✓ Document current usage patterns in tests |
| **Dependencies** | None |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/API_AUDIT.md` (new)<br>`Sources/InvariantSwift/**/*.swift` (read-only) |
| **Example Output** | List with entries: `Gen<T> (KEEP)`, `PropertyRunner (RENAME→Runner)`, `InternalShim (DEPRECATE)` |

### 0.2 Design Public API Surface

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.2 |
| **Title** | Design final public API surface and naming scheme |
| **Objective** | Define the stable, long-term API that will be locked at 1.0 |
| **Acceptance Criteria** | ✓ Create API design document with rationale<br>✓ Define namespace organization (InvariantSwift.Core, etc.)<br>✓ Specify protocol hierarchy (Generatable→Generable→Gen)<br>✓ Get team review/approval on design |
| **Dependencies** | 0.1 |
| **Effort** | Medium (3-5 hours) |
| **Files** | `docs/PUBLIC_API_DESIGN.md` (new) |
| **Example Output** | "Gen<T> is primary public protocol, PropertyRunner becomes @available(*, renamed: \"Runner\")" |

### 0.3 Create API Documentation Template

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.3 |
| **Title** | Create and validate DocC documentation template |
| **Objective** | Establish standard format for all public API documentation |
| **Acceptance Criteria** | ✓ Template includes: summary, parameters, return value, discussion, examples<br>✓ Examples are compilable (buildable from doctest)<br>✓ Document compliance requirements<br>✓ Add to CLAUDE.md documentation guidelines |
| **Dependencies** | 0.2 |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/API_DOCUMENTATION_TEMPLATE.md` (new)<br>`CLAUDE.md` (update) |
| **Example Output** | Template showing required `///` comment structure with example implementation |

### 0.4 Add DocC comments to public APIs

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.4 |
| **Title** | Add comprehensive DocC documentation to all public symbols |
| **Objective** | Fully document all public APIs with examples and cross-references |
| **Acceptance Criteria** | ✓ All 80+ public symbols have DocC comments<br>✓ All examples compile and run<br>✓ Coverage: 100% for public APIs<br>✓ Build succeeds with no warnings: `swift build -Xswiftc -warnings-as-errors` |
| **Dependencies** | 0.3 |
| **Effort** | Large (8-10 hours) |
| **Files** | `Sources/InvariantSwift/**/*.swift` (update all public APIs) |
| **Example Output** | Gen<T> has full DocC with 3+ usage examples, protocol requirements documented |

### 0.5 Rename/deprecate APIs per design

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.5 |
| **Title** | Execute API renames and mark deprecated symbols |
| **Objective** | Implement the public API changes identified in task 0.2 |
| **Acceptance Criteria** | ✓ All renames applied (PropertyRunner → Runner, etc.)<br>✓ Old names marked @available(*, renamed:) with deprecation message<br>✓ Build succeeds with no warnings<br>✓ All tests pass (may need updating for new names) |
| **Dependencies** | 0.2, 0.4 |
| **Effort** | Medium (4-6 hours) |
| **Files** | `Sources/InvariantSwift/**/*.swift` (update)<br>`Tests/FunctionalTesting/**/*.swift` (update test calls) |
| **Example Output** | Old APIs compile with deprecation warning; new names work without warnings |

### 0.6 Update Package.swift exports

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.6 |
| **Title** | Configure module exports and public API surface in Package.swift |
| **Objective** | Lock down which symbols are exported and visible to consumers |
| **Acceptance Criteria** | ✓ Package.swift specifies explicit module imports<br>✓ Only intended public APIs are accessible from outside<br>✓ Verify with: `swift package describe`<br>✓ No accidental internal APIs exposed |
| **Dependencies** | 0.5 |
| **Effort** | Small (1-2 hours) |
| **Files** | `Package.swift` (update)<br>`Sources/InvariantSwift/InvariantSwift.swift` (create main module file if needed) |
| **Example Output** | Package.swift has proper visibility controls; running `swift build` shows only public symbols |

### 0.7 Write API stability guide

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.7 |
| **Title** | Document API stability commitments and versioning strategy |
| **Objective** | Establish semantic versioning and backwards-compatibility rules |
| **Acceptance Criteria** | ✓ Document SemVer usage (major.minor.patch)<br>✓ Define what constitutes breaking change<br>✓ Specify deprecation timeline (2 releases minimum)<br>✓ Add to CONTRIBUTING.md |
| **Dependencies** | 0.2 |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/API_STABILITY.md` (new)<br>`CONTRIBUTING.md` (update) |
| **Example Output** | "Major version bumps only for public API changes. 2-release deprecation window required." |

### 0.8 Create API reference guide

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.8 |
| **Title** | Create comprehensive API reference documentation |
| **Objective** | Build searchable, organized reference of all public APIs |
| **Acceptance Criteria** | ✓ Document all 80+ public symbols with categories<br>✓ Include quick lookup tables<br>✓ Show common usage patterns<br>✓ Cross-reference related symbols |
| **Dependencies** | 0.4 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `docs/API_REFERENCE.md` (new) |
| **Example Output** | Table with columns: Symbol | Category | Brief Description | Example |

### 0.9 Update README with API examples

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.9 |
| **Title** | Update main README with new public API examples |
| **Objective** | Reflect finalized API surface in user-facing documentation |
| **Acceptance Criteria** | ✓ All README examples use current public API names<br>✓ Examples are compilable/runnable<br>✓ Reflect common use cases from tasks 0.1, 0.2<br>✓ Run examples to verify they work |
| **Dependencies** | 0.5, 0.4 |
| **Effort** | Small (2-3 hours) |
| **Files** | `README.md` (update) |
| **Example Output** | README shows updated Gen<T> API, PropertyRunner renamed to Runner, etc. |

### 0.10 Create CHANGELOG entry

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.10 |
| **Title** | Add comprehensive CHANGELOG entry for public API changes |
| **Objective** | Document all API changes for users upgrading to stable version |
| **Acceptance Criteria** | ✓ CHANGELOG lists all renames with migration path<br>✓ Specifies deprecation timeline<br>✓ Includes upgrade examples<br>✓ Cross-references migration guide (0.11) |
| **Dependencies** | 0.5 |
| **Effort** | Small (1-2 hours) |
| **Files** | `CHANGELOG.md` (update) |
| **Example Output** | Under [Unreleased], lists: "BREAKING: PropertyRunner renamed to Runner; old name available with deprecation warning until 2.0" |

### 0.11 Create migration guide

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.11 |
| **Title** | Document migration path for API changes |
| **Objective** | Help existing users update their code to use new public API |
| **Acceptance Criteria** | ✓ Migration guide lists all breaking changes<br>✓ Provides before/after code examples<br>✓ Step-by-step update instructions<br>✓ Validation checklist after migration |
| **Dependencies** | 0.5, 0.10 |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/MIGRATION.md` (new) |
| **Example Output** | "## Updating from 0.x to 1.0: Rename PropertyRunner to Runner throughout your code: `PropertyRunner()` → `Runner()`" |

### 0.12 Run full test suite and fix failures

| Aspect | Details |
|--------|---------|
| **Task ID** | 0.12 |
| **Title** | Verify all tests pass with new public API |
| **Objective** | Ensure no breaking changes to public API contracts in tests |
| **Acceptance Criteria** | ✓ Run: `swift test` with all platforms<br>✓ All tests pass<br>✓ No warnings or errors<br>✓ Coverage maintained at 99%<br>✓ Commit with message: "fix: update tests for public API stabilization" |
| **Dependencies** | 0.5, 0.4, 0.9 |
| **Effort** | Medium (3-5 hours) |
| **Files** | `Tests/FunctionalTesting/**/*.swift` (update as needed)<br>`Tests/InvariantSwiftMacroTests/**/*.swift` (update) |
| **Example Output** | All tests pass: "Test Suite passed; 124 tests run in 4.2s" |

---

## Milestone 1: Core Generator & Shrinking Engine

**Target**: Robust, optimized generator system with efficient shrinking
**Effort**: 18 tasks / ~60 hours
**MVP Critical**: YES - Foundation for all property-based testing
**Depends On**: Milestone 0 (naming/API stabilized)

### 1.1 Profile current generator performance

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.1 |
| **Title** | Profile and benchmark current generator implementations |
| **Objective** | Establish baseline performance metrics for optimization |
| **Acceptance Criteria** | ✓ Benchmark Int, String, [Int], Optional<T> generators<br>✓ Measure: generation rate (ops/sec), memory per generation, shrinking time<br>✓ Document baseline in `docs/PERFORMANCE_BASELINE.md`<br>✓ Target: 10,000+ generations/sec for primitives |
| **Dependencies** | Milestone 0 complete |
| **Effort** | Medium (3-4 hours) |
| **Files** | `docs/PERFORMANCE_BASELINE.md` (new)<br>`Tests/PerformanceTests/GeneratorPerformanceTests.swift` (update) |
| **Example Output** | "Int generator: 12,500 ops/sec, 48 bytes/gen. String: 3,200 ops/sec (variable length)" |

### 1.2 Optimize primitive generators

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.2 |
| **Title** | Optimize Int, Double, Bool, String primitive generators |
| **Objective** | Improve generation speed and reduce memory allocations |
| **Acceptance Criteria** | ✓ Reduce memory allocations by 20%+<br>✓ Achieve 15,000+ ops/sec for Int generator<br>✓ Use zero-copy string generation where possible<br>✓ Benchmarks show improvement vs. 1.1 baseline |
| **Dependencies** | 1.1 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Sources/InvariantSwift/Generators/PrimitiveGenerators.swift` (optimize)<br>`Tests/PerformanceTests/GeneratorPerformanceTests.swift` (update benchmarks) |
| **Example Output** | Int generator now: 15,200 ops/sec (+22%), 40 bytes/gen (-17%) |

### 1.3 Implement lazy shrinking trees

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.3 |
| **Title** | Implement lazy-evaluated shrinking tree data structure |
| **Objective** | Create efficient, memory-friendly shrinking representation |
| **Acceptance Criteria** | ✓ Implement ShrinkTree<T> as lazy sequence<br>✓ Support infinite shrinking depth (via sequence generation)<br>✓ Measure memory: should be O(log n) for shrinking path, not O(n)<br>✓ Verify with tests: `Tests/FunctionalTesting/ShrinkTreeTests.swift` |
| **Dependencies** | 1.1, 1.2 |
| **Effort** | Large (6-8 hours) |
| **Files** | `Sources/InvariantSwift/Advanced/ShrinkTrees.swift` (new/rewrite)<br>`Tests/FunctionalTesting/RecursiveShrinkingTests.swift` (update) |
| **Example Output** | ShrinkTree demonstrates lazy evaluation; shrinking 100-element array uses <1KB memory |

### 1.4 Add concurrent shrinking support

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.4 |
| **Title** | Implement parallel shrinking with Swift concurrency actors |
| **Objective** | Leverage multi-core systems for faster failure minimization |
| **Acceptance Criteria** | ✓ Implement actor-based shrinking coordinator<br>✓ Support 2-4x speedup on multi-core (measured)<br>✓ Maintain correctness: deterministic results with same seed<br>✓ Pass `AsyncPropertyTests.swift` suite |
| **Dependencies** | 1.3 |
| **Effort** | Large (6-8 hours) |
| **Files** | `Sources/InvariantSwift/Advanced/ShrinkTrees.swift` (add async support)<br>`Tests/FunctionalTesting/AsyncPropertyTests.swift` (update) |
| **Example Output** | Property runner with async shrinking on 4-core: 2.8x faster vs. sequential |

### 1.5 Implement combinator-based generators

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.5 |
| **Title** | Design and implement generator combinators (map, flatMap, filter, etc.) |
| **Objective** | Enable composable, functional generator construction |
| **Acceptance Criteria** | ✓ Implement: map, flatMap, filter, zip, oneOf, frequency<br>✓ All combinators preserve shrinking behavior<br>✓ Verify with: `Tests/FunctionalTesting/CombinatorGeneratorTests.swift`<br>✓ Examples in docstrings |
| **Dependencies** | 1.2 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Sources/InvariantSwift/Generators/CombinatorGenerators.swift` (expand/improve)<br>`Tests/FunctionalTesting/CombinatorGeneratorTests.swift` (comprehensive tests) |
| **Example Output** | Gen.oneOf([genInt, genString, genBool]).map { ... } chains cleanly |

### 1.6 Implement collection generators

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.6 |
| **Title** | Implement optimized generators for Array, Set, Dictionary |
| **Objective** | Provide efficient generation of common collection types |
| **Acceptance Criteria** | ✓ Array generator supports: size control, element generation<br>✓ Set generator ensures uniqueness efficiently<br>✓ Dictionary generator pairs keys with values<br>✓ All shrink correctly (remove elements, simplify contents)<br>✓ Pass `Tests/FunctionalTesting/CollectionGeneratorTests.swift` |
| **Dependencies** | 1.5 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Sources/InvariantSwift/Generators/CollectionGenerators.swift` (improve)<br>`Tests/FunctionalTesting/CollectionGeneratorTests.swift` (comprehensive) |
| **Example Output** | Gen.array(of: Gen.int).generate() produces array; shrinking removes elements and simplifies integers |

### 1.7 Add custom generator registration

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.7 |
| **Title** | Implement custom generator registration API |
| **Objective** | Allow users to define generators for domain types |
| **Acceptance Criteria** | ✓ Create GeneratorRegistry API<br>✓ Support: register, lookup, deregister generators<br>✓ Thread-safe (actor-based)<br>✓ Scope support (global, test-local)<br>✓ Examples in docstrings |
| **Dependencies** | 1.2, 1.5 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Sources/InvariantSwift/Core/Generator.swift` (update)<br>`Sources/InvariantSwift/Advanced/GeneratorRegistry.swift` (new) |
| **Example Output** | Users can: `registerGenerator(for: User.self) { User(...) }` |

### 1.8 Implement seed determinism

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.8 |
| **Title** | Ensure deterministic generation with seed-based RNG |
| **Objective** | Same seed + size = exact same generated values (essential for reproducibility) |
| **Acceptance Criteria** | ✓ Gen initialized with seed=42 produces identical sequence twice<br>✓ Different seeds produce different sequences<br>✓ Verify: run tests with multiple seeds, compare outputs<br>✓ Document: `docs/DETERMINISTIC_GENERATION.md` |
| **Dependencies** | 1.2 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/Core/Seed.swift` (verify/enhance)<br>`docs/DETERMINISTIC_GENERATION.md` (new) |
| **Example Output** | Gen(seed: 42).generate() on run 1 == Gen(seed: 42).generate() on run 2 |

### 1.9 Add distribution strategies

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.9 |
| **Title** | Implement weighted distribution generators (frequency, weighted) |
| **Objective** | Enable biased generation toward specific values/ranges |
| **Acceptance Criteria** | ✓ frequency: weighted selection among alternatives<br>✓ weighted: custom weight function for values<br>✓ Verify distribution: collect 10k samples, check distribution match<br>✓ Examples in docstrings |
| **Dependencies** | 1.5 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/Generators/DomainGenerators.swift` (add/update)<br>`Tests/FunctionalTesting/ComprehensiveGeneratorTests.swift` (add distribution tests) |
| **Example Output** | Gen.frequency([1 -> Gen.int, 3 -> Gen.positive]) generates positive 3x more often |

### 1.10 Add numeric range generators

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.10 |
| **Title** | Implement range-based generators (positive, negative, bounded) |
| **Objective** | Generate numbers within specified ranges efficiently |
| **Acceptance Criteria** | ✓ Gen.positive, Gen.negative, Gen.inRange(min...max)<br>✓ Shrinking respects bounds (shrink toward 0 or boundary)<br>✓ Support all numeric types (Int, UInt, Double)<br>✓ Pass `Tests/FunctionalTesting/NumericGeneratorTests.swift` |
| **Dependencies** | 1.2, 1.5 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/Generators/NumericGenerators.swift` (expand)<br>`Tests/FunctionalTesting/NumericGeneratorTests.swift` (comprehensive) |
| **Example Output** | Gen.inRange(1...100) generates integers; shrinking moves toward 1 |

### 1.11 Implement optional/result generators

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.11 |
| **Title** | Implement Optional and Result type generators |
| **Objective** | Generate wrapped types for testing error/empty cases |
| **Acceptance Criteria** | ✓ Gen.optional(of: genT) generates Optional<T><br>✓ Gen.result(success: genT, failure: genE) generates Result<T,E><br>✓ Shrinking: simplifies inner values, prefers .none or .failure<br>✓ Pass `Tests/FunctionalTesting/OptionalResultGeneratorTests.swift` |
| **Dependencies** | 1.5, 1.2 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/Generators/OptionalResultGenerators.swift` (expand)<br>`Tests/FunctionalTesting/OptionalResultGeneratorTests.swift` |
| **Example Output** | Gen.optional(of: Gen.string) produces mix of "some" strings and nil |

### 1.12 Add shrinking visualization/debugging

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.12 |
| **Title** | Implement shrinking trace visualization for debugging |
| **Objective** | Show users exactly how values shrink during minimization |
| **Acceptance Criteria** | ✓ Generate shrinking tree trace (JSON or formatted text)<br>✓ Show: original value → each shrink step → final minimal value<br>✓ Integrate with PropertyRunner output<br>✓ Example: `docs/SHRINKING_TRACE_EXAMPLE.md` |
| **Dependencies** | 1.3, 1.4 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/Presentation/ShrinkingTrace.swift` (new)<br>`docs/SHRINKING_TRACE_EXAMPLE.md` (new) |
| **Example Output** | Trace shows: [1,2,3,4,5] → [1,2,3,4] → [1,2,3] → [1,3] → [1] |

### 1.13 Implement shrinking predicates

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.13 |
| **Title** | Add shrink predicate system for custom shrinking rules |
| **Objective** | Allow users to control shrinking behavior per generator |
| **Acceptance Criteria** | ✓ Create ShrinkPredicate<T> protocol<br>✓ Examples: "shrink to smallest non-zero", "shrink via specific path"<br>✓ Composable with existing generators<br>✓ Documentation and examples |
| **Dependencies** | 1.3, 1.7 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Sources/InvariantSwift/Advanced/ShrinkPredicates.swift` (new)<br>`Tests/FunctionalTesting/ShrinkingTests.swift` (add predicate tests) |
| **Example Output** | Users can define: "when shrinking User, preserve ID field, only simplify data" |

### 1.14 Add size-aware generation

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.14 |
| **Title** | Implement size parameter propagation through generators |
| **Objective** | Control complexity of generated values (small, medium, large) |
| **Acceptance Criteria** | ✓ Gen.withSize(10) generates values ~10 in "complexity"<br>✓ Size applies to: collection lengths, string lengths, recursion depth<br>✓ Verify: size(5) produces smaller collections than size(20)<br>✓ Documentation |
| **Dependencies** | 1.2, 1.6 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Sources/InvariantSwift/Core/Generator.swift` (add size parameter)<br>`Tests/FunctionalTesting/GeneratorCoreTests.swift` (add size tests) |
| **Example Output** | Gen.array(of: Gen.int).withSize(5) produces arrays of ~5-15 elements |

### 1.15 Create generator testing utilities

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.15 |
| **Title** | Build internal utilities for testing generators |
| **Objective** | Create test helpers for validating generator behavior |
| **Acceptance Criteria** | ✓ Create `GeneratorTestHelpers.swift`<br>✓ Utilities: checkDistribution, checkShrinking, checkDeterminism<br>✓ Use in own tests and make available for user tests<br>✓ Document with examples |
| **Dependencies** | 1.8, 1.12 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Tests/FunctionalTesting/TestUtilities.swift` (expand)<br>`Sources/InvariantSwift/Testing/GeneratorTestHelpers.swift` (new) |
| **Example Output** | Users can: `checkDistribution(gen, samples: 10000) { ... verify distribution ... }` |

### 1.16 Performance profiling and optimization

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.16 |
| **Title** | Final performance tuning and benchmarking |
| **Objective** | Achieve target performance metrics |
| **Acceptance Criteria** | ✓ Int generator: 15,000+ ops/sec<br>✓ Array generator: 5,000+ ops/sec<br>✓ Shrinking: <100ms for most 100-element failures<br>✓ Document in: `docs/PERFORMANCE_FINAL.md`<br>✓ Commit: "perf: optimize generators to reach performance targets" |
| **Dependencies** | 1.2, 1.4, 1.12 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Tests/PerformanceTests/GeneratorPerformanceTests.swift` (final benchmarks)<br>`docs/PERFORMANCE_FINAL.md` (new) |
| **Example Output** | Final: Int 16,200 ops/sec (+30% vs baseline), shrinking <80ms |

### 1.17 Run comprehensive generator test suite

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.17 |
| **Title** | Run and pass complete generator test suite |
| **Objective** | Verify all generator functionality works correctly |
| **Acceptance Criteria** | ✓ All tests in `Tests/FunctionalTesting/*GeneratorTests.swift` pass<br>✓ No warnings<br>✓ Code coverage ≥99% for generator code<br>✓ Run: `swift test | xcbeautify` with all passing |
| **Dependencies** | 1.2 through 1.16 |
| **Effort** | Small (1-2 hours) |
| **Files** | `Tests/FunctionalTesting/` (all generator tests) |
| **Example Output** | "Tests passed: 89/89 (GeneratorCoreTests, CollectionGeneratorTests, etc.)" |

### 1.18 Commit generator milestone

| Aspect | Details |
|--------|---------|
| **Task ID** | 1.18 |
| **Title** | Create final commit for Milestone 1 |
| **Objective** | Capture all generator improvements with clear commit message |
| **Acceptance Criteria** | ✓ Commit message follows conventional commits<br>✓ Message: "feat(generators): implement optimized core generator engine with lazy shrinking"<br>✓ Includes all changes from 1.1-1.17<br>✓ Push to epic/mvp branch |
| **Dependencies** | 1.17 |
| **Effort** | Small (1 hour) |
| **Files** | All files from 1.1-1.17 |
| **Example Output** | Commit: `fade60f "feat(generators): implement optimized core generator engine with lazy shrinking"` |

---

## Milestone 2: Swift Testing Integration

**Target**: Seamless integration with Apple's Swift Testing framework
**Effort**: 14 tasks / ~45 hours
**MVP Critical**: YES - Primary test execution framework
**Depends On**: Milestones 0-1

### 2.1 Study Swift Testing framework

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.1 |
| **Title** | Research Swift Testing framework capabilities and integration points |
| **Objective** | Understand how to integrate property-based tests with @Test macro |
| **Acceptance Criteria** | ✓ Document: APIs, macros, hooks, test lifecycle<br>✓ Create: `docs/SWIFT_TESTING_INTEGRATION_ANALYSIS.md`<br>✓ Identify integration points (before/after, failure reporting, etc.)<br>✓ Review existing PropertyTestIntegration.swift for current approach |
| **Dependencies** | Milestones 0-1 complete |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/SWIFT_TESTING_INTEGRATION_ANALYSIS.md` (new)<br>`Sources/InvariantSwift/SwiftTesting/PropertyTestIntegration.swift` (read) |
| **Example Output** | "Swift Testing provides @Test macro, #expect(), #require(); can hook PropertyRunner.run into test lifecycle" |

### 2.2 Implement PropertyRunner integration

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.2 |
| **Title** | Create PropertyRunner adapter for Swift Testing tests |
| **Objective** | Allow property-based properties to run as Swift Testing @Test |
| **Acceptance Criteria** | ✓ PropertyRunner executes within @Test context<br>✓ Failures report via Swift Testing failure mechanism<br>✓ Example: property runs, shrinks, fails with clear message in xcode<br>✓ Pass: `Tests/FunctionalTesting/PropertyTestIntegrationTests.swift` |
| **Dependencies** | 2.1 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Sources/InvariantSwift/SwiftTesting/PropertyTestIntegration.swift` (enhance)<br>`Tests/FunctionalTesting/PropertyTestIntegrationTests.swift` (add integration tests) |
| **Example Output** | @Test func testProperty() { runner.run(property) } executes and fails through Swift Testing |

### 2.3 Add failure reporting and diagnostics

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.3 |
| **Title** | Implement detailed failure reporting in Swift Testing context |
| **Objective** | Show shrunken value, number of shrinks, seed for reproducibility |
| **Acceptance Criteria** | ✓ Failure message includes: seed, shrunken value, original value, shrink count<br>✓ Error message is concise but informative<br>✓ Includes command to reproduce: "swift test --seed 12345"<br>✓ Test shows clear diagnostics in Xcode |
| **Dependencies** | 2.2 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Sources/InvariantSwift/SwiftTesting/FailureReporting.swift` (new)<br>`Tests/FunctionalTesting/PropertyTestIntegrationTests.swift` (update) |
| **Example Output** | Failure: "Property failed with seed=987. Shrunken: [1,2]. Shrunk from [...]" |

### 2.4 Support async properties

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.4 |
| **Title** | Enable async property tests with Swift Testing async @Test |
| **Objective** | Support properties that perform async operations |
| **Acceptance Criteria** | ✓ Async property functions work with @Test(condition: .expectedToFail)<br>✓ PropertyRunner handles async generation and assertions<br>✓ Concurrent shrinking works with async properties<br>✓ Pass: `Tests/FunctionalTesting/AsyncPropertyTests.swift` |
| **Dependencies** | 2.2, 1.4 (concurrent shrinking) |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Sources/InvariantSwift/Advanced/AsyncProperties.swift` (enhance)<br>`Tests/FunctionalTesting/AsyncPropertyTests.swift` (add async tests) |
| **Example Output** | @Test async func testAsync() async { await runner.run(asyncProperty) } |

### 2.5 Implement #expect syntax support

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.5 |
| **Title** | Create macros for #expect integration within properties |
| **Objective** | Support Swift Testing's #expect() syntax in property assertions |
| **Acceptance Criteria** | ✓ Properties can use #expect(condition) directly<br>✓ Failures through #expect are caught and reported<br>✓ #require() for hard failures (stops shrinking)<br>✓ Examples in docstrings |
| **Dependencies** | 2.2, 2.3 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/SwiftTesting/PropertyAssertions.swift` (new)<br>`Tests/FunctionalTesting/PropertyTests.swift` (add #expect tests) |
| **Example Output** | Properties use: #expect(a + b > 0) instead of custom assertion |

### 2.6 Add test filtering and selection

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.6 |
| **Title** | Implement filtering/selection of properties to run |
| **Objective** | Support --filter, tags, or explicit test selection |
| **Acceptance Criteria** | ✓ Filter properties by name: swift test --filter PropertyName<br>✓ Support tags/categories: @Test @tag("quick"), @tag("slow")<br>✓ Verify: run subset of properties, others skip<br>✓ Document in CLI section |
| **Dependencies** | 2.2 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/SwiftTesting/PropertyTestIntegration.swift` (add filtering)<br>`docs/SWIFT_TESTING_FEATURES.md` (document filtering) |
| **Example Output** | swift test --filter QuickTests runs only quick properties |

### 2.7 Implement test repetition and seed control

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.7 |
| **Title** | Add command-line control for test repetition and seeds |
| **Objective** | Allow users to run tests N times with specific seeds |
| **Acceptance Criteria** | ✓ swift test --seed 12345 uses specific seed<br>✓ swift test --repeat 5 runs each test 5 times<br>✓ Combine: swift test --seed 42 --repeat 3<br>✓ Document in CLI help |
| **Dependencies** | 2.2, 1.8 (determinism) |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/SwiftTesting/CLIOptions.swift` (new)<br>`Sources/FuncTestCLI/main.swift` (update) |
| **Example Output** | swift test --seed 42 --repeat 3 runs each test 3x with seed 42 |

### 2.8 Add test statistics collection

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.8 |
| **Title** | Collect and report test statistics (examples, shrinks, time) |
| **Objective** | Show users insights about property testing process |
| **Acceptance Criteria** | ✓ Collect: number of generations, shrink count, time taken<br>✓ Report in summary: "Ran 1000 examples in 2.3s, avg shrink: 4.2"<br>✓ Per-property stats in verbose mode<br>✓ Save stats to JSON for analysis |
| **Dependencies** | 2.2, 2.3 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Sources/InvariantSwift/SwiftTesting/TestStatistics.swift` (new)<br>`Tests/FunctionalTesting/PropertyTestIntegrationTests.swift` (verify stats) |
| **Example Output** | "testAddition: 1000 examples, 5 shrinks, 145ms" |

### 2.9 Implement failure persistence

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.9 |
| **Title** | Save failing cases to file for analysis and reproduction |
| **Objective** | Enable post-mortem analysis of failures |
| **Acceptance Criteria** | ✓ Save failure cases to `.invariantswift/failures.json`<br>✓ Include: seed, value, timestamp, test name<br>✓ Users can: `swift test --replay-failures` to run saved failures<br>✓ Document: `docs/FAILURE_ANALYSIS.md` |
| **Dependencies** | 2.3, 2.8 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Sources/InvariantSwift/SwiftTesting/FailurePersistence.swift` (new)<br>`.invariantswift/failures.json` (new, git-ignored) |
| **Example Output** | Failures saved; running `swift test --replay-failures` re-runs previous failures |

### 2.10 Add test output formatting

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.10 |
| **Title** | Implement configurable test output formatting (verbose, compact, json) |
| **Objective** | Allow different output formats for different use cases |
| **Acceptance Criteria** | ✓ Formats: verbose (detailed), compact (one-liner), json (machine-readable)<br>✓ Default: compact (one per test)<br>✓ Flag: swift test --output json<br>✓ JSON includes all statistics from 2.8 |
| **Dependencies** | 2.8 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwift/SwiftTesting/OutputFormatting.swift` (new)<br>`Sources/FuncTestCLI/main.swift` (add --output flag) |
| **Example Output** | swift test --output json produces valid JSON with test results |

### 2.11 Create integration documentation

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.11 |
| **Title** | Write comprehensive Swift Testing integration guide |
| **Objective** | Help users understand how to use InvariantSwift with Swift Testing |
| **Acceptance Criteria** | ✓ Document: basic usage, async properties, filtering, statistics<br>✓ Examples: 5+ runnable code samples<br>✓ Create: `docs/SWIFT_TESTING_INTEGRATION.md`<br>✓ Include: common patterns and gotchas |
| **Dependencies** | 2.1-2.10 |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/SWIFT_TESTING_INTEGRATION.md` (new) |
| **Example Output** | Guide shows: "To write a property, define with @PropertyTest macro (see Milestone 3) or use PropertyRunner.run()" |

### 2.12 Run integration test suite

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.12 |
| **Title** | Verify all Swift Testing integration tests pass |
| **Objective** | Ensure full compatibility with Swift Testing framework |
| **Acceptance Criteria** | ✓ Run: `swift test Tests/FunctionalTesting/PropertyTestIntegrationTests.swift`<br>✓ All tests pass<br>✓ No warnings<br>✓ Coverage: ≥99% for integration code |
| **Dependencies** | 2.2-2.11 |
| **Effort** | Small (1-2 hours) |
| **Files** | `Tests/FunctionalTesting/PropertyTestIntegrationTests.swift` |
| **Example Output** | "Tests passed: 28/28 (PropertyTestIntegrationTests)" |

### 2.13 Create example applications

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.13 |
| **Title** | Build example property tests demonstrating Swift Testing integration |
| **Objective** | Provide copy-paste examples for users |
| **Acceptance Criteria** | ✓ Create 3-5 example properties (math, strings, collections)<br>✓ Each example has: property definition, test execution, output<br>✓ Examples are runnable: `swift test --filter Example`<br>✓ Place in: `docs/examples/swift_testing_examples.swift` |
| **Dependencies** | 2.11 |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/examples/swift_testing_examples.swift` (new) |
| **Example Output** | Example: testSortingIsIdempotent property runs with 1000 examples |

### 2.14 Commit Swift Testing integration milestone

| Aspect | Details |
|--------|---------|
| **Task ID** | 2.14 |
| **Title** | Create final commit for Milestone 2 |
| **Objective** | Capture all Swift Testing integration improvements |
| **Acceptance Criteria** | ✓ Commit message: "feat(swift-testing): integrate with Swift Testing @Test framework"<br>✓ Includes all changes from 2.1-2.13<br>✓ Push to epic/mvp branch |
| **Dependencies** | 2.13 |
| **Effort** | Small (1 hour) |
| **Files** | All files from 2.1-2.13 |
| **Example Output** | Commit: `abc12345 "feat(swift-testing): integrate with Swift Testing @Test framework"` |

---

## Milestone 3: @PropertyTest Macro

**Target**: Macro-based automatic test generation
**Effort**: 15 tasks / ~50 hours
**MVP Critical**: YES - Core convenience feature
**Depends On**: Milestones 0-2

### 3.1 Design @PropertyTest macro syntax

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.1 |
| **Title** | Design @PropertyTest macro syntax and transformation rules |
| **Objective** | Define how @PropertyTest transforms user functions into test suite |
| **Acceptance Criteria** | ✓ Design document: `docs/MACRO_DESIGN.md`<br>✓ Specify: input signature, output tests, generator inference<br>✓ Examples: before/after transformation<br>✓ Example: @PropertyTest func test(a: Int, b: String) transforms to @Test func testProperty() |
| **Dependencies** | Milestones 0-2 complete |
| **Effort** | Medium (3-4 hours) |
| **Files** | `docs/MACRO_DESIGN.md` (new) |
| **Example Output** | "@PropertyTest func test(a: Int, b: String) → generates 1000 tests with random Int, String pairs" |

### 3.2 Study SwiftSyntax for macro implementation

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.2 |
| **Title** | Research SwiftSyntax for implementing @PropertyTest macro |
| **Objective** | Understand SwiftSyntax API for AST manipulation |
| **Acceptance Criteria** | ✓ Document: `docs/SWIFTSYNTAX_TUTORIAL.md`<br>✓ Cover: AST structure, visitors, builders<br>✓ Example: simple macro (upper-case string)<br>✓ Verify example macro works |
| **Dependencies** | 3.1 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `docs/SWIFTSYNTAX_TUTORIAL.md` (new)<br>`Sources/InvariantSwiftMacros/ExampleMacro.swift` (example, to be deleted after) |
| **Example Output** | "SwiftSyntax provides FunctionDeclSyntax, ParameterClauseSyntax; can extract params and build new code" |

### 3.3 Implement macro parameter extraction

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.3 |
| **Title** | Extract function parameters and infer types from @PropertyTest |
| **Objective** | Parse function signature to determine generators needed |
| **Acceptance Criteria** | ✓ Extract: parameter names, types, defaults<br>✓ Support: Int, String, Bool, Double, [T], Optional<T>, Result<T,E><br>✓ For unsupported types: error with clear message<br>✓ Test with examples: func test(a: Int, b: [String], c: Optional<Int>) |
| **Dependencies** | 3.2 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Sources/InvariantSwiftMacros/PropertyTestMacro.swift` (parameter extraction)<br>`Tests/InvariantSwiftMacroTests/PropertyTestMacroTests.swift` (add tests) |
| **Example Output** | Extracts: [("a", Int), ("b", [String]), ("c", Optional<Int>)] |

### 3.4 Implement generator selection logic

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.4 |
| **Title** | Implement automatic generator selection based on parameter types |
| **Objective** | Map types to appropriate generators |
| **Acceptance Criteria** | ✓ Type mapping: Int→Gen.int, String→Gen.string, [T]→Gen.array(of:), etc.<br>✓ Support custom generators via @PropertyTest(generators: [...])<br>✓ Clear error for unmapped types<br>✓ Test: macro correctly selects generators |
| **Dependencies** | 3.3 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Sources/InvariantSwiftMacros/GeneratorSelection.swift` (new)<br>`Tests/InvariantSwiftMacroTests/PropertyTestMacroTests.swift` (add) |
| **Example Output** | Macro generates: Gen.int, Gen.string, Gen.array(of: Gen.string), Gen.optional(of: Gen.int) |

### 3.5 Implement macro code generation

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.5 |
| **Title** | Generate complete @Test function from @PropertyTest |
| **Objective** | Create full test that runs property with generated values |
| **Acceptance Criteria** | ✓ Generate @Test func __propertyTest_<name>() async<br>✓ Set up runner with 1000 examples<br>✓ Call user function with generated values<br>✓ Catch and report failures<br>✓ Example: macro expands property to complete test function |
| **Dependencies** | 3.4 |
| **Effort** | Large (6-8 hours) |
| **Files** | `Sources/InvariantSwiftMacros/PropertyTestMacro.swift` (code generation)<br>`Tests/InvariantSwiftMacroTests/PropertyTestMacroTests.swift` (expansion tests) |
| **Example Output** | Macro generates: @Test func __propertyTest_example() async { let runner = PropertyRunner(); ... } |

### 3.6 Add macro expansion tests

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.6 |
| **Title** | Write comprehensive tests for macro expansion |
| **Objective** | Verify macro produces correct code in all cases |
| **Acceptance Criteria** | ✓ Test cases: simple property, async property, property with complex types<br>✓ Verify: expansion is syntactically correct Swift<br>✓ Verify: generated code compiles<br>✓ Use SwiftSyntaxMacrosTestSupport |
| **Dependencies** | 3.5 |
| **Effort** | Medium (4-5 hours) |
| **Files** | `Tests/InvariantSwiftMacroTests/PropertyTestMacroTests.swift` (expand tests) |
| **Example Output** | Test verifies: @PropertyTest func test(a: Int) expands to @Test func __propertyTest_test() { ... } |

### 3.7 Implement error handling in macro

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.7 |
| **Title** | Add error reporting for macro compilation errors |
| **Objective** | Provide helpful error messages when macro usage is incorrect |
| **Acceptance Criteria** | ✓ Error: unsupported parameter type → "String? not supported; use Optional<String>"<br>✓ Error: missing generator for custom type → "provide generator via @PropertyTest(generators: ...)"<br>✓ Error: property returns value → "property must return Void"<br>✓ Errors are actionable and helpful |
| **Dependencies** | 3.3, 3.5 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwiftMacros/PropertyTestMacro.swift` (error handling)<br>`Tests/InvariantSwiftMacroTests/PropertyTestMacroTests.swift` (error tests) |
| **Example Output** | Clear error: "Unsupported type 'MyCustomType' for parameter 'x'. Provide generator via @PropertyTest(generators: [...])" |

### 3.8 Support multiple property definitions

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.8 |
| **Title** | Allow multiple @PropertyTest functions in same file |
| **Objective** | Enable test suites with multiple properties without conflicts |
| **Acceptance Criteria** | ✓ Multiple @PropertyTest functions in one file: each generates unique test<br>✓ Test names are unique (using function name as base)<br>✓ No conflicts or overwrites<br>✓ Example: 3 @PropertyTest functions → 3 @Test functions |
| **Dependencies** | 3.5 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Sources/InvariantSwiftMacros/PropertyTestMacro.swift` (name generation)<br>`Tests/InvariantSwiftMacroTests/PropertyTestMacroTests.swift` (test multiple) |
| **Example Output** | File with 3 @PropertyTest → generates 3 @Test __propertyTest_<name> functions |

### 3.9 Add configuration options to macro

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.9 |
| **Title** | Implement @PropertyTest configuration parameters |
| **Objective** | Allow users to customize test behavior via macro arguments |
| **Acceptance Criteria** | ✓ Support: @PropertyTest(examples: 5000, seed: 42, timeout: 10000)<br>✓ Pass config to PropertyRunner<br>✓ Document all options in macro comment<br>✓ Validate: examples > 0, timeout > 0, etc. |
| **Dependencies** | 3.5, 3.7 |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Sources/InvariantSwiftMacros/PropertyTestMacro.swift` (parse config)<br>`Sources/InvariantSwiftMacros/MacroConfiguration.swift` (new) |
| **Example Output** | @PropertyTest(examples: 5000) generates runner with 5000 examples |

### 3.10 Support custom generators in macro

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.10 |
| **Title** | Allow users to specify custom generators for types |
| **Objective** | Enable @PropertyTest to use custom generators registered in registry |
| **Acceptance Criteria** | ✓ @PropertyTest(generators: [User.self: customUserGen])<br>✓ Or: lookup from GeneratorRegistry<br>✓ Fall back to default if not specified<br>✓ Error handling for unmapped types |
| **Dependencies** | 3.9, 1.7 (generator registry) |
| **Effort** | Medium (3-4 hours) |
| **Files** | `Sources/InvariantSwiftMacros/PropertyTestMacro.swift` (custom generator support)<br>`Tests/InvariantSwiftMacroTests/PropertyTestMacroTests.swift` (test custom) |
| **Example Output** | @PropertyTest(generators: [User.self: testUserGen]) uses testUserGen for User parameters |

### 3.11 Create macro documentation

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.11 |
| **Title** | Write comprehensive @PropertyTest macro documentation |
| **Objective** | Help users understand and use the macro |
| **Acceptance Criteria** | ✓ Document: syntax, supported types, configuration options, examples<br>✓ Create: `docs/MACRO_GUIDE.md`<br>✓ Show: before/after, common patterns, limitations<br>✓ 5+ runnable examples |
| **Dependencies** | 3.1-3.10 |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/MACRO_GUIDE.md` (new) |
| **Example Output** | "Use @PropertyTest(examples: 1000) func test(a: Int) { ... } to generate 1000 test cases" |

### 3.12 Build macro examples and test suite

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.12 |
| **Title** | Create example @PropertyTest properties and test suite |
| **Objective** | Provide reference implementations and verify macro works end-to-end |
| **Acceptance Criteria** | ✓ Create 5+ example properties using @PropertyTest<br>✓ Examples cover: primitives, collections, custom types, async<br>✓ Place in: `docs/examples/macro_examples.swift`<br>✓ All examples compile and run |
| **Dependencies** | 3.11 |
| **Effort** | Small (2-3 hours) |
| **Files** | `docs/examples/macro_examples.swift` (new) |
| **Example Output** | Examples: testSorting, testStringReversal, testMapPreservesLength, etc. |

### 3.13 Performance test macro-generated code

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.13 |
| **Title** | Benchmark generated test code vs. manual implementation |
| **Objective** | Verify macro doesn't introduce performance overhead |
| **Acceptance Criteria** | ✓ Compare: macro-generated test vs. manual runner.run(property)<br>✓ Overhead should be <5% (test setup cost)<br>✓ Document in: `docs/MACRO_PERFORMANCE.md`<br>✓ Add to PerformanceTests |
| **Dependencies** | 3.5 |
| **Effort** | Small (2-3 hours) |
| **Files** | `Tests/PerformanceTests/MacroPerformanceTests.swift` (new)<br>`docs/MACRO_PERFORMANCE.md` (new) |
| **Example Output** | Macro-generated tests have <3% overhead vs. manual runner |

### 3.14 Run complete macro test suite

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.14 |
| **Title** | Verify all macro tests and examples pass |
| **Objective** | Ensure macro implementation is complete and correct |
| **Acceptance Criteria** | ✓ Run: `swift test Tests/InvariantSwiftMacroTests`<br>✓ All tests pass<br>✓ No warnings or errors<br>✓ Coverage: ≥99% for macro code |
| **Dependencies** | 3.6-3.13 |
| **Effort** | Small (1-2 hours) |
| **Files** | `Tests/InvariantSwiftMacroTests/` (all macro tests) |
| **Example Output** | "Tests passed: 42/42 (PropertyTestMacroTests, MacroExpansionTests, ...)" |

### 3.15 Commit @PropertyTest macro milestone

| Aspect | Details |
|--------|---------|
| **Task ID** | 3.15 |
| **Title** | Create final commit for Milestone 3 |
| **Objective** | Capture all macro implementation work |
| **Acceptance Criteria** | ✓ Commit message: "feat(macros): implement @PropertyTest macro for automatic test generation"<br>✓ Includes all changes from 3.1-3.14<br>✓ Push to epic/mvp branch |
| **Dependencies** | 3.14 |
| **Effort** | Small (1 hour) |
| **Files** | All files from 3.1-3.14 |
| **Example Output** | Commit: `def67890 "feat(macros): implement @PropertyTest macro for automatic test generation"` |

---

## Master Dependency Graph

```
Milestone 0: Naming & Public API
  └── [12 tasks: 0.1-0.12]
      ├── All depend on completion of previous tasks in sequence
      └── Final dependency: All tests pass (0.12)

Milestone 1: Core Generator & Shrinking
  └── [18 tasks: 1.1-1.18]
      ├── Depends on: Milestone 0 complete
      ├── Linear chain: 1.1 → 1.2 → 1.3 → 1.4 (performance foundation)
      ├── Parallel: 1.5-1.11 (composable generators, can work in parallel after 1.2)
      ├── Performance tuning: 1.12-1.16 (depends on full generator suite)
      └── Validation: 1.17-1.18 (depends on all generators)

Milestone 2: Swift Testing Integration
  └── [14 tasks: 2.1-2.14]
      ├── Depends on: Milestones 0-1 complete
      ├── Linear foundation: 2.1 → 2.2 → 2.3 (integration framework)
      ├── Features: 2.4-2.10 (depend on 2.2, can parallelize)
      ├── Documentation: 2.11-2.13 (depends on features complete)
      └── Validation: 2.14 (depends on all)

Milestone 3: @PropertyTest Macro
  └── [15 tasks: 3.1-3.15]
      ├── Depends on: Milestones 0-2 complete
      ├── Design phase: 3.1-3.2 (sequential)
      ├── Implementation: 3.3 → 3.4 → 3.5 (sequential)
      ├── Testing: 3.6-3.8 (depend on 3.5)
      ├── Features: 3.9-3.10 (depend on 3.5, can parallelize)
      ├── Documentation: 3.11-3.12 (depend on features)
      ├── Performance: 3.13 (depends on 3.5)
      └── Validation: 3.14-3.15 (depends on all)

MVP COMPLETE: Milestones 0-3 (54 total tasks)
  └── Provides: Stable public API, efficient property-based testing, Swift Testing integration, macro convenience

Extension Milestones (4-8):
  ├── Milestone 4: Process Isolation [12 tasks]
  ├── Milestone 5: CLI & Plugin [13 tasks]
  ├── Milestone 6: Model-Based Testing [14 tasks]
  ├── Milestone 7: Coverage-Guided Testing [16 tasks]
  └── Milestone 8: Invariant Mining [14 tasks]

Optional Milestone:
  └── Milestone 9: Advanced Features (if time permits)
```

### Critical Path Analysis

**Minimum Tasks to MVP (54):**
1. **Week 1-2**: Milestone 0 (12 tasks, ~40h)
2. **Week 2-4**: Milestone 1 (18 tasks, ~60h) - *Longest, performance-critical*
3. **Week 4-5**: Milestone 2 (14 tasks, ~45h)
4. **Week 5-6**: Milestone 3 (15 tasks, ~50h)

**Total MVP**: ~195 hours (≈5-6 weeks for 1 developer, ≈2-3 weeks for 2 developers in parallel)

---

## Task Execution Guidelines

### Batching & Parallelization

**Can parallelize within milestone** (after dependencies met):
- Milestone 1: Tasks 1.5-1.11 (generators) after 1.2 foundation
- Milestone 2: Tasks 2.4-2.10 (features) after 2.2 framework
- Milestone 3: Tasks 3.9-3.10 (configuration) after 3.5 code gen

**Must serialize** (dependencies required):
- All "0.1" tasks (sequential within M0)
- Generator foundation → Generator optimization → Shrinking
- Macro design → SwiftSyntax → Implementation → Testing

### Per-Task Workflow

For each task:
1. **Read** task specification and dependencies
2. **Prepare** environment (check build, understand current state)
3. **Implement** changes per acceptance criteria
4. **Test** with provided test suite
5. **Document** changes in DocC/markdown
6. **Commit** with conventional commit message
7. **Mark complete** in task tracking

### Definition of Done (Per Task)

- [ ] Code written and passing tests
- [ ] No compiler warnings or errors
- [ ] Code coverage ≥99% for new code
- [ ] Documentation updated/added
- [ ] Examples provided (if applicable)
- [ ] Commit message follows conventional commits
- [ ] PR/branch clean and ready to merge

---

## Example: Task 0.4 Execution

**Task**: Add DocC comments to all public APIs
**Dependencies**: 0.3 (template complete)

**Execution**:
```swift
// Before: public function with no docs
public func generate(size: Int) -> T { ... }

// After: fully documented
/// Generates a random value of type T.
/// - Parameter size: Controls the complexity of generated value (0-100).
/// - Returns: A randomly generated instance of T.
/// - Example: `let value = gen.generate(size: 10)`
public func generate(size: Int) -> T { ... }
```

**Acceptance Criteria Met**:
- ✓ All 80+ public symbols have DocC
- ✓ Examples compile (buildable from doctest)
- ✓ `swift build -Xswiftc -warnings-as-errors` succeeds
- ✓ Coverage ≥99%

**Commit**: `docs: add comprehensive DocC documentation to all public APIs`

---

## Next Steps

1. **Immediate** (This message): You now have complete task breakdown
2. **Next**: Choose execution strategy:
   - Single developer: Execute sequentially by milestone
   - Team: Assign roles and parallelize within constraints
3. **Per milestone**: Use this document to guide daily work

---

**Document Generated**: January 16, 2026
**Format**: Markdown (task breakdown with metadata)
**Total Tasks**: 124 granular sub-tasks
**Status**: Ready for implementation
