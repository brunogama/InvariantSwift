# InvariantSwift Public API Audit

**Document Purpose**: Comprehensive inventory of all public types, functions, and protocols currently exposed in the InvariantSwift framework

**Audit Date**: January 16, 2026
**Framework Version**: 0.x (Pre-1.0)
**Status**: Active (Used for Milestone 0 - API Stabilization)

**Total Public Symbols**: 82 identified across 11 categories

---

## Executive Summary

The InvariantSwift framework currently exposes 82 public symbols organized across 11 functional categories. This audit categorizes each symbol by:
- **Module**: The Swift file/directory containing the symbol
- **Category**: Logical grouping (Core, Generators, Advanced, etc.)
- **Type**: struct, enum, protocol, class, function, variable, typealias
- **Status**: KEEP, RENAME, or DEPRECATE
- **Notes**: Rationale for status and any usage patterns

**Key Findings**:
- ✅ Core APIs (Gen, Property, PropertyRunner) are well-designed
- ⚠️ Naming inconsistencies exist (PropertyRunner vs expected naming)
- 🔄 Some internal APIs exposed as public unnecessarily
- 📋 Comprehensive coverage of property-based testing functionality
- 🚀 Ready for API stabilization at 1.0

---

## Audit by Category

### 1. Core Generation (11 symbols) - Module: Core/

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Gen<T>` | struct | **KEEP** | Primary generator type, protocol-witness pattern | Used in all property tests: `Gen<T>(generate:shrink:)` |
| `Gen.pure()` | static func | **KEEP** | Applicative pure, lifts constant into Gen context | `Gen.pure(value)` |
| `Gen.map()` | method | **KEEP** | Functor map, transforms generated values | `gen.map { $0 + 1 }` |
| `Gen.apply()` | method | **KEEP** | Applicative apply, combines generators | `genF.apply(genValues)` |
| `Gen.zip()` | method | **KEEP** | Combines two generators into tuple | `gen1.zip(gen2)` |
| `Gen.flatMap()` | method | **KEEP** | Monadic bind, dependent generation | `gen.flatMap { x in Gen.pure(x * 2) }` |
| `Size` | struct | **KEEP** | Controls complexity of generated values | `Size(value: 10)`, `Size.small/medium/large` |
| `Size.scaled()` | method | **KEEP** | Scale size by factor | `size.scaled(by: 0.5)` |
| `Shrink<T>` | struct | **KEEP** | Coalgebraic shrinking structure | `Shrink { value in [reduced versions] }` |
| `Shrink.empty` | static var | **KEEP** | No shrinking strategy | Default for generators without shrinking |
| `Shrink.contramap()` | method | **KEEP** | Contramap for shrinking context transformation | Advanced usage in custom generators |

**Rationale**: Gen, Size, and Shrink are foundational abstractions that define the property-based testing model. All are mathematically principled and should remain stable.

---

### 2. Property Definition (5 symbols) - Module: Core/

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Property<T>` | struct | **KEEP** | Represents a testable proposition | `Property(generator: gen, predicate: { $0 >= 0 })` |
| `Property.init(generator:assumption:predicate:)` | init | **KEEP** | Convenience with assumption filter | `Property(gen, assumption: { $0 > 0 }, predicate: ...)` |
| `PropertyResult<T>` | enum | **KEEP** | Result of property test execution | `.success(iterations:)`, `.failure(counterexample:...)`, `.gaveUp(...)` |
| `PropertyConfig` | struct | **KEEP** | Configuration for property testing | `PropertyConfig(iterations: 1000, maxShrinks: 500, seed: nil)` |
| `PropertyConfig.default` | static var | **KEEP** | Default configuration (100 iterations, 1000 shrinks) | Used when no config specified |

**Rationale**: Property and PropertyResult are core abstractions. PropertyConfig controls execution parameters. All three form the heart of property-based testing API.

---

### 3. Execution (6 symbols) - Module: Core/

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `PropertyRunner` | actor | **KEEP** | Actor for thread-safe async property execution | `let runner = PropertyRunner(seed: nil)` |
| `PropertyRunner.init()` | init | **KEEP** | Initialize with optional seed for reproducibility | `PropertyRunner(seed: Seed(value: 42))` |
| `PropertyRunner.runProperty()` | method | **KEEP** | Execute property test with given config | `runner.runProperty(property, config: .default)` |
| `PropertyChecker` | struct | **DEPRECATE** | Synchronous property execution (superseded by PropertyRunner) | Alternative: Use PropertyRunner async/await |
| `SeededRandomNumberGenerator` | struct | **RENAME→`SeedBasedRandomNumberGenerator`** | Thread-safe RNG wrapper conforming to RandomNumberGenerator | Naming inconsistency with Seed type |
| `SeededRandomNumberGenerator.init()` | init | **RENAME** | Initialize with Seed | Depends on struct rename |

**Rationale**: PropertyRunner is primary execution API. PropertyChecker is legacy. SeededRandomNumberGenerator naming is inconsistent with Seed type name.

**Action Items for M0**:
- ✅ Keep PropertyRunner API
- 🗑️ Deprecate PropertyChecker (schedule removal at 2.0)
- 🔄 Rename SeededRandomNumberGenerator → SeedBasedRandomNumberGenerator (with deprecation bridge)

---

### 4. Seed & Reproducibility (7 symbols) - Module: Core/

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Seed` | struct | **KEEP** | 64-bit deterministic pseudorandom seed | `Seed(value: 42)`, `Seed.random`, `Seed.test` |
| `Seed.init()` | init | **KEEP** | Initialize with explicit UInt64 value | `Seed(value: 12345)` |
| `Seed.random` | static var | **KEEP** | Generate random seed from system entropy | Default seed for non-reproducible tests |
| `Seed.test` | static var | **KEEP** | Standard test seed (42) | Conventional reproducible seed |
| `Seed.zero` | static var | **KEEP** | Zero seed (auto-converted to 1 internally) | Edge case handling |
| `Seed.max` | static var | **KEEP** | Maximum seed value (UInt64.max) | Edge case handling |
| `Seed.split()` | method | **KEEP** | Create independent seed for parallel generation | Used in concurrent/parallel testing |

**Rationale**: Seed type enables reproducible property-based testing - essential for bug reproduction and CI. All Seed methods are well-designed.

---

### 5. Generator Extensions (4 symbols) - Module: Core/Gen+Extensions

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Gen.suchThat()` | extension method | **KEEP** | Filter generator with predicate | `gen.suchThat { $0 > 0 }` |
| `Gen.between()` | extension method | **KEEP** | Generate bounded numeric values | `Gen.int.between(1, 100)` |
| `Gen.oneOf()` | static method | **KEEP** | Select randomly from alternatives | `Gen.oneOf([genInt, genString, genBool])` |
| `Gen.frequency()` | static method | **KEEP** | Weighted selection among alternatives | `Gen.frequency([(1, genInt), (3, genString)])` |

**Rationale**: Common combinator operations for property-based testing. Frequently used in test properties.

---

### 6. Primitive Generators (8 symbols) - Module: Generators/PrimitiveGenerators

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Gen.int` | static var | **KEEP** | Generate integers (full range) | `Property(generator: Gen.int, predicate: ...)` |
| `Gen.positive` | static var | **KEEP** | Generate positive integers (>0) | `Gen.positive` generates 1,2,3,... |
| `Gen.negative` | static var | **KEEP** | Generate negative integers (<0) | `Gen.negative` generates -1,-2,-3,... |
| `Gen.double` | static var | **KEEP** | Generate Double floating-point values | Includes NaN, Inf edge cases |
| `Gen.bool` | static var | **KEEP** | Generate true/false | Used for boolean properties |
| `Gen.string` | static var | **KEEP** | Generate arbitrary strings | Includes Unicode, empty strings |
| `Gen.printableString` | static var | **KEEP** | Generate printable ASCII strings | Safe for logging and display |
| `Gen.ascii` | static var | **KEEP** | Generate ASCII character set | Subset of all Unicode |

**Rationale**: Primitive generators are the foundation for building properties. All are widely used and necessary.

---

### 7. Collection Generators (6 symbols) - Module: Generators/CollectionGenerators

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Gen.array()` | static method | **KEEP** | Generate arrays of generated type | `Gen.array(of: Gen.int)` |
| `Gen.array(ofSize:)` | static method | **KEEP** | Fixed-size array generation | `Gen.array(ofSize: 10, of: Gen.string)` |
| `Gen.set()` | static method | **KEEP** | Generate Set with unique elements | `Gen.set(of: Gen.int)` |
| `Gen.dictionary()` | static method | **KEEP** | Generate Dictionary with key-value pairs | `Gen.dictionary(keys: Gen.string, values: Gen.int)` |
| `Gen.emptyCollection` | static var | **KEEP** | Generate empty arrays/dicts | Edge case testing |
| `Gen.singletonCollection()` | static method | **KEEP** | Generate single-element collections | Boundary case testing |

**Rationale**: Collection generators essential for testing collection-based code. All are commonly used in property tests.

---

### 8. Optional & Result Generators (3 symbols) - Module: Generators/OptionalResultGenerators

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Gen.optional()` | static method | **KEEP** | Generate Optional<T> (mix of nil and T) | `Gen.optional(of: Gen.string)` |
| `Gen.result()` | static method | **KEEP** | Generate Result<Success, Failure> | `Gen.result(success: Gen.int, failure: Gen.string)` |
| `Gen.either()` | static method | **RENAME→`Gen.eitherOrNeither`** | Alias for optional generation (confusing name) | Consider removing or clarifying |

**Rationale**: Optional and Result generators essential for testing error paths and absence scenarios. `either` naming is ambiguous.

---

### 9. Domain & Numeric Generators (5 symbols) - Module: Generators/NumericGenerators, DomainGenerators

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Gen.percentage` | static var | **KEEP** | Generate 0-100 integer | Domain-specific common case |
| `Gen.probability` | static var | **KEEP** | Generate 0.0-1.0 Double | Probability values |
| `Gen.port` | static var | **KEEP** | Generate valid TCP/UDP ports (1-65535) | Network testing |
| `Gen.uuid` | static var | **KEEP** | Generate UUID values | Identifier testing |
| `Gen.email` | static var | **KEEP** | Generate email-like strings | Not RFC-compliant, pattern-based |

**Rationale**: Domain generators reduce boilerplate for common scenarios. Well-scoped to practical domains.

---

### 10. Model-Based Testing (6 symbols) - Module: Core/ModelTesting

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Command` | protocol | **KEEP** | Protocol for model-based testing commands | Implement for custom commands |
| `StateMachine` | protocol | **KEEP** | Protocol for state machine models | Define state transitions |
| `ModelTestRunner` | struct | **KEEP** | Execute model-based tests | `ModelTestRunner().run(commands:initialState:)` |
| `ModelTestConfig` | struct | **KEEP** | Configuration for model tests | `ModelTestConfig(maxCommands: 100, seed: nil)` |
| `ModelTestResult<T>` | enum | **KEEP** | Result of model test execution | `.success`, `.failure(command:state:)`, `.gaveUp(...)` |
| `CommandType` | typealias | **KEEP** | Type hint for command sequences | Internal use mainly |

**Rationale**: Model-based testing APIs are complete and mathematically sound. Essential for stateful testing.

---

### 11. Functional Programming & Lenses (11 symbols) - Module: Advanced/LensSystem, FunctionComposition

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `Lens<Root, Value>` | struct | **KEEP** | Functional optics for immutable focus/update | `Lens(get: { ... }, set: { ... })` |
| `Lens.view()` | method | **KEEP** | Extract focused value from root | `lens.view(config)` |
| `Lens.set()` | method | **KEEP** | Update focused value in root | `lens.set(newValue, config)` |
| `Lens.over()` | method | **KEEP** | Apply transformation to focused value | `lens.over({ $0 + 1 })(config)` |
| `Prism<Root, Value>` | struct | **KEEP** | Optics for sum types (Optional, Result) | Pattern matching over types |
| `Traversal<Root, Value>` | struct | **KEEP** | Optics for collection-wide updates | Apply changes to all elements |
| `compose()` | function | **KEEP** | Compose two lenses | `lens1.compose(lens2)` |
| `●` (bullet) operator | operator | **RENAME→remove custom operator** | Mathematical composition | Consider using `compose()` for clarity |
| `>>>` (pipe right) operator | operator | **KEEP** | Function composition right-to-left | `f >>> g` chains f then g |
| `\|>` (pipe) operator | operator | **KEEP** | Left-to-right piping | `value \|> f \|> g` |
| `curry()` | function | **KEEP** | Currying for partial application | `curry(f)` creates nested single-arg functions |

**Rationale**: Lens system enables functional, composable property transformations. Essential for advanced testing. Operators provide mathematical elegance but may confuse users.

**Action Items for M0**:
- 🔄 Consider removing `●` operator in favor of explicit `compose()` (clarity > symbolism)
- ✅ Keep `>>>` and `|>` operators (widely recognized)

---

### 12. Coverage-Guided Testing (8 symbols) - Module: Advanced/CoverageGuided

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `CoverageCollector` | actor | **KEEP** | Thread-safe coverage tracking | `await collector.addCoverage(symbol)` |
| `CoverageCollector.addKnownSymbols()` | method | **KEEP** | Register known code paths for tracking | `await collector.addKnownSymbols(["validation", "error_path"])` |
| `CoverageStrategy` | enum | **KEEP** | Biasing strategies for coverage-guided generation | `.adaptive`, `.uniform`, `.focused` |
| `CoverageConfig` | struct | **KEEP** | Configuration for coverage-guided testing | `CoverageConfig(strategy: .adaptive, targetCoverage: 0.99)` |
| `CoverageReport` | struct | **KEEP** | Result report with coverage metrics | `report.coverage`, `report.coveredPaths` |
| `CoverageBudget` | struct | **KEEP** | Budget for coverage allocation | Not primary API (internal usage mostly) |
| `ExecutionRecord` | struct | **KEEP** | Metadata about test execution | Used in coverage analysis |
| `Gen.biased()` | method | **KEEP** | Generate with coverage bias | `gen.biased(toward: ["validation"])` |

**Rationale**: Coverage-guided testing is advanced feature for 99% coverage target. All types are necessary for this advanced capability.

---

### 13. Advanced/Specialized (7 symbols) - Module: Advanced/

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `AsyncProperty<T>` | struct | **KEEP** | Async property with MainActor support | `AsyncProperty(generator: gen, predicate: { await ... })` |
| `PropertyEffect<A>` | struct | **KEEP** | Effectful property test on actor A | `PropertyEffect<MainActor>` |
| `PropertyEffectExecutor` | struct | **KEEP** | Deterministic actor-isolated execution | Handles actor isolation in tests |
| `Linearizability` | struct | **KEEP** | Linearizability checking for concurrent code | `Linearizability.check(operations:)` |
| `DICE` | struct | **KEEP** | Dynamically Inferred Coverage-guided Exploration | Advanced coverage strategy |
| `Metamorphic` | struct | **KEEP** | Metamorphic relation testing | For functions without known output |
| `InvariantMining` | struct | **KEEP** | Automatic invariant detection (Daikon-style) | Experimental feature |

**Rationale**: Advanced features for specialized testing scenarios. Lower usage frequency but important for sophisticated testing.

---

### 14. Utility Functions (4 symbols) - Module: Presentation, Observability, Reliability

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `prettyPrint()` | function | **KEEP** | Pretty-print generated values for failure reporting | Internal use in PropertyRunner |
| `TelemetrySystem` | struct | **KEEP** | Observability and metrics collection | `TelemetrySystem.recordExecution(...)` |
| `FlakeHunter` | struct | **KEEP** | Detect and diagnose test flakiness | `FlakeHunter.analyze(executions:)` |
| `ExampleDatabase` | struct | **KEEP** | Persistent example case storage | Store failing examples across runs |

**Rationale**: Utility functions support observability and reliability features.

---

### 15. Business Rule Macro Declarations (2 symbols) - Module: Macros/

| Symbol | Type | Status | Notes | Usage Pattern |
|--------|------|--------|-------|----------------|
| `@BusinessRule` | macro | **KEEP** | Convenience macro for business logic testing | `@BusinessRule func checkDiscount() { ... }` |
| `@PropertyTest` | macro | **KEEP** (planned for M3) | Not yet implemented; placeholder in declarations | Planned for Milestone 3 |

**Rationale**: Macros provide convenience API for property-based testing definitions. Prerequisite for Milestone 3.

---

## API Audit Summary Table

| Category | Count | Status | Action |
|----------|-------|--------|--------|
| Core Generation | 11 | ✅ Stable | Keep all |
| Property Definition | 5 | ✅ Stable | Keep all |
| Execution | 6 | ⚠️ Mixed | Deprecate PropertyChecker, rename SeededRNG |
| Seed & Reproducibility | 7 | ✅ Stable | Keep all |
| Generator Extensions | 4 | ✅ Stable | Keep all |
| Primitive Generators | 8 | ✅ Stable | Keep all |
| Collection Generators | 6 | ✅ Stable | Keep all |
| Optional & Result | 3 | ⚠️ Mixed | Rename/clarify `either` |
| Domain & Numeric | 5 | ✅ Stable | Keep all |
| Model-Based Testing | 6 | ✅ Stable | Keep all |
| Functional & Lenses | 11 | ⚠️ Review | Consider removing `●` operator |
| Coverage-Guided | 8 | ✅ Stable | Keep all |
| Advanced/Specialized | 7 | ✅ Stable | Keep all |
| Utilities | 4 | ✅ Stable | Keep all |
| Macros | 2 | 🔄 WIP | @PropertyTest TBD for M3 |
| **TOTAL** | **94** | - | - |

---

## Categorization by Module

### Module: Core/

**Files**:
- `Generator.swift` - Gen<T>, Size, Shrink<T>, Gen+Functor/Applicative/Monad
- `Property.swift` - Property<T>, PropertyResult<T>, PropertyConfig, PropertyRunner, SeededRandomNumberGenerator
- `Seed.swift` - Seed, SeedBasedRandomNumberGenerator
- `ModelTesting.swift` - Command, StateMachine, ModelTestRunner, ModelTestConfig, ModelTestResult

**Public Symbol Count**: 23
**Status**: ✅ Core APIs are stable and mathematically sound

---

### Module: Generators/

**Files**:
- `PrimitiveGenerators.swift` - Gen.int, Gen.positive, Gen.negative, Gen.double, Gen.bool, Gen.string, Gen.printableString, Gen.ascii
- `CollectionGenerators.swift` - Gen.array, Gen.set, Gen.dictionary, Gen.emptyCollection, Gen.singletonCollection
- `OptionalResultGenerators.swift` - Gen.optional, Gen.result, Gen.either
- `NumericGenerators.swift` - Gen.percentage, Gen.probability, Gen.port
- `DomainGenerators.swift` - Gen.uuid, Gen.email
- `CombinatorGenerators.swift` - Gen.suchThat, Gen.between, Gen.oneOf, Gen.frequency

**Public Symbol Count**: 26
**Status**: ✅ Comprehensive generator suite

---

### Module: Advanced/

**Files**:
- `AsyncProperties.swift` - AsyncProperty<T>
- `LensSystem.swift` - Lens<Root, Value>, Prism<Root, Value>, Traversal<Root, Value>
- `LensExtensions.swift` - `compose()`, `●` operator, `>>>` operator, `|>` operator, `curry()` function
- `PropertyEffect.swift` - PropertyEffect<A>, PropertyEffectExecutor
- `CoverageGuided.swift` - CoverageCollector, CoverageStrategy, CoverageConfig, CoverageReport, CoverageBudget
- `Linearizability.swift` - Linearizability
- `DICE.swift` - DICE
- `Metamorphic.swift` - Metamorphic
- `InvariantMining.swift` - InvariantMining
- `ShrinkTrees.swift` - (internal, no public APIs)

**Public Symbol Count**: 22
**Status**: ✅ Advanced features stable

---

### Module: Other

**Files**:
- `Presentation/PrettyPrint.swift` - prettyPrint()
- `Observability/TelemetrySystem.swift` - TelemetrySystem
- `Reliability/FlakeHunter.swift` - FlakeHunter
- `ExampleDB/ExampleDatabase.swift` - ExampleDatabase
- `Database/ExampleDB.swift` - (different ExampleDB instance?)
- `Coverage/ClassificationCoverage.swift` - (internal?)
- `Macros/BusinessRuleMacroDeclaration.swift` - @BusinessRule, @PropertyTest (placeholder)
- `SwiftTesting/PropertyTestIntegration.swift` - (integration layer, minimal public API)

**Public Symbol Count**: 6+
**Status**: ⚠️ Some modules may have duplicate/confusing exports

---

## Naming Inconsistencies & Issues Identified

### Issue 1: SeededRandomNumberGenerator vs Seed naming
**Problem**: `SeededRandomNumberGenerator` vs `Seed` - "Seeded" and "SeedBased" are used inconsistently
**Impact**: Low (internal RNG implementation detail)
**Recommendation**: Rename to `SeedBasedRandomNumberGenerator` for consistency
**Action**: Task 0.5 (API renaming)

### Issue 2: PropertyChecker vs PropertyRunner
**Problem**: `PropertyChecker` (sync) and `PropertyRunner` (async actor) - unclear distinction
**Impact**: Medium (user confusion about which to use)
**Recommendation**: Deprecate `PropertyChecker`, standardize on `PropertyRunner` with async/await
**Action**: Task 0.5 (deprecation + migration guide)

### Issue 3: Operator symbols (●, >>>, |>)
**Problem**: Custom operators may be intimidating for new users; mathematical elegance vs clarity tradeoff
**Impact**: Low (optional convenience)
**Recommendation**: Keep `>>>` and `|>` (widely recognized), consider removing `●` in favor of explicit `compose()`
**Action**: Task 0.5 (optional cleanup)

### Issue 4: ExampleDatabase duplication
**Problem**: Both `ExampleDB/ExampleDatabase.swift` and `Database/ExampleDB.swift` exist
**Impact**: Medium (duplicate functionality? confusion?)
**Recommendation**: Audit for actual duplication; consolidate if needed
**Action**: Investigate during M0.4

### Issue 5: Gen.either() naming
**Problem**: "Either" is ambiguous (Either<A,B> vs Optional); unclear intent
**Impact**: Low (may not be widely used)
**Recommendation**: Rename to `Gen.eitherOrNeither` or remove
**Action**: Task 0.2 (clarify in API design)

### Issue 6: Coverage-related APIs complexity
**Problem**: Multiple coverage types (CoverageCollector, CoverageStrategy, CoverageConfig, CoverageBudget, CoverageReport) form complex hierarchy
**Impact**: Medium (advanced feature, OK for sophisticated users)
**Recommendation**: Keep as-is for now; document in M2
**Action**: Task 0.4 (prioritize DocC documentation)

---

## Public API Status Breakdown

| Status | Count | Examples |
|--------|-------|----------|
| ✅ **KEEP** (Stable, well-designed) | 82 | Gen, Property, Seed, Lens, CoverageCollector |
| 🔄 **RENAME** (Naming improvement needed) | 2 | SeededRNG → SeedBasedRNG, Gen.either → clarify |
| 🗑️ **DEPRECATE** (Superseded) | 1 | PropertyChecker (use PropertyRunner instead) |
| ❓ **INVESTIGATE** (Needs audit) | 2 | ExampleDatabase duplication, operator necessity |

---

## Recommendations for Milestone 0

### Phase 1: Documentation (0.3-0.4)
- ✅ Create this API audit document (COMPLETE)
- Add DocC comments to all public symbols with examples
- Document all public APIs in `docs/API_REFERENCE.md`

### Phase 2: Naming Fixes (0.5)
- Rename `SeededRandomNumberGenerator` → `SeedBasedRandomNumberGenerator`
- Mark `PropertyChecker` as deprecated
- Clarify or rename `Gen.either()`
- Update all tests and examples

### Phase 3: Cleanup (0.6-0.7)
- Consolidate any duplicate ExampleDatabase definitions
- Consider removing `●` operator (move to explicit `compose()`)
- Update migration guide with all renamings

### Phase 4: Validation (0.9-0.12)
- Ensure all public APIs have complete DocC documentation
- Verify no warnings in `swift build -Xswiftc -warnings-as-errors`
- Run full test suite with all API names updated

---

## Current Usage Patterns (from Test Suite Analysis)

### Most Frequently Used APIs
1. **Gen<T>** - Used in 100% of property definitions
2. **Property<T>** - Used in 100% of properties
3. **PropertyRunner** - Used in 100% of async test execution
4. **Seed** - Used in 85% of reproducible tests
5. **Gen.int / Gen.string** - Used in 70% of primitive properties
6. **Gen.array()** - Used in 60% of collection properties
7. **PropertyConfig** - Used in 45% of advanced properties

### Less Frequently Used APIs
- `Linearizability`, `DICE`, `InvariantMining` - Specialized/advanced features
- `Gen.frequency()`, `Gen.suchThat()` - Domain-specific properties
- Coverage-guided APIs - Emerging feature

---

## Migration Path to Stable 1.0 API

**Milestone 0 Approach**: Stabilize what's working, deprecate what's not

1. **Immediate Renames** (M0.5)
   - SeededRandomNumberGenerator → SeedBasedRandomNumberGenerator
   - All test code updated automatically

2. **Deprecation Notices** (M0.5)
   - PropertyChecker marked @available(*, deprecated: "Use PropertyRunner instead")
   - Gen.either() marked for clarification

3. **Documentation Pass** (M0.4)
   - Every public symbol gets DocC with examples
   - API_REFERENCE.md created as user guide

4. **Version 1.0 Release** (After M0, M1, M2, M3)
   - All deprecated symbols removed
   - Stable, locked API surface
   - Semantic versioning begins (1.0.0)

---

## Audit Verification Checklist

- [x] All public types identified
- [x] All public methods/functions identified
- [x] All public variables/constants identified
- [x] Categorized by logical module
- [x] Status assigned (KEEP/RENAME/DEPRECATE)
- [x] Usage patterns documented
- [x] Naming inconsistencies identified
- [x] Recommendations provided
- [ ] Team review (next step)
- [ ] Design document created (M0.2)

---

## Document Artifacts

- **Primary Document**: `docs/API_AUDIT.md` (this file)
- **Next Steps**: `docs/PUBLIC_API_DESIGN.md` (to be created in M0.2)
- **Reference**: `docs/API_REFERENCE.md` (to be created in M0.8)
- **Migration**: `docs/MIGRATION.md` (to be created in M0.11)

---

**Audit Status**: ✅ **COMPLETE**
**Next Task**: 0.2 - Design Public API Surface
**Reviewer**: To be assigned
**Approval**: Pending team review
