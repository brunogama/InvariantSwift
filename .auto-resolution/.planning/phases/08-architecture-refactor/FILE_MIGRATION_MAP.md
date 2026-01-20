# File Migration Map

This document maps every file from the current structure to its destination in the new architecture.

## Legend

- ✅ = Move file
- 🔗 = Create re-export/reference
- 🆕 = New file to create
- ❌ = Delete/deprecate

---

## Sources/InvariantSwift/Core/ → Sources/InvariantSwiftCore/

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Core/AnyCodable.swift` | ✅ | `InvariantSwiftCore/AnyCodable.swift` |
| `Core/AnySendable.swift` | ✅ | `InvariantSwiftCore/AnySendable.swift` |
| `Core/BusinessRuleViolation.swift` | ✅ | `InvariantSwiftCore/BusinessRuleViolation.swift` |
| `Core/ClassificationContext.swift` | ✅ | `InvariantSwiftCore/ClassificationContext.swift` |
| `Core/ClassificationReport.swift` | ✅ | `InvariantSwiftCore/ClassificationReport.swift` |
| `Core/ClassifyingProperty.swift` | ✅ | `InvariantSwiftCore/ClassifyingProperty.swift` |
| `Core/ClassifyingPropertyRunner.swift` | ✅ | `InvariantSwiftCore/ClassifyingPropertyRunner.swift` |
| `Core/FailingExample.swift` | ✅ | `InvariantSwiftCore/FailingExample.swift` |
| `Core/FailureReport.swift` | ✅ | `InvariantSwiftCore/FailureReport.swift` |
| `Core/ForAll.swift` | ✅ | `InvariantSwiftCore/ForAll.swift` |
| `Core/Gen.swift` | ✅ | `InvariantSwiftCore/Gen.swift` |
| `Core/Generatable.swift` | ✅ | `InvariantSwiftCore/Generatable.swift` |
| `Core/Generator+String.swift` | ✅ | `InvariantSwiftCore/Generator+String.swift` |
| `Core/GeneratorConstraint.swift` | ✅ | `InvariantSwiftCore/GeneratorConstraint.swift` |
| `Core/ModelTesting.swift` | ✅ | `InvariantSwiftCore/ModelTesting.swift` |
| `Core/Property+Classification.swift` | ✅ | `InvariantSwiftCore/Property+Classification.swift` |
| `Core/Property+Combinators.swift` | ✅ | `InvariantSwiftCore/Property+Combinators.swift` |
| `Core/Property+Implication.swift` | ✅ | `InvariantSwiftCore/Property+Implication.swift` |
| `Core/Property.swift` | ✅ | `InvariantSwiftCore/Property.swift` |
| `Core/PropertyConfig+Helpers.swift` | ✅ | `InvariantSwiftCore/PropertyConfig+Helpers.swift` |
| `Core/PropertyExecution.swift` | ✅ | `InvariantSwiftCore/PropertyExecution.swift` |
| `Core/PropertyResult+Extensions.swift` | ✅ | `InvariantSwiftCore/PropertyResult+Extensions.swift` |
| `Core/PropertyTimeout.swift` | ✅ | `InvariantSwiftCore/PropertyTimeout.swift` |
| `Core/RuleBasedStateMachine.swift` | ✅ | `InvariantSwiftCore/RuleBasedStateMachine.swift` |
| `Core/RunReport.swift` | ✅ | `InvariantSwiftCore/RunReport.swift` |
| `Core/RunReportBuilder.swift` | ✅ | `InvariantSwiftCore/RunReportBuilder.swift` |
| `Core/Seed.swift` | ✅ | `InvariantSwiftCore/Seed.swift` |
| `Core/Shrink.swift` | ✅ | `InvariantSwiftCore/Shrink.swift` |
| `Core/ShrinkTree+Parallel.swift` | ✅ | `InvariantSwiftCore/ShrinkTree+Parallel.swift` |
| `Core/ShrinkTree.swift` | ✅ | `InvariantSwiftCore/ShrinkTree.swift` |
| `Core/SizeType.swift` | ✅ | `InvariantSwiftCore/SizeType.swift` |

**Files staying in Core but moving to Execution:**

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Core/ExampleDatabase.swift` | ✅ | `InvariantSwiftPersistence/ExampleDatabase.swift` |
| `Core/IsolatedPropertyRunner.swift` | ✅ | `InvariantSwiftExecution/IsolatedPropertyRunner.swift` |
| `Core/PropertyRunner+Discard.swift` | ✅ | `InvariantSwiftExecution/PropertyRunner+Discard.swift` |
| `Core/PropertyRunner+Progress.swift` | ✅ | `InvariantSwiftExecution/PropertyRunner+Progress.swift` |
| `Core/RegressionBank.swift` | ✅ | `InvariantSwiftPersistence/RegressionBank.swift` |
| `Core/ReplayToken.swift` | ✅ | `InvariantSwiftPersistence/ReplayToken.swift` |
| `Core/SubprocessIsolation.swift` | ✅ | `InvariantSwiftExecution/SubprocessIsolation.swift` |

---

## Sources/InvariantSwift/Generators/ → Sources/InvariantSwiftGenerators/

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Generators/CollectionGenerators.swift` | ✅ | `InvariantSwiftGenerators/CollectionGenerators.swift` |
| `Generators/CombinatorGenerators.swift` | ✅ | `InvariantSwiftGenerators/CombinatorGenerators.swift` |
| `Generators/FloatingPointMode.swift` | ✅ | `InvariantSwiftGenerators/FloatingPointMode.swift` |
| `Generators/Generatable+Primitives.swift` | ✅ | `InvariantSwiftGenerators/Generatable+Primitives.swift` |
| `Generators/NumericGenerators.swift` | ✅ | `InvariantSwiftGenerators/NumericGenerators.swift` |
| `Generators/OptionalResultGenerators.swift` | ✅ | `InvariantSwiftGenerators/OptionalResultGenerators.swift` |
| `Generators/PrimitiveGenerators.swift` | ✅ | `InvariantSwiftGenerators/PrimitiveGenerators.swift` |

---

## Sources/InvariantSwift/Testing/ → Sources/InvariantSwiftExecution/

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Testing/ConfigBuilder.swift` | ✅ | `InvariantSwiftExecution/ConfigBuilder.swift` |
| `Testing/ConfigTemplate.swift` | ✅ | `InvariantSwiftExecution/ConfigTemplate.swift` |
| `Testing/GeneratorTestHelpers.swift` | ✅ | `InvariantSwiftExecution/GeneratorTestHelpers.swift` |
| `Testing/TargetCollector.swift` | ✅ | `InvariantSwiftExecution/TargetCollector.swift` |
| `Testing/TargetedConfig.swift` | ✅ | `InvariantSwiftExecution/TargetedConfig.swift` |
| `Testing/TargetedRunner.swift` | ✅ | `InvariantSwiftExecution/TargetedRunner.swift` |
| `Testing/TargetedTesting.swift` | ✅ | `InvariantSwiftExecution/TargetedTesting.swift` |

---

## Sources/InvariantSwift/Database/ → Sources/InvariantSwiftPersistence/

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Database/CorpusDatabase.swift` | ✅ | `InvariantSwiftPersistence/CorpusDatabase.swift` |

---

## Sources/InvariantSwift/Macros/ → Sources/InvariantSwiftMacroAPI/

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Macros/ArbitraryMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/ArbitraryMacroDeclaration.swift` |
| `Macros/BusinessRuleMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/BusinessRuleMacroDeclaration.swift` |
| `Macros/DeriveGenMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/DeriveGenMacroDeclaration.swift` |
| `Macros/DeterministicMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/DeterministicMacroDeclaration.swift` |
| `Macros/EquivalenceMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/EquivalenceMacroDeclaration.swift` |
| `Macros/IdempotentMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/IdempotentMacroDeclaration.swift` |
| `Macros/LawCheckedMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/LawCheckedMacroDeclaration.swift` |
| `Macros/PropertyMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/PropertyMacroDeclaration.swift` |
| `Macros/PureMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/PureMacroDeclaration.swift` |
| `Macros/RegressionMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/RegressionMacroDeclaration.swift` |
| `Macros/ShrinkTowardsMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/ShrinkTowardsMacroDeclaration.swift` |
| `Macros/StateMachineMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/StateMachineMacroDeclaration.swift` |
| `Macros/TimeoutMacroDeclaration.swift` | ✅ | `InvariantSwiftMacroAPI/TimeoutMacroDeclaration.swift` |

---

## Sources/InvariantSwift/SwiftTesting/ → Sources/InvariantSwiftTesting/

| Current File | Action | New Location |
|--------------|--------|--------------|
| `SwiftTesting/ExpectDifference.swift` | ✅ | `InvariantSwiftTesting/ExpectDifference.swift` |
| `SwiftTesting/FailurePersistence.swift` | ✅ | `InvariantSwiftTesting/FailurePersistence.swift` |
| `SwiftTesting/FailureReporting.swift` | ✅ | `InvariantSwiftTesting/FailureReporting.swift` |
| `SwiftTesting/PropertyTestIntegration.swift` | ✅ | `InvariantSwiftTesting/PropertyTestIntegration.swift` |
| `SwiftTesting/TestStatistics.swift` | ✅ | `InvariantSwiftTesting/TestStatistics.swift` |

---

## Sources/InvariantSwift/Advanced/ → Sources/InvariantSwiftExperimental/Advanced/

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Advanced/AsyncProperties.swift` | ✅ | `InvariantSwiftExperimental/Advanced/AsyncProperties.swift` |
| `Advanced/CoverageGuided.swift` | ✅ | `InvariantSwiftExperimental/Advanced/CoverageGuided.swift` |
| `Advanced/DICE.swift` | ✅ | `InvariantSwiftExperimental/Advanced/DICE.swift` |
| `Advanced/FunctionComposition.swift` | ✅ | `InvariantSwiftExperimental/Advanced/FunctionComposition.swift` |
| `Advanced/Generator+Middleware.swift` | ✅ | `InvariantSwiftExperimental/Advanced/Generator+Middleware.swift` |
| `Advanced/GeneratorMiddleware.swift` | ✅ | `InvariantSwiftExperimental/Advanced/GeneratorMiddleware.swift` |
| `Advanced/GeneratorRegistry.swift` | ✅ | `InvariantSwiftExperimental/Advanced/GeneratorRegistry.swift` |
| `Advanced/InvariantMining.swift` | ✅ | `InvariantSwiftExperimental/Advanced/InvariantMining.swift` |
| `Advanced/LensSystem.swift` | ✅ | `InvariantSwiftExperimental/Advanced/LensSystem.swift` |
| `Advanced/Linearizability.swift` | ✅ | `InvariantSwiftExperimental/Advanced/Linearizability.swift` |
| `Advanced/Metamorphic.swift` | ✅ | `InvariantSwiftExperimental/Advanced/Metamorphic.swift` |
| `Advanced/ParallelShrinker.swift` | ✅ | `InvariantSwiftExperimental/Advanced/ParallelShrinker.swift` |
| `Advanced/PropertyEffect.swift` | ✅ | `InvariantSwiftExperimental/Advanced/PropertyEffect.swift` |
| `Advanced/PropertyEffectExecutor.swift` | ✅ | `InvariantSwiftExperimental/Advanced/PropertyEffectExecutor.swift` |
| `Advanced/PropertyRunner+Coverage.swift` | ✅ | `InvariantSwiftExperimental/Advanced/PropertyRunner+Coverage.swift` |
| `Advanced/Scheduler.swift` | ✅ | `InvariantSwiftExperimental/Advanced/Scheduler.swift` |
| `Advanced/ShrinkHints.swift` | ✅ | `InvariantSwiftExperimental/Advanced/ShrinkHints.swift` |
| `Advanced/ShrinkPredicates.swift` | ✅ | `InvariantSwiftExperimental/Advanced/ShrinkPredicates.swift` |
| `Advanced/SMTSolver.swift` | ✅ | `InvariantSwiftExperimental/Advanced/SMTSolver.swift` |

---

## Other Experimental subdirectories

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Coverage/ClassificationCoverage.swift` | ✅ | `InvariantSwiftExperimental/Coverage/ClassificationCoverage.swift` |
| `Extensions/PropertyConfig+Lenses.swift` | ✅ | `InvariantSwiftExperimental/Extensions/PropertyConfig+Lenses.swift` |
| `Extensions/Seed+Lenses.swift` | ✅ | `InvariantSwiftExperimental/Extensions/Seed+Lenses.swift` |
| `Extensions/Size+Lenses.swift` | ✅ | `InvariantSwiftExperimental/Extensions/Size+Lenses.swift` |
| `Fuzzing/LibFuzzerIntegration.swift` | ✅ | `InvariantSwiftExperimental/Fuzzing/LibFuzzerIntegration.swift` |
| `Observability/TelemetrySystem.swift` | ✅ | `InvariantSwiftExperimental/Observability/TelemetrySystem.swift` |
| `Reliability/FlakeHunter.swift` | ✅ | `InvariantSwiftExperimental/Reliability/FlakeHunter.swift` |
| `Reliability/FlakeHunter+PropertyTest.swift` | ✅ | `InvariantSwiftExperimental/Reliability/FlakeHunter+PropertyTest.swift` |

---

## Files staying in InvariantSwift (main library)

| Current File | Action | New Location |
|--------------|--------|--------------|
| `Contract/ContractTesting.swift` | ✅ stays | `InvariantSwift/Contract/ContractTesting.swift` |
| `Differential/DifferentialTesting.swift` | ✅ stays | `InvariantSwift/Differential/DifferentialTesting.swift` |
| `Ghostwriter/*` | ✅ stays | `InvariantSwift/Ghostwriter/*` |
| `Presentation/*` | ✅ stays | `InvariantSwift/Presentation/*` |
| `FunctionalTesting.swift` | 🆕 rewrite | `InvariantSwift/InvariantSwift.swift` (becomes umbrella) |

---

## Sources/InvariantSwiftMacros/ → Sources/InvariantSwiftMacroImpl/

Rename entire directory (contents unchanged):

```
InvariantSwiftMacros/ → InvariantSwiftMacroImpl/
```

---

## Sources/GhostwriterLib/ → Sources/GhostwriterSyntax/

Rename entire directory (contents unchanged):

```
GhostwriterLib/ → GhostwriterSyntax/
```

---

## New Files to Create

### 🆕 Sources/InvariantSwiftCore/InvariantSwiftCore.swift (umbrella)

```swift
// Re-exports nothing - InvariantSwiftCore is the base
// All types are defined here
```

### 🆕 Sources/InvariantSwiftGenerators/InvariantSwiftGenerators.swift (umbrella)

```swift
@_exported import InvariantSwiftCore
```

### 🆕 Sources/InvariantSwiftExecution/InvariantSwiftExecution.swift (umbrella)

```swift
@_exported import InvariantSwiftCore
```

### 🆕 Sources/InvariantSwiftPersistence/InvariantSwiftPersistence.swift (umbrella)

```swift
@_exported import InvariantSwiftCore
```

### 🆕 Sources/InvariantSwift/InvariantSwift.swift (umbrella)

```swift
// Main library re-exports
@_exported import InvariantSwiftCore
@_exported import InvariantSwiftGenerators
@_exported import InvariantSwiftExecution
@_exported import InvariantSwiftPersistence
```

### 🆕 Sources/InvariantSwiftMacroAPI/InvariantSwiftMacroAPI.swift (umbrella)

```swift
@_exported import InvariantSwiftCore
@_exported import InvariantSwift
// All macro declarations are in this module
```

### 🆕 Sources/InvariantSwiftExperimental/InvariantSwiftExperimental.swift (umbrella)

```swift
@_exported import InvariantSwiftCore
@_exported import InvariantSwift
```

### 🆕 Sources/InvariantSwiftTesting/InvariantSwiftTesting.swift (umbrella)

```swift
@_exported import InvariantSwiftCore
@_exported import InvariantSwift
@_exported import InvariantSwiftExperimental
@_exported import InvariantSwiftMacroAPI
```

---

## Test Directory Restructuring

| Current Directory | New Directory |
|-------------------|---------------|
| `Tests/InvariantSwiftTests/` | `Tests/InvariantSwiftTests/` (unchanged) |
| `Tests/InvariantSwiftMacroTests/` | `Tests/InvariantSwiftMacroTests/` (unchanged) |
| N/A | 🆕 `Tests/InvariantSwiftCoreTests/` |
| N/A | 🆕 `Tests/GhostwriterSyntaxTests/` |

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Files to move | ~85 |
| New umbrella files | 8 |
| Directories to create | 8 |
| Directories to rename | 2 |
| Exclude lists eliminated | 4 (43 entries) |
