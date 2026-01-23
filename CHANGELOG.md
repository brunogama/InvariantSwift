# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Codebase Mapping Documentation** in `.planning/codebase/`:
  * STACK.md - Technology stack and dependencies (Swift 6.0+, SwiftSyntax 602.0.0, swift-custom-dump)
  * ARCHITECTURE.md - System design and component interactions (Generator, Property, ShrinkTree, Macros)
  * STRUCTURE.md - Directory layout and naming conventions (6 library targets, 2 executables, 7 test targets)
  * CONVENTIONS.md - Code style and patterns (Google Swift Style, strict concurrency, actor isolation)
  * TESTING.md - Test framework and patterns (Swift Testing, 99%+ coverage target, macro expansion tests)
  * INTEGRATIONS.md - External dependencies analysis (self-contained library, SQLite3, os.log)
  * CONCERNS.md - Technical debt and known issues (force unwraps, 16 disabled tests, large files)
- **JSON Report Schema for CI/CD Integration** (ISP-0008):
  * `RunReport` struct with versioned schema (v1) for machine-readable test outputs
  * Test outcome enum: `.success`, `.failed`, `.gaveUp`
  * `RunStatistics` with iteration counts, timings, and shrink steps
  * `FailureDetails` with replay tokens, counterexamples, and optional shrink traces
  * Factory methods: `RunReport.from(PropertyResult)` and `RunReport.from(ClassifyingPropertyResult)`
  * JSON I/O methods: `toJSON()`, `fromJSON()`, `writeJSON()`, `readJSON()`
  * Complete CI integration guide in `docs/JSON_REPORTS.md`
  * Examples for GitHub Actions, GitLab CI, Jenkins parsing
- Floating-point generation with configurable modes (GEN-FLOAT-001):
  * `FloatingPointMode` enum: `.finiteOnly`, `.allowInfinity`, `.allowNaN`
  * Default generators produce finite values only for predictable behavior
  * Deterministic shrinking that converges to 0 monotonically (SHRINK-FLOAT-001)
  * `FloatingPointTolerance` helpers for approximate comparisons (`.absolute()`, `.relative()`, `.ulp()`)
  * Comprehensive cross-platform determinism tests
- Crash isolation for property tests on macOS via subprocess execution (CORE-CRASH-001)
- SubprocessIsolation.swift with IPC protocol for safe inter-process communication
- PropertyTestHelper executable target for isolated test execution
- AnyCodable for type-erased test input serialization
- IsolatedPropertyRunner with real subprocess support on macOS (fallback to in-process on other platforms)
- Integration tests for fatalError isolation and parent process survival
- Comprehensive documentation in docs/CRASH_ISOLATION.md
- Collection shrinking v2 (SHRINK-COLL-001): delta-debugging chunk removal strategy for arrays and dictionaries
- Deterministic shrinking: hash-based key sorting for dictionaries ensures reproducible shrink sequences
- `CollectionShrinkingV2Tests`: comprehensive test coverage for chunk removal and determinism
- `CollectionShrinkingBenchmarks`: performance benchmarks for small/medium/large collections

### Changed
- Array shrinking now uses two-phase strategy: chunk removal (O(log n)) before element shrinking (O(n²))
- Dictionary shrinking uses sorted key-value pairs for deterministic candidate ordering
- Updated shrinking documentation to reflect delta-debugging strategy and performance characteristics

### Fixed
- Package.swift type-checking timeout by splitting large initialization into helper variables


### Added
- AsyncProperty<T> type for properties with async predicates
- AsyncThrowingProperty<T> type for properties with async predicates that can throw
- PropertyRunner.runAsyncProperty for executing async properties with shrinking
- PropertyRunner.runAsyncThrowingProperty for executing async throwing properties
- ShrinkTree.findMinimalAsync for async BFS shrinking support
- Comprehensive test coverage for async and throwing property scenarios

### Added
- **Automated Documentation Generation System**:
  * `check_docs.py` - Enhanced DocC coverage analysis with JSON reports and threshold enforcement
  * `Scripts/generate_architecture_diagrams.py` - Mermaid diagram generation from Package.swift
  * `Scripts/generate_api_reference.py` - Public symbol extraction and markdown API reference
  * `Scripts/validate_doc_examples.py` - Code example validation with syntax checking
  * `.github/workflows/docs-check.yml` - CI workflow for documentation enforcement
  * Makefile targets: `doc-check`, `doc-diagrams`, `doc-api`, `doc-examples`, `docs-gen`, `docs-validate`
- **OpenSpec Proposals**:
  * `add-diff-engine` - Proposal for stable, readable diff output in failure reports (Strings, Collections, Reflection)
- **Documentation Tutorials**:
  * `docs/FUZZING.md` - LibFuzzer integration guide (FuzzTarget, FuzzDataProvider, crash detection)
  * Linearizability Testing section in ADVANCED.md (Wing-Gong algorithm, concurrent data structures)
  * Contract Testing section in ADVANCED.md (Equatable/Comparable contracts, pre/postconditions)
  * Regression Banking section in ADVANCED.md (failure persistence, replay, CI integration)
  * Lens and Prism Optics tutorial in ADVANCED.md (lens laws, prism extraction, traversals)
  * Expanded Metamorphic Testing in COOKBOOK.md (relations, discovery engine, ML/AI testing)
- `docs/QUICKSTART.md` - 10-minute quick start guide for new developers
- **PropertyResult Enhancements** (Phase 1):
  * `isGaveUp` computed property for consistency with `isSuccess`/`isFailure`
  * `iterationCount` computed property to extract iteration count from any result case
  * `toExitCode()` method returning CLI exit codes (0=success, 1=failure, 2=gaveUp)
  * `shortDescription` for concise log output
  * `CustomStringConvertible` conformance with rich human-readable descriptions
- **Property Combinators** (Phase 1):
  * `mapPredicate(_:)` - transform predicate while keeping generator
  * `mapGenerator(_:)` - transform generator while keeping predicate
  * `filter(_:)` - alias for suchThat assumption filtering
  * `label(_:)` - attach descriptive labels for failure messages
  * `LabeledProperty<T>` struct for labeled property wrapper
- **PropertyConfig Enhancements** (Phase 1):
  * `timeout: TimeInterval?` for per-iteration timeout
  * `verbosity: Verbosity` enum (`.silent`, `.normal`, `.verbose`)
- **Dogfooding Tests** (Phase 2):
  * Failure reporting tests (ReproString parsing, seed reproducibility)
  * Generator distribution tests (oneOf fairness, frequency weights, optional nil/value)
  * Async property shrinking verification
- Async property support in @Property macro:
  * Detects async functions and generates `async throws` test methods
  * Uses `runPropertyAsync()` for async property execution
  * New `runPropertyAsync<T: Sendable>()` runtime function

### Tests
- Added async property macro tests
- Added constraint parsing tests for @Arbitrary macro

### Changed
- PropertyConfig now includes verbose parameter with default false

- Comprehensive documentation suite:
  * API_REFERENCE.md - Complete reference for all public types
  * COOKBOOK.md - Practical recipes for common testing scenarios
  * GENERATORS.md - Generator primitives, collections, and combinators
  * SHRINKING.md - Automatic counterexample minimization guide
  * ADVANCED.md - Coverage-guided, model-based, DICE, SMT features
  * PRETTY_PRINTING.md - Diff-based assertions documentation
  * Updated QUICKSTART.md with step-by-step tutorials
- Diff-based assertions for Swift Testing integration:
  * `expectNoDifference()` - Detailed diff output on equality failure
  * `expectDifference()` - Assert value changes as expected (sync and async)
  * `DiffFormat` struct with `.default` (ASCII) and `.proportional` (Unicode)
  * `ObjectTracker` for cycle detection in reference types
  * `StructuredDiff.collapsed()` for collection diff summary
- Per-field shrinking for @Arbitrary macro - each struct field shrinks independently
- `Shrink.automatic` static property for default no-op shrinking strategy
- `Shrink.towards(_:)` static function for target-based shrinking
- `GeneratorInference.inferShrink(for:)` for deriving shrink from generator type

### Fixed
- Fix plugin deprecation warnings for Swift 6.0 URL APIs (.path -> .url, .directory -> .directoryURL)
- Remove fatalError calls from production code paths:
  - PropertyEffect: Replace fatalError contramap with safe contramapWith method
  - ShrinkTrees: Change element(), filter(), oneOf(), frequency() to return optional instead of crashing
- Apply formatting and lint fixes across modified files

### Changed
- Property API enhanced with improved documentation and safer patterns

### Tests
- Add PropertyMacroIntegrationTests with 18 integration tests validating macro runtime behavior
- Test coverage for property execution, generator inference, failure detection, seed determinism

### Added
- Property-based testing framework for Swift
- Core generator system with integrated shrinking
- Mathematical law verification system
- Coverage-guided testing with 99% target
- Swift 6 concurrency support with async properties
- Macro system for automatic test generation (@PropertyTest)
- Integration with Swift Testing framework
- Advanced features: lens system, DICE, SMT solver support
- Comprehensive test suite with performance benchmarks
- CLI tool (`functest`) for property-based testing
- Swift Package Manager plugin integration
- CodeRabbit automated code review configuration with Swift-specific optimizations
- Comprehensive architecture documentation suite:
  * InvariantSwift-architecture.md (37 KB, 18 sections, 13 diagrams, 6 ADRs)
  * SHARDING-GUIDE.md for team-distributed ownership
  * README.md navigation hub for documentation suite
  * sections/ directory with pre-sharded architecture sections (17 files + index)
- Developer onboarding and quick start guides:
  * ONBOARDING.md (1,297 lines) - Complete developer onboarding guide
  * QUICKSTART.md (158 lines) - 10-minute quick start guide
  * README_IMPROVEMENTS.md (359 lines) - README improvement analysis
  * .claude/commands/tools/onboarding.md - Onboarding analysis template
- Comprehensive roadmap task breakdown:
  * ROADMAP_TASK_BREAKDOWN.md (124 granular sub-tasks across 9 milestones)
  * Complete task metadata: IDs, titles, objectives, acceptance criteria, dependencies, effort estimates, file references
  * Master dependency graph showing task sequencing and critical path
  * 54 MVP tasks (Milestones 0-3: Naming, Core Generator, Swift Testing, @PropertyTest)
  * 70 extension tasks (Milestones 4-9: Process Isolation, CLI, Model-Based, Coverage-Guided, Invariant Mining)
- Milestone 0: API Stabilization work begins
  * API_AUDIT.md (503 lines) - Complete audit of 82 public symbols across 11 categories
    - Identifies KEEP/RENAME/DEPRECATE status for all public APIs
    - Naming inconsistencies documented and recommendations provided
    - Usage patterns analyzed from test suite
  * PUBLIC_API_DESIGN.md (837 lines) - Production-ready API design
    - 4-module organization (Core, Generators, Advanced, Observability)
    - Namespace structure and protocol hierarchy specified
    - Naming standards and stability commitments documented
    - Pre-1.0 breaking change strategy (no deprecation bridges needed)
    - Ready for team review and approval before implementation
  * API_DOCUMENTATION_TEMPLATE.md (412 lines) - Comprehensive documentation standard
    - Required DocC elements for every public symbol
    - Category-specific templates (protocols, structs, enums, functions, operators)
    - Mathematical/functional programming API guidelines
    - Async properties and model-based testing documentation patterns
    - Compliance validation checklist for all 82 symbols
    - Examples of good vs. bad documentation
  * CLAUDE.md updated with "Documentation Guidelines" section
    - DocC standards and requirements (Milestones 0.3-0.4)
    - Documentation compliance rules and validation procedures
    - Building and validating DocC documentation
    - Functional programming concept documentation standards
  * Task 0.4: Add comprehensive DocC comments to all 82 public APIs
    - Core module (26 symbols): Gen<T>, Size, Shrink, Property, PropertyResult, PropertyConfig, PropertyRunner, Seed, SeedBasedRandomNumberGenerator
    - Generators module (26 symbols): Primitive (int, double, string, etc.), Collection (array, set, dictionary), Optional/Result, Domain (uuid, email, port), Combinators (oneOf, frequency, etc.)
    - Advanced module (11 symbols): Lens, Prism, Traversal, CoverageCollector, CoverageStrategy
    - SwiftTesting integration (6+ symbols): @PropertyTest macro, PropertyTestResult, async property support
    - Observability, Coverage, Model-Based Testing: Full DocC documentation
    - Every symbol documented with: summary, discussion, parameters, returns, throws, examples, notes, cross-references
    - All examples compile without warnings
    - Mathematical foundations documented for functional programming APIs (functor laws, monads, lenses)
    - External references included for complex concepts

### Changed
- Remove swift-docs-generation pre-commit hook
- Clean up duplicate Swift format configuration files
- Add Claude Code development workflow configuration
- **Migrate main library target from FunctionalTesting to InvariantSwift**
- Reorganize source files from FunctionalTesting/ to InvariantSwift/
- Reorganize test files from FunctionalTestingTests/ to FunctionalTesting/

### Deprecated
- N/A (initial release)

### Removed
- ClassificationCoverage.swift (obsolete coverage file)

### Fixed
- Clean up duplicate content in CodeRabbit configuration file
- Fix compilation errors in DICE.swift, Seed.swift, CombinatorGenerators.swift (isEmpty checks)
- Fix generic parameter naming collision in ModelTesting.swift (Command → CommandType)
- Fix FuncTestCLI/main.swift: actor-isolated method calls, Property API usage, RandomNumberGenerator types
- Fix Package.swift to exclude LawGeneration.swift.disabled file
- Ensure Swift 6 strict concurrency compliance across all targets
- Apply linter corrections for code style consistency

### Security
- N/A (initial release)

## [1.0.0] - 2025-09-12

### Added
- Initial release of FunctionalTesting framework
- Complete property-based testing framework with advanced features
- Core property testing with generators and shrinking
- Mathematical law verification and model-based testing
- Coverage-guided testing with 99% target
- Swift 6 concurrency support with async properties
- Macro system for automatic test generation
- Integration with Swift Testing framework
- Advanced features: lens system, DICE, SMT solver support
- Comprehensive test suite with performance benchmarks

[Unreleased]: https://github.com/your-org/FunctionalTesting/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/your-org/FunctionalTesting/releases/tag/v1.0.0
  * Generated architecture diagrams and API reference outputs
- Removed redundant docs/API_REFERENCE.md (superseded by API_REFERENCE_GENERATED.md)
