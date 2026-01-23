# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
