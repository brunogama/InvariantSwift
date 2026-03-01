# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- **Phase 13: Cross-Platform Crash Isolation (Plan 13-02 complete)** - PosixSpawnIsolation subprocess backend
  - Added `PosixSpawnIsolation` struct conforming to `IsolationStrategy` via `posix_spawn`
  - Pipe-based IPC: stdin for request, stdout for response, stderr for crash diagnostics
  - Crash detection via inline wait-status bit operations (WIFSIGNALED/WTERMSIG pattern)
  - Timeout via detached Task that sends SIGKILL after configured deadline
  - All file descriptors closed in all code paths via defer blocks
  - `PropertyEvaluationRequest`/`PropertyEvaluationResponse` promoted to `public` with `protocolVersion`
  - `IsolationStrategy.execute(body:)` updated to `@escaping` for `ThreadIsolation` compatibility
  - `ThreadIsolation` (Plan 03 skeleton): rewrote to compile on Swift 6.2 — workaround for compiler
    SIGABRT in `SendNonSendable` pass with raw `pthread_t`; uses `Foundation.Thread` + `DispatchSemaphore`
  - `IsolationStrategyFactory` wired to return `PosixSpawnIsolation` for `.fullSubprocess` capability
  - Helper path discovery: argv[0] sibling, `.build/debug/`, `.build/release/`
  - `PropertyTestHelper` binary updated with protocol version handshake (exit code 3 on mismatch)
- **Phase 13: Cross-Platform Crash Isolation (Plan 13-01 complete)** - Foundation types for crash isolation
  - Added `IsolationCapability` enum with `.fullSubprocess`, `.threadBased`, `.none` cases
  - Added `CrashReport<T>` struct with signal, counterexample, shrunkCounterexample, stderr,
    backtrace, isSymbolicated, and `IsolationMechanism` provenance fields
  - Added `IsolationStrategy` protocol with `execute(body:)` returning `IsolationResult`
  - Added `IsolationResult` enum: `.success`, `.failure`, `.crashed`, `.timeout`
  - Added `IsolationStrategyFactory` namespace and `PassthroughIsolation` placeholder
  - All three types compile with zero warnings, zero swiftlint violations
  - Runtime probing via `posix_spawn` on Darwin (iOS Simulator vs device detection)
  - Cached capability via `static let` (single probe at startup)
  - Pure Darwin import, no Foundation dependency
  - Fixed InvariantSwiftMacros for SwiftSyntax 600.0.1: `GenericArgumentSyntax.argument` is
    `TypeSyntax` directly (not a tagged union), updated all 8 affected files
- **Phase 13: Cross-Platform Crash Isolation (Planning)**
  - Created 4-plan breakdown for replacing Foundation.Process with posix_spawn
  - Plan 13-01: IsolationCapability, CrashReport, IsolationStrategy foundation types
  - Plan 13-02: PosixSpawnIsolation for macOS + iOS Simulator
  - Plan 13-03: ThreadIsolation fallback for iOS device
  - Plan 13-04: IsolatedPropertyRunner rewrite and comprehensive tests
- **Fix**: Remove duplicate FlatMapShrinkingTests.swift files that caused SPM "multiple producers" build error
  - Deleted stale XCTest-based Core/FlatMapShrinkingTests.swift (104 lines)
  - Deleted orphan Tests/FunctionalTesting/ directory (7 unreferenced files)
  - Deleted stale Packages/InvariantSwiftCore copy
  - Canonical Swift Testing version preserved at Tests/InvariantSwiftTests/FunctionalTesting/
- **Fix**: Add Xcode scheme with test action for xcodebuild integration
  - Created .swiftpm/xcode/xcshareddata/xcschemes/InvariantSwift.xcscheme
  - All 8 test targets included in scheme test action
  - Updated .gitignore to allow shared xcschemes to be committed
- **Packaging**: Add binary artifact bundle for InvariantSwiftMacros
  - Dual-manifest pattern (Package.swift / Package.binary.swift) eliminates swift-syntax for consumers
  - Build script and CI workflow for tagged releases (macOS arm64/x86_64, Linux x86_64)
- **Phase 11: Technical Debt Reduction (Plan 11-01, 11-04 Partial Complete)** - Configuration ergonomics and macro/infrastructure improvements
  - **Plan 11-01 Complete**: Configuration ergonomics and public API improvements
    - Added PropertyConfigBuilder with fluent API (.withIterations, .withSeed, etc.)
    - Added SeedStrategy enum (.random, .fixed(Seed)) for better seed handling
    - PropertyConfig remains backwards compatible with existing initializer
    - Exposed PropertyResult.toTestResult() as public API (moved from fileprivate in FlakeHunter)
    - Created PropertyResult+TestResult.swift for reliability testing integration
    - Enhanced DifferentialTesting error comparison: .mustMatch now compares error types using type(of:)
    - DifferentialTestError description now includes error type information and mismatch warnings
    - Completed 11-01-SUMMARY.md with execution details (3 commits, 265s duration)
  - **Plan 11-04 Complete**: PropertyMacro AST refactoring, Ghostwriter Dictionary support, and coverage infrastructure
    - Refactored PropertyMacro to use pure SwiftSyntax AST builders (no string interpolation)
    - Implemented Dictionary<K, V> and [K: V] support in Ghostwriter TestCodeGenerator
    - Dictionary generators inferred recursively for key/value types using Gen.zip pattern
    - Resolved PropertyRunner+Coverage circular dependency by removing duplicate file
    - PropertyRunner coverage extensions now properly located in InvariantSwiftAdvanced module
    - Completed 11-04-SUMMARY.md with execution details (2 commits, 553s duration)
### Planned
- **Phase 11: Technical Debt Reduction Plans** - Decomposed technical debt reduction into 4 execution plans
  - **Plan 11-02: God File Decomposition (Core)** - Planned decomposition of Property.swift and ModelTesting.swift
  - **Plan 11-03: God File Decomposition (Advanced)** - Planned decomposition of FlakeHunter, Linearizability, InvariantMining, and PrettyPrint
  - **Plan 11-04: Infrastructure & Macros** - Planned PropertyMacro AST refactoring and Ghostwriter Dictionary support
### Internal
- **Phase 11: Technical Debt Research** - Researched and documented technical debt inventory and refactoring plan

### Added
- **Phase 05: Error Messages & Progress** - Developer experience polish for better failure diagnostics
  - **Plan 05-01: Shrinking Metrics** - Added ShrinkMetrics struct to capture shrinking journey data
    - Tracks attempts, successful reductions, duration, and reduction percentage
    - Includes automatic reduction percentage calculation from original/shrunk sizes
    - Provides box-drawn formatting for failure output
    - Extended FailureReport with shrinkMetrics property and computedShrinkMetrics accessor
    - Enhanced FailureReporter to display shrinking metrics in verbose format
  - **Plan 05-02: INVARIANT_SEED Environment Variable** - Environment-based seed control
    - Added Seed.fromEnvironmentOrRandom() to read INVARIANT_SEED environment variable
    - Supports valid UInt64 seeds with fallback to random for invalid values
    - Added PropertyConfig.default() factory using environment-aware seed
    - Enhanced ReplayToken with fullReproductionInstructions showing 3 options
  - Plan 05-03: Comprehensive integration tests for error messages, progress, and seed reproducibility
- **Phase 09-07: Workspace Cleanup Verification** - Final verification before migration cleanup
  - Verified sub-package builds: InvariantSwiftCore (3.62s), InvariantSwiftMacros (12.97s)
  - Created cleanup manifest documenting 10 source directories (284 files) and 5 test directories (116 files) to be removed
  - Ready for final cleanup after human verification checkpoint
- **Phase 10 Research: Professional Naming** - Research for workspace cleanup
  - Identified `InvariantSwiftAdvanced` as professional replacement for Experimental
  - Mapped 78+ files requiring import and type reference updates
  - Researched Swift ecosystem naming patterns for advanced modules
  - Verified stability of advanced features (AsyncProperties, Fuzzing, Metamorphic)
  - Planned non-breaking reorganization strategy

### Breaking Changes

- **Renamed:** `InvariantSwiftExperimental` module has been renamed to `InvariantSwiftAdvanced` (Phase 10)
  - The old module name gave the impression of unstable, work-in-progress code
  - These features (coverage-guided generation, fuzzing, metamorphic testing, etc.) are production-ready
  - **Migration:** Replace all instances of `import InvariantSwiftExperimental` with `import InvariantSwiftAdvanced`
  - **Migration:** Replace all instances of `@testable import InvariantSwiftExperimental` with `@testable import InvariantSwiftAdvanced`
  - No API changes - all types and functions remain the same
  - 71 files updated across Sources/, Tests/, and Packages/
  - 56 source files preserved (28 in root + 28 in Packages/Core)

- **Phase 09-05: Test Migration and Root Umbrella** - Complete workspace integration
  - Migrated core tests to Packages/InvariantSwiftCore/Tests/
  - Migrated macro tests to Packages/InvariantSwiftMacros/Tests/
  - Created InvariantSwiftUmbrella re-export module for unified import
  - Updated plugins to reference sub-package executables
  - Tests properly distributed based on macro dependencies

- **Phase 09-06: CI/CD and Build Tooling** - Workspace infrastructure
  - Updated CI workflow with parallel sub-package builds (build-core, build-macros)
  - Added integration job that depends on sub-package builds
  - Enabled SwiftSyntax prebuilts (--enable-experimental-prebuilts) for 40-75% faster builds
  - Added SwiftSyntax prebuilts caching (~/.swiftpm/swift-syntax-prebuilts)
  - Added sub-package specific SwiftPM caching
  - Updated Makefile with workspace-aware targets (build-core, build-macros, test-core, test-macros)
  - Added clean-all target for cleaning all package build artifacts
  - Updated docs/QUICKSTART.md with package structure and prebuilts configuration

- **Phase 09-04: Ghostwriter Migration** - Moved Ghostwriter to InvariantSwiftMacros package
  - Copied GhostwriterLib (5 files) to Packages/InvariantSwiftMacros/Sources/GhostwriterLib/
  - Copied GhostwriterCLI (refactored to 12 files) to Packages/InvariantSwiftMacros/Sources/GhostwriterCLI/
  - Added CLIOutput protocol abstraction for CLI output
  - Added GenerationContext and VerboseStatsContext parameter objects
  - Consolidates all SwiftSyntax-dependent code in macro package

- **Phase 09-01: SPM Workspace Monorepo Structure** - Foundation for SwiftSyntax isolation
  - Created Packages/InvariantSwiftCore/ with stub Package.swift
  - Created Packages/InvariantSwiftMacros/ with stub Package.swift
  - Added Sources/ and Tests/ subdirectories with .gitkeep placeholders
  - Added local path dependencies in root Package.swift
  - Added workspace structure documentation comment
  - Establishes monorepo directory structure for parallel builds

### Changed
- **Phase 09 Plans Revised** - Addressed checker feedback with 5 blockers and 3 warnings fixed
  - Added explicit plugin migration task in Plan 05
  - Split Plan 05 Task 2 into 3 focused tasks (umbrella, plugins, integration tests)
  - Added umbrella re-export verification with key_links
  - Clarified test migration criteria for macro-dependent tests
  - Fixed Plan 04 dependency graph (added 09-03, moved to wave 3)
  - Updated wave structure: Wave 1 (01,02), Wave 2 (03), Wave 3 (04), Wave 4 (05,06), Wave 5 (07)
- **Architecture Refactor: Layered Module Structure** - Major reorganization
  - Split monolithic InvariantSwift into layered modules with clean dependency graph
  - Layer 0 (Foundation): InvariantSwiftCore - Gen, Property, Shrink, Seed, Size
  - Layer 1 (Building Blocks): InvariantSwiftGenerators, InvariantSwiftExecution
  - Layer 2 (Main Library): InvariantSwift - re-exports Core, Generators, Execution
  - Layer 3 (Extensions): InvariantSwiftMacroAPI (no swift-syntax), InvariantSwiftExperimental
  - Layer 4 (Testing): InvariantSwiftTesting - Swift Testing framework integration
  - Isolated swift-syntax to compile-time-only macro target
  - Fixed circular dependency in MacroAPI with duplicated support types
  - Added umbrella re-exports for unified import experience

### Fixed
- **Build: MacroAPI Dependency Fix** - Added missing InvariantSwiftMacros dependency
  - InvariantSwiftMacroAPI declares external macros via #externalMacro
  - Missing dependency caused "plugin not found" warnings during parallel builds
  - Build now passes with -Xswiftc -warnings-as-errors
- **Phase 04.7-26: ConfigBuilder SwiftLint Cleanup** - Gap closure (wave 2)
  - Fixed 5 SwiftLint violations in Sources/InvariantSwift/Testing/ConfigBuilder.swift
  - Removed unneeded synthesized initializer (Swift auto-generates memberwise init for structs)
  - Replaced ConfigBuilder<T> return types with Self in from/set/update methods
  - Fixed line_length violation in set method (split to 4 lines)
  - All strict mode violations resolved
  - swiftlint lint --strict passes with 0 violations
  - Plan complete: 1 commit, SUMMARY.md created
- **Phase 04.7-22: Test Helper Implementation** - Gap closure (wave 2) - COMPLETE
  - Added expectNoDifference and expectDifference test assertion helpers
  - Created Tests/InvariantSwiftTests/TestHelpers/DiffAssertions.swift
  - Enable PrettyPrinterEnhancementTests.swift compilation
  - Simple equality-based assertions for test infrastructure
  - 1 commit, 3 minutes, SUMMARY.md created
- **Phase 04.7-20: SwiftLint Disable Documentation** - Gap 1 closure (complete)
  - Documented Generator.swift file_length blanket disable with TECH DEBT comment
  - Explained why blanket disable is unavoidable: file_length is file-level rule, cannot use function-scoped disable
  - Referenced future work: ISP proposal for generator modularization (Gen/Shrink/Size/Seed split)
  - This is the ONLY acceptable blanket disable in codebase per RULES.md
  - Verified Property.swift and RunReport.swift use function-scoped disable/enable pairs (NOT blanket disables)
  - Property.swift has 3 function-scoped pairs: cyclomatic_complexity (runPropertyWithFailingExamples), function_body_length (runThrowingProperty, runAsyncThrowingProperty)
  - RunReport.swift has 1 function-scoped pair: function_body_length+function_parameter_count (buildReport)
  - swiftlint lint --strict passes with 0 violations on Sources/InvariantSwift/Core/
  - Plan complete: 2 commits, 3 minutes, SUMMARY.md created
