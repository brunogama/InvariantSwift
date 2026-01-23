# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **AccessLevel Enum (Phase 04-01)**: Full Swift access level extraction for Ghostwriter
  - `AccessLevel` enum with all 5 Swift levels (private, fileprivate, internal, public, open)
  - `Comparable` conformance for access level ordering
  - `isPubliclyAccessible` property for test filtering
  - `extractAccessLevel()` function using `TokenKind.keyword` pattern (official Swift macro approach)
  - Access level extraction for both types and properties
  - Backward compatible `isPublic` computed properties
- **CLI --include-internal Flag (Phase 04-01)**: Control test generation for internal types
  - `Config.includeInternal` flag defaults to false (only public/open types)
  - `--include-internal` command-line argument parsing
  - Access level-based filtering in type selection
  - Verbose logging shows skipped non-public types with access levels
- **Phase 5 Execution Plans** in `.planning/phases/5-error-messages-and-progress/`:
  * 5-01-PLAN.md: Progress Tracking and INVARIANT_SEED Environment Variable
    - ProgressReporter struct with time-based throttling
    - PropertyConfig.showProgress and progressInterval settings
    - INVARIANT_SEED env var reading in PropertyRunner (with INVARIANT_SWIFT_SEED compat)
    - Progress suppression for fast tests (< 5 seconds)
  * 5-02-PLAN.md: Enhanced Failure Messages
    - Comprehensive verbose message format with sections (header, counterexample, stats, reproduction)
    - Both env var and @PropertyTest macro reproduction syntax
    - Shrinking metrics display (attempts, successful, reduction)
    - Classification included when present
  * 5-03-PLAN.md: PropertyRunner Progress Integration
    - ProgressReporter integration in runProperty iteration loop
    - Seed logging in verbose mode and always on failure
    - Swift Testing integration with seed in failure messages
- **Phase 6 Research Documentation** in `.planning/phases/06-documentation-examples/06-RESEARCH.md`:
  * Research on Swift DocC documentation compiler and framework documentation patterns
  * Three-tier documentation structure: Quick Start -> Cookbook -> Migration Guide
  * Recipe-based documentation patterns with Problem/Solution/Discussion format
  * Migration guide patterns from QuickCheck/Hypothesis to InvariantSwift
  * Accessibility strategies for non-FP developers (avoid functor/monad jargon)
  * Common pitfalls: FP terminology barriers, missing migration paths, example complexity
  * Standard stack: Swift DocC, Markdown, Swift-DocC-Plugin
  * Estimated 1 week implementation (3 days authoring + 2 days tutorials + 2 days review)
- **Implication Operator `==>` (Phase 03-01)**: QuickCheck-style conditional properties
  - `Bool ==> Bool` overload for simple precondition checks
  - `Bool ==> PropertyEvaluation` overload for explicit control
  - `ImplicationPrecedence` precedence group (right-associative, between comparison and assignment)
  - Short-circuit evaluation via `@autoclosure`
  - False precondition returns `.discard` (not `.fail`)
- **PropertyRunner+Discard (Phase 03-02)**: Discard ratio checking and enforcement logic
  - `checkDiscardRatio()` validates ratio against configured thresholds
  - Actionable warning and error messages with specific fix suggestions
  - Non-isolated methods compatible with PropertyRunner actor isolation
- **PropertyConfig.DiscardConfig (Phase 03-02)**: Configurable discard ratio tracking and enforcement
  - `warnRatio`, `failRatio`, and `enforceRatio` properties for controlling discard behavior
  - Static presets: `.default` (5x/10x), `.lenient` (10x/50x), `.disabled`
  - Prevents silent test failures from over-filtering generators
- **ImplicationOperatorTests (Phase 03-03)**: Comprehensive test suite for `==>` operator
  - 14 tests covering semantics, short-circuit evaluation, precedence, and integration
  - Includes dogfood test verifying operator semantics with property testing
  - Zero lint violations, full coverage of Phase 03-01 implementation
- **DiscardTrackingTests (Phase 03-03)**: Comprehensive test suite for discard ratio tracking
  - 14 tests covering DiscardConfig, ratio calculation, thresholds, and enforcement
  - Integration with ==> operator and message formatting tests
  - 2 dogfood tests verifying ratio math and threshold logic
  - Zero lint violations, full coverage of Phase 03-02 implementation
- **Phase 3 Research Documentation** in `.planning/phases/03-discard-syntax-sugar/03-RESEARCH.md`:
  * Research on QuickCheck implication operator (`==>`) semantics and implementation
  * Discard ratio tracking patterns for preventing over-filtering
  * Custom operator precedence and associativity for Swift
  * Integration with existing PropertyEvaluation.discard infrastructure
  * Common pitfalls: over-restrictive preconditions, `==>` vs `&&` confusion
  * Estimated 3-5 days implementation
- **PropertyTestMacroClassificationTests (Phase 01-03)**: Macro integration tests
  - Verifies @PropertyTest macro generates code compatible with ClassifyingProperty
  - Documents workaround for using classification with macros
  - Tests type compatibility between Property and ClassifyingProperty overloads
- **CoverageEnforcementTests (Phase 01-03)**: 9 tests for coverage threshold enforcement
  - Strict vs lenient mode behavior
  - Multiple coverage thresholds
  - Clear error messages with actual vs required percentages
  - Edge cases (0%, 100% thresholds)
- **ClassificationFluentAPITests (Phase 01-03)**: 17 comprehensive tests for the fluent classification API
  - Tests for cover(), classify(), and label() methods
  - Method chaining and multiple coverage requirements
  - Edge cases (0%, 100% coverage, empty properties)
  - 3 dogfood tests using property testing to verify classification correctness
  - Lenient vs strict mode coverage enforcement tests
- **Swift Testing Classification Integration (Phase 01-03)**: Classification reports now appear in Swift Testing output for both passing and failing tests
  - `FailureReport.classificationReport` field for including classification data in failure messages
  - `FailureReport.from(ClassifyingPropertyResult)` factory method for creating reports with classification
  - `checkProperty(_: ClassifyingProperty)` overload for running classifying properties in Swift Testing
  - Classification displayed in both compact and verbose failure formats
- **CoverageConfig**: Added `CoverageConfig` nested type to `PropertyConfig` with `enforceCoverage`, `warnOnLowCoverage`, and `maxLabels` options for configurable coverage enforcement (Phase 01-02)
- **Enhanced ClassifyingPropertyRunner**: Config-driven coverage enforcement with clear error messages and warning support
- **Enhanced ClassificationReport formatting**: QuickCheck-style output with percentage-sorted labels and clear coverage status indicators
- **Phase 2 Execution Plans** in `.planning/phases/02-enhanced-reporting/`:
  * 02-01-PLAN.md: Value Collection (collect) with histogram tracking
    - Property<T>.collect() extension for value distribution tracking
    - ClassificationContext.collect() with thread-safe histogram storage
    - ClassificationReport.collectedValues with formatted histogram output
    - bucketNumeric() helper for readable numeric ranges (0, 1-9, 10-99, etc.)
  * 02-02-PLAN.md: Multi-dimensional Tabulation and Phase 1 API
    - Property<T>.tabulate() for multi-label categorization
    - ClassificationContext.tabulate() reusing labels dictionary
    - Complete fluent API: cover(), classify(), label(), collect(), tabulate()
    - Depends on 02-01 for Property+Classification.swift foundation
  * 02-03-PLAN.md: Counterexample Messages and Enhanced Formatting
    - Property<T>.counterexample() for custom failure messages
    - ClassificationContext.addCounterexample() with lazy evaluation
    - PropertyRunner integration for counterexample message flow
    - PrettyPrint enhancements: formatHistogram(), formatPropertyFailure()
  * 02-04-PLAN.md: Comprehensive Test Suite and Quality Verification
    - CollectTests.swift, TabulateTests.swift, CounterexampleTests.swift
    - MacroIntegrationTests.swift for @PropertyTest + fluent API
    - QR-1: 100% coverage verification with swift test --enable-code-coverage
    - QR-2: 20% dogfooding threshold with 6+ property-based tests
    - QR-3: Macro integration tests for all Phase 2 features
- **Phase 1 Execution Plans** in `.planning/phases/01-test-observability/`:
  * 01-01-PLAN.md: Fluent Classification API (Property+Classification.swift)
    - Property<T>.cover(), .classify(), .label() extensions returning ClassifyingProperty<T>
    - Method chaining support for accumulating multiple classifications
    - Dynamic labeling and collect() convenience methods on ClassificationContext
  * 01-02-PLAN.md: PropertyRunner Integration with CoverageConfig
    - CoverageConfig struct with enforceCoverage, warnOnLowCoverage, maxLabels options
    - Config-driven coverage enforcement in ClassifyingPropertyRunner
    - Enhanced ClassificationReport formatting with QuickCheck-style output
  * 01-03-PLAN.md: Swift Testing Integration and Comprehensive Tests
    - FailureReporting enhancement with classification data
    - 15+ tests for fluent API (ClassificationFluentAPITests.swift)
    - 8+ tests for coverage enforcement (CoverageEnforcementTests.swift)
    - 3+ dogfood tests using property testing to verify classification
- **Phase 1 Research Documentation** in `.planning/phases/01-test-observability/01-RESEARCH.md`:
  * Research on QuickCheck test observability features (cover, classify, label, collect)
  * Verified existing ClassificationContext infrastructure (90% already implemented)
  * Non-breaking integration strategy via fluent API extensions
  * Performance analysis: <10% overhead target for classification tracking
  * Common pitfalls: over-filtering, unbounded label sets, performance considerations
  * Estimated 1 week implementation (3-5 days code + 2-3 days testing)
- **Project Configuration** in `.planning/config.json`:
  * Workflow mode: YOLO (auto-approve execution)
  * Planning depth: Standard (5-8 phases, 3-5 plans each)
  * Parallelization: Enabled (independent plans run simultaneously)
  * Git tracking: Enabled (planning docs committed to version control)
  * Model profile: Balanced (Sonnet for most agents, good quality/cost ratio)
  * Workflow agents: Research, Plan Check, and Verifier all enabled
- **Project Initialization** in `.planning/PROJECT.md`:
  * Project vision: InvariantSwift v2.0 with full QuickCheck feature parity
  * Core value: Accessible property-based testing for non-FP Swift developers
  * Validated requirements from existing codebase (core generators, macros, faker, crash isolation)
  * Active requirements for v2.0 (QuickCheck features, working Ghostwriter, improved macros, code cleanup)
  * Constraints: Swift 6 strict concurrency, SwiftSyntax 602.0.0, production quality
- **Codebase Mapping Documentation** in `.planning/codebase/`:
  * STACK.md - Technology stack and dependencies (Swift 6.0+, SwiftSyntax 602.0.0, swift-custom-dump)
  * ARCHITECTURE.md - System design and component interactions (Generator, Property, ShrinkTree, Macros)
  * STRUCTURE.md - Directory layout and naming conventions (6 library targets, 2 executables, 7 test targets)
  * CONVENTIONS.md - Code style and patterns (Google Swift Style, strict concurrency, actor isolation)
  * TESTING.md - Test framework and patterns (Swift Testing, 99%+ coverage target, macro expansion tests)
  * INTEGRATIONS.md - External dependencies analysis (self-contained library, SQLite3, os.log)
  * CONCERNS.md - Technical debt and known issues (force unwraps, 16 disabled tests, large files)
- **Project Research Documentation** in `.planning/research/`:
  * STACK.md - QuickCheck feature inventory and technology choices for v2.0 implementation
  * FEATURES.md - Table stakes vs differentiators analysis with accessibility impact assessment
  * ARCHITECTURE.md - Integration patterns showing existing ClassificationContext infrastructure
  * PITFALLS.md - Critical pitfalls (shrinking loops, recursive generators, FP terminology barriers)
  * SUMMARY.md - Research synthesis with 6-phase roadmap implications and technology decisions
- **Requirements Documentation** in `.planning/REQUIREMENTS.md`:
  * QR-1: 100% test coverage mandate for all new code in Phases 1-6
  * QR-2: Dogfood tests using InvariantSwift to test itself with property tests
  * QR-3: Integration macro tests with SwiftSyntaxMacrosTestSupport verification
  * Functional requirements by phase: 6 phases covering QuickCheck feature parity
  * Phase 1: Test observability (cover, classify, label) - MVP blocker
  * Phase 2: Enhanced reporting (collect, tabulate, counterexample) - QuickCheck parity
  * Phase 3: Discard improvements and ==> operator - DX polish
  * Phase 4: Ghostwriter fixes (auto-generate @Arbitrary, filter private types) - production-ready
  * Phase 5: Enhanced error messages, progress indicators, seed logging - accessibility
  * Phase 6: XCTest migration guide, terminology glossary, expanded cookbook - documentation
  * Non-functional requirements: <10% performance overhead, thread-safe actors, bounded memory
  * Success metrics: 90%+ QuickCheck parity, 100% coverage, 20%+ dogfood tests
- **Project Roadmap** in `.planning/ROADMAP.md`:
  * 6-phase implementation plan with 6-8 weeks total effort
  * 29 detailed tasks with specific deliverables and file paths
  * Phase 1: Test Observability (1-2 weeks, P0) - Wire ClassificationContext to PropertyRunner
  * Phase 2: Enhanced Reporting (1-2 weeks, P1) - Add collect, tabulate, counterexample
  * Phase 3: Discard & Syntax (3-5 days, P1) - Implement ==> operator and discard tracking
  * Phase 4: Ghostwriter Fixes (1 week, P1) - Auto-generate @Arbitrary, access filtering
  * Phase 5: Error Messages (3-5 days, P2) - Enhanced failures, progress, seed logging
  * Phase 6: Documentation (1 week, P2) - XCTest migration guide, 20+ examples, glossary
  * Quality gates: 100% coverage, 20%+ dogfood tests, zero warnings enforced per phase
  * Parallelization opportunities: Phases 3-4 can run concurrently
  * Dependencies graph and timeline with critical path identified
  * Success criteria: 90%+ QuickCheck feature parity, user testing with non-FP developers
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
- Collection shrinking v2 with integrated shrinking and BFS search (SHRINK-COLL-001)
- `ShrinkTree<T>` struct for lazy shrinking with tree traversal
- Enhanced `Gen.array`, `Gen.set`, `Gen.dictionary` with integrated shrinking
- Support for async/throwing property predicates (PROP-ASYNC-001)
- Safe optional unwrapping for predicates without force-unwrap in library code

### Changed
- Improved generator type inference to reduce ambiguity errors
- Refactored test imports across 130+ test files for consistency
- Updated all test files to use qualified `Gen<T>` syntax

### Fixed
- Removed unsafe force-unwraps from all library code
- Fixed compiler warnings related to optional unwrapping
- Corrected type inference issues in generator composition

### Deprecated
- LensExtensions.swift removed (optics not core to PBT)
- RegressionBank.swift in Advanced/ moved to Core/ for consistency

## [1.0.0] - 2024-XX-XX

### Added
- Initial release with core property-based testing features
- Generator combinators for all Swift standard library types
- Property test runner with configurable iterations
- Shrinking strategies for minimal counterexamples
- Swift Testing integration
- Macro support (@PropertyTest, @Arbitrary, @StateMachine)

[Unreleased]: https://github.com/yourorg/InvariantSwift/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourorg/InvariantSwift/releases/tag/v1.0.0
