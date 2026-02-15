# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
