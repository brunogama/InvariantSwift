# Deferred Test Files - Phase 4.7

The following test files remain disabled pending feature completion or infrastructure availability.

## SMTSolverTests.swift.disabled ✅ RE-ENABLED

- **Feature:** SMT solver integration
- **Status:** Fully functional, all APIs exist in InvariantSwiftExperimental
- **File:** Tests/InvariantSwiftTests/FunctionalTesting/SMTSolverTests.swift
- **Imports Required:** `@testable import InvariantSwiftExperimental`
- **Test Count:** 26 comprehensive tests
- **Compile Status:** Zero errors

## MetamorphicTests.swift ✅ RE-ENABLED

- **Feature:** Metamorphic property testing
- **Status:** Fully functional, all APIs exist in InvariantSwiftExperimental
- **File:** Tests/InvariantSwiftTests/FunctionalTesting/MetamorphicTests.swift
- **Imports Required:** `@testable import InvariantSwiftExperimental`
- **Compile Status:** Zero errors

## GeneratorRegistryTests.swift ✅ RE-ENABLED

- **Feature:** Generator registry actor
- **Status:** Fully functional, all APIs exist in InvariantSwiftExperimental
- **File:** Tests/InvariantSwiftTests/FunctionalTesting/GeneratorRegistryTests.swift
- **Imports Required:** `@testable import InvariantSwiftExperimental`
- **Compile Status:** Zero errors

## LinearizabilityTests.swift.disabled (DEFERRED)

- **Feature:** Linearizability checking for concurrent data structures
- **Status:** Core types exist, but `Operation<Input, Output>` not generic
- **API Gap:** `Operation` type in InvariantSwiftExperimental is not generic, but tests expect `Operation<Int, Int>`
- **Reason:** Type signature mismatch between implementation and tests
- **Unblock:** Either:
  1. Make `Operation` generic: `public struct Operation<Input, Output>`
  2. Update tests to use non-generic Operation with type erasure
- **Recommendation:** Defer until Operation API is finalized

## LensSystemTests.swift.disabled (DEFERRED)

- **Feature:** Lens/Prism optics for immutable updates
- **Status:** Core Lens/Prism types exist, but PropertyConfig lens integration missing
- **API Gaps:**
  - `PropertyConfig.iterations` static lens not defined
  - `PropertyConfig.maxShrinks` static lens not defined
  - `Lens.get()` method signature mismatch
- **Reason:** PropertyConfig doesn't have lens extension methods
- **Unblock:** Implement PropertyConfig+Lenses.swift extension:
  ```swift
  extension PropertyConfig {
    static let iterations: Lens<PropertyConfig, Int> = ...
    static let maxShrinks: Lens<PropertyConfig, Int> = ...
    static let seed: Lens<PropertyConfig, Seed?> = ...
  }
  ```
- **Recommendation:** Defer until lens integration is complete

## CoverageGuidedTests.swift.disabled (DEFERRED)

- **Feature:** Coverage-guided property testing
- **Status:** Core types exist, but PropertyRunner integration incomplete
- **API Gaps:**
  - `PropertyRunner.runPropertyWithCoverageTracking()` not implemented
  - `PropertyRunner.runPropertyWithCoverageGuidance()` not implemented
  - `CoverageStrategy.frequency` enum case not fully defined
- **Reason:** PropertyRunner extensions for coverage-guided execution need implementation
- **Unblock:** Implement PropertyRunner+Coverage.swift with:
  ```swift
  extension PropertyRunner {
    public func runPropertyWithCoverageTracking<T>(
      _ property: Property<T>,
      knownSymbols: Set<String>,
      config: PropertyConfig = .default,
      coverageConfig: CoverageConfig = .default
    ) async -> (PropertyResult<T>, CoverageReport)

    public func runPropertyWithCoverageGuidance<T>(
      _ property: Property<T>,
      collector: CoverageCollector,
      config: PropertyConfig = .default,
      coverageStrategy: CoverageStrategy = .adaptive
    ) async -> (PropertyResult<T>, CoverageReport)
  }
  ```
- **Recommendation:** Defer until PropertyRunner coverage methods are implemented

## CoverageCompletionTests.swift.disabled (DEFERRED)

- **Feature:** Coverage completion testing (targets final 0.01% coverage gaps)
- **Status:** Similar to CoverageGuidedTests - core types exist, integration methods missing
- **Reason:** Same PropertyRunner extension methods required
- **Unblock:** Same as CoverageGuidedTests.swift
- **Recommendation:** Defer until PropertyRunner coverage methods are implemented

## Files NOT Deferred (Successfully Re-enabled in Plan 07)

The following files were successfully re-enabled with zero compile errors:

1. **SMTSolverTests.swift** ✅ - SMT solver integration tests (requires InvariantSwiftExperimental)
2. **MetamorphicTests.swift** ✅ - Metamorphic property testing (requires InvariantSwiftExperimental)
3. **GeneratorRegistryTests.swift** ✅ - Generator registry actor tests (requires InvariantSwiftExperimental)

## Files From Other Plans (Not in Plan 07 Scope)

The following files exist but were addressed in other plans:

- CollectionGeneratorTests.swift.disabled - Wave 1 (Plan 04.7-05 or 04.7-06)
- CollectionShrinkingV2Tests.swift.disabled - Wave 1 (Plan 04.7-05 or 04.7-06)
- FailurePersistenceTests.swift.disabled - Wave 1 (Plan 04.7-05 or 04.7-06)
- FloatingPointModeTests.swift.disabled - Wave 1 (Plan 04.7-05 or 04.7-06)
- LibFuzzerTests.swift.disabled - Wave 1 (Plan 04.7-05 or 04.7-06)
- MetaPropertyTests.swift.disabled - Wave 1 (Plan 04.7-05 or 04.7-06)
- NumericGeneratorTests.swift.disabled - Wave 1 (Plan 04.7-05 or 04.7-06)
- PrettyPrinterEnhancementTests.swift.disabled - Wave 1 (Plan 04.7-05 or 04.7-06)

## Deleted Files (Superseded)

- **LawGeneration.swift.disabled** ❌ DELETED - Superseded by LawCheckedMacro.swift (exposed in Phase 4.2, Plan 04.2-01)
  - Old macro implementation with FunctorLaws, ApplicativeLaws, MonadLaws macros
  - Replaced by comprehensive @LawChecked(laws: [...]) macro with 18 mathematical law types
  - No migration needed - @LawChecked provides equivalent and superior functionality

## Summary

**Plan 07 Target Files:** 8 files total
- 3 experimental feature test files (SMT, Linearizability, Lens)
- 4 advanced feature test files (Metamorphic, Registry, Coverage×2)
- 1 source file (LawGeneration.swift.disabled)

**Successfully Re-enabled:** 3/7 test files (43% success rate)
- SMTSolverTests.swift
- MetamorphicTests.swift
- GeneratorRegistryTests.swift

**Deferred:** 4/7 test files (57% - acceptable for experimental/incomplete features)
- LinearizabilityTests.swift (Operation type not generic)
- LensSystemTests.swift (PropertyConfig lens extensions missing)
- CoverageGuidedTests.swift (PropertyRunner coverage methods missing)
- CoverageCompletionTests.swift (PropertyRunner coverage methods missing)

**Deleted:** 1 source file (superseded implementation)
- LawGeneration.swift.disabled

**Technical Debt:** Coverage-guided PropertyRunner integration (estimated 2-4 hours work)

**Next Steps:**
1. Implement PropertyRunner+Coverage.swift extension methods
2. Re-enable deferred test files with skip conditions for missing methods
3. Add test skipping pattern: `try? skipIfMethodMissing("runPropertyWithCoverageTracking")`
