# InvariantSwift v2.0

## What This Is

A property-based testing framework for Swift with full QuickCheck feature parity, designed for Swift 6 strict concurrency. Built for Swift developers who don't use functional programming - as easy to use as XCTest, with the power of property-based testing. Uses SwiftSyntax for intelligent test generation via Ghostwriter.

## Core Value

Non-FP Swift developers can adopt property-based testing as easily as they use XCTest, with QuickCheck's complete feature set available in idiomatic Swift.

## Requirements

### Validated

<!-- Existing capabilities from current codebase -->

- ✓ Core generator system (Gen<T>) with composition — existing
- ✓ Property test execution with shrinking — existing
- ✓ Swift Testing integration (@PropertyTest macro) — existing
- ✓ Macro system infrastructure (SwiftSyntax 602.0.0) — existing
- ✓ 100+ Faker generators for realistic test data — existing
- ✓ Basic shrinking strategies (towards zero, remove elements, halve) — existing
- ✓ Deterministic test replay via Seed — existing
- ✓ Actor-based concurrency patterns — existing
- ✓ JSON report schema for CI/CD integration — existing
- ✓ Crash isolation via subprocess execution (macOS) — existing

### Active

<!-- Building toward these for v2.0 -->

- [ ] **QuickCheck Feature Parity**: All QuickCheck features working in Swift
  - [ ] `cover` - coverage checking to ensure test distribution
  - [ ] `discard` - better assumption handling without false positives
  - [ ] `classify` - test distribution statistics and reporting
  - [ ] `collect` - gather and report test data patterns
  - [ ] Conditional properties (`==>` implication operator)
  - [ ] `forAll` with explicit generators
  - [ ] Improved shrinking (integrated collection shrinking, smarter strategies)
  - [ ] `counterexample` - minimal failing case reporting
  - [ ] `verbose` mode for detailed test execution traces

- [ ] **Ghostwriter Auto-Generation**: Generates compilable, working tests
  - [ ] Correctly identifies public types only (skip private/internal)
  - [ ] Auto-generates @Arbitrary extensions for custom types
  - [ ] Detects protocol conformances (Equatable, Comparable, Codable, Hashable)
  - [ ] Generates law-based property tests (reflexivity, symmetry, transitivity)
  - [ ] Generates tests with correct imports and module access

- [ ] **Improved Macro System**: Better ergonomics and generation
  - [ ] @Property macro (replaces @PropertyTest for cleaner syntax)
  - [ ] @Arbitrary macro generates better arbitrary implementations
  - [ ] Macro-based code mutation for mutation testing
  - [ ] Better error messages from macro expansion failures

- [ ] **Maintainable Codebase**: Clean, navigable code
  - [ ] Split large files (Property.swift 2046 lines → multiple focused files)
  - [ ] Split Generator.swift (1691 lines → separate concerns)
  - [ ] Eliminate force unwraps in library code (use guard/optional chaining)
  - [ ] Remove precondition() calls (make illegal states unrepresentable)

- [ ] **Accessible to Non-FP Developers**: Familiar patterns, clear documentation
  - [ ] Examples using standard Swift types (not abstract FP concepts)
  - [ ] Clear error messages (no FP jargon)
  - [ ] Documentation shows XCTest comparison
  - [ ] "Getting Started" guide for XCTest users

- [ ] **Fix Disabled Tests**: 16 test files re-enabled and passing
  - [ ] CollectionGeneratorTests.swift
  - [ ] NumericGeneratorTests.swift
  - [ ] CoverageCompletionTests.swift
  - [ ] LibFuzzerTests.swift
  - [ ] MetamorphicTests.swift
  - [ ] MetaPropertyTests.swift
  - [ ] ShrinkPredicateTests.swift
  - [ ] CoverageGuidedTests.swift
  - [ ] GeneratorRegistryTests.swift
  - [ ] LinearizabilityTests.swift
  - [ ] PrettyPrinterEnhancementTests.swift
  - [ ] LensSystemTests.swift
  - [ ] FloatingPointModeTests.swift
  - [ ] CollectionShrinkingV2Tests.swift
  - [ ] SMTSolverTests.swift
  - [ ] FailurePersistenceTests.swift

- [ ] **Benchmarks**: Performance regression detection
  - [ ] Generator performance benchmarks
  - [ ] Shrinking performance benchmarks
  - [ ] Property execution benchmarks
  - [ ] Macro expansion benchmarks

### Out of Scope

- Forced async/await migration — explore if beneficial, not required (Swift 6 concurrency via actors works)
- Gen<Type> syntax replacement — current syntax is fine, focus on features not syntax bikeshedding
- Real-time chat/collaboration features — this is a testing library
- GUI test runner — CLI and Xcode integration sufficient
- Network-based distributed testing — local execution only

## Context

**Starting from existing codebase:**
InvariantSwift is a mature Swift package with solid foundations. Core architecture (Gen, Property, Shrink, Seed, Size) is sound and well-tested. The codebase has 99%+ coverage target and follows Swift 6 strict concurrency.

**Known issues to address:**
- Ghostwriter generates broken tests (missing @Arbitrary, targets private types)
- 16 test files disabled (features half-built or broken)
- Technical debt: force unwraps (`array.last!`), huge files (2000+ lines), precondition() usage
- Non-FP developers find the framework intimidating (terminology, patterns, examples)

**What QuickCheck has that we're missing:**
Coverage checking (`cover`), better assumption handling (`discard`), test classification (`classify`, `collect`), conditional properties, explicit generator control, comprehensive shrinking strategies.

## Constraints

- **Tech stack**: Swift 6.0+ with strict concurrency (`-strict-concurrency=complete`)
- **Macro infrastructure**: SwiftSyntax 602.0.0 (exact version pin for Swift 6.x compatibility)
- **Build**: Swift Package Manager only (no CocoaPods, Carthage)
- **Platforms**: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ (no older OS support)
- **Code quality**: Zero warnings (`-warnings-as-errors`), 99%+ test coverage, SwiftLint strict mode
- **Production quality**: No fatalError, no force unwraps, no precondition() in library code (make illegal states unrepresentable)
- **Dependencies**: Minimal external dependencies (only SwiftSyntax, swift-custom-dump, swift-benchmark)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep Gen<T> closure-based | Core architecture is solid, no reason to rewrite | — Pending |
| Focus on QuickCheck parity | Clear success criteria, proven feature set | — Pending |
| Fix Ghostwriter first | High-leverage feature that showcases framework value | — Pending |
| Use @Property over @PropertyTest | Cleaner syntax, matches property-based testing terminology | — Pending |

---
*Last updated: 2026-01-23 after initialization*
