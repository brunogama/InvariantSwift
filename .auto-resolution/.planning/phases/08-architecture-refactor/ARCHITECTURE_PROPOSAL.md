# InvariantSwift Architecture Refactoring Proposal

**Author:** Claude (AI Architecture Analysis)  
**Date:** 2026-01-30  
**Priority:** High - Swift-Syntax Isolation & Clean Target Separation

## Executive Summary

This proposal addresses the current architectural issues in InvariantSwift with a focus on:
1. **Isolating swift-syntax dependencies** to compile-time-only targets
2. **Eliminating shared source paths** with complex exclude lists
3. **Creating clean dependency boundaries** between targets
4. **Reducing build times** for consumers who don't need macros

---

## Current Architecture Problems

### 1. Swift-Syntax Pollution

Currently, swift-syntax dependencies leak into:
- `InvariantSwiftMacros` (necessary - macro implementation)
- `GhostwriterLib` (necessary - source parsing)
- `GhostwriterCLI` (necessary - CLI tool)
- `InvariantSwiftMacroTests` (necessary - macro testing)
- `InvariantSwiftTests` (unnecessary - depends on GhostwriterLib)

**Impact:** Any consumer importing `InvariantSwift` + `InvariantSwiftTesting` indirectly pulls swift-syntax into their dependency graph via transitive test target dependencies.

### 2. Shared Source Path Anti-Pattern

Multiple targets share `Sources/InvariantSwift/` with different exclude lists:

```swift
// Current problematic structure:
.target(name: "InvariantSwiftCore", path: "Sources/InvariantSwift", sources: ["Core"])
.target(name: "InvariantSwift", path: "Sources/InvariantSwift", exclude: [...17 items...])
.target(name: "InvariantSwiftTesting", path: "Sources/InvariantSwift", exclude: [...14 items...])
.target(name: "InvariantSwiftExperimental", path: "Sources/InvariantSwift", exclude: [...12 items...])
```

**Problems:**
- Easy to accidentally include/exclude wrong files
- IDE navigation is confusing
- Build system can't parallelize properly
- Hard to understand what belongs where

### 3. Macro Declaration/Implementation Split

Macro declarations (the `@attached(peer) public macro Property(...)` code) currently live in:
- `Sources/InvariantSwift/Macros/` - Runtime declarations (no swift-syntax)
- `Sources/InvariantSwiftMacros/` - Compile-time implementations (swift-syntax)

This is actually correct! But the dependency structure is confused:
- `InvariantSwiftTesting` depends on `InvariantSwiftMacros` (the implementation)
- Should instead depend on a declarations-only target

### 4. Duplicate Ghostwriter Implementations

- `Sources/InvariantSwift/Ghostwriter/` - Runtime ghostwriter (no swift-syntax)
- `Sources/GhostwriterLib/` - CLI ghostwriter with swift-syntax for parsing

These do different things but have confusingly similar names.

---

## Proposed Architecture

### Target Dependency Graph

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                    COMPILE-TIME ONLY                        │
                    │              (swift-syntax isolated here)                   │
                    │                                                             │
                    │  ┌─────────────────┐     ┌──────────────────────┐          │
                    │  │InvariantSwift   │     │GhostwriterSyntax     │          │
                    │  │MacroImpl        │     │(swift-syntax parsing)│          │
                    │  │(swift-syntax)   │     └──────────┬───────────┘          │
                    │  └────────┬────────┘                │                       │
                    │           │                         │                       │
                    │           │              ┌──────────▼───────────┐          │
                    │           │              │GhostwriterCLI        │          │
                    │           │              │(executable)          │          │
                    │           │              └──────────────────────┘          │
                    └───────────┼──────────────────────────────────────────────────┘
                                │
                    ════════════╪══════════════════════════════════════════════════
                                │ (macro boundary - no runtime dependency)
                    ════════════╪══════════════════════════════════════════════════
                                │
          ┌─────────────────────┴─────────────────────────┐
          │                  RUNTIME TARGETS               │
          │            (zero swift-syntax dependency)      │
          │                                                │
          │   ┌──────────────────────────────────────┐    │
          │   │         InvariantSwiftCore           │    │
          │   │  (Gen, Shrink, Property, ShrinkTree) │    │
          │   │         ZERO DEPENDENCIES            │    │
          │   └──────────────────┬───────────────────┘    │
          │                      │                         │
          │        ┌─────────────┼─────────────┐          │
          │        ▼             ▼             ▼          │
          │   ┌─────────┐  ┌──────────┐  ┌───────────┐   │
          │   │Generators│  │Execution │  │Persistence│   │
          │   │(numeric, │  │(runners, │  │(database, │   │
          │   │ string,  │  │ config,  │  │ corpus,   │   │
          │   │collection)│  │ testing) │  │ replay)   │   │
          │   └─────┬────┘  └────┬─────┘  └─────┬─────┘   │
          │         │            │              │          │
          │         └────────────┼──────────────┘          │
          │                      ▼                         │
          │              ┌───────────────┐                │
          │              │InvariantSwift │                │
          │              │ (main library)│                │
          │              └───────┬───────┘                │
          │                      │                         │
          │    ┌─────────────────┼─────────────────┐      │
          │    ▼                 ▼                 ▼      │
          │ ┌────────┐    ┌───────────┐    ┌──────────┐  │
          │ │MacroAPI│    │Experimental│    │Domain    │  │
          │ │(decls  │    │(advanced,  │    │Generators│  │
          │ │ only)  │    │ coverage)  │    │(faker)   │  │
          │ └───┬────┘    └─────┬─────┘    └────┬─────┘  │
          │     │               │               │         │
          │     └───────────────┼───────────────┘         │
          │                     ▼                         │
          │            ┌─────────────────┐               │
          │            │InvariantSwift   │               │
          │            │Testing          │               │
          │            │(Swift Testing   │               │
          │            │ integration)    │               │
          │            └─────────────────┘               │
          └────────────────────────────────────────────────┘
```

### Directory Structure

```
Sources/
├── InvariantSwiftCore/           # NEW: Dedicated directory
│   ├── Gen.swift
│   ├── Shrink.swift
│   ├── ShrinkTree.swift
│   ├── Property.swift
│   ├── Seed.swift
│   ├── Size.swift
│   ├── AnySendable.swift
│   ├── AnyCodable.swift
│   └── ... (other Core files)
│
├── InvariantSwiftGenerators/     # NEW: Dedicated directory
│   ├── PrimitiveGenerators.swift
│   ├── NumericGenerators.swift
│   ├── CollectionGenerators.swift
│   ├── CombinatorGenerators.swift
│   ├── OptionalResultGenerators.swift
│   └── FloatingPointMode.swift
│
├── InvariantSwiftExecution/      # NEW: Dedicated directory
│   ├── PropertyRunner.swift
│   ├── PropertyConfig.swift
│   ├── IsolatedPropertyRunner.swift
│   ├── SubprocessIsolation.swift
│   └── ... (testing infrastructure)
│
├── InvariantSwiftPersistence/    # NEW: Dedicated directory
│   ├── ExampleDatabase.swift
│   ├── CorpusDatabase.swift
│   ├── RegressionBank.swift
│   ├── ReplayToken.swift
│   └── ... (persistence files)
│
├── InvariantSwift/               # REFACTORED: Umbrella + unique files only
│   ├── InvariantSwift.swift      # Re-exports
│   ├── Contract/                 # Unique to main library
│   ├── Differential/
│   ├── Ghostwriter/              # Runtime ghostwriter (no swift-syntax)
│   └── Presentation/
│
├── InvariantSwiftMacroAPI/       # NEW: Macro declarations only (no swift-syntax!)
│   ├── PropertyMacroDeclaration.swift
│   ├── ArbitraryMacroDeclaration.swift
│   ├── GenMacroDeclaration.swift
│   ├── GeneratorExpression.swift  # DSL types
│   └── ... (all macro declarations)
│
├── InvariantSwiftMacroImpl/      # RENAMED from InvariantSwiftMacros
│   ├── MacroPlugin.swift         # swift-syntax dependency HERE
│   ├── PropertyMacro/
│   ├── ArbitraryMacro/
│   └── ... (implementations)
│
├── InvariantSwiftExperimental/   # NEW: Dedicated directory
│   ├── Advanced/
│   ├── Coverage/
│   ├── Fuzzing/
│   ├── Reliability/
│   └── Observability/
│
├── InvariantSwiftTesting/        # NEW: Dedicated directory
│   ├── SwiftTestingIntegration.swift
│   ├── FailureReporting.swift
│   ├── ExpectDifference.swift
│   └── ... (Swift Testing bridge)
│
├── InvariantSwiftDomainGenerators/  # UNCHANGED
│   └── ...
│
├── GhostwriterSyntax/            # RENAMED from GhostwriterLib
│   ├── SwiftSyntaxTypeExtractor.swift
│   ├── CompileVerifier.swift
│   └── ... (swift-syntax parsing)
│
└── GhostwriterCLI/               # UNCHANGED
    └── ...
```

---

## Package.swift Refactoring

### New Target Definitions

```swift
// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "InvariantSwift",
  platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10)],
  
  products: [
    // MAIN PRODUCTS (no swift-syntax)
    .library(name: "InvariantSwiftCore", targets: ["InvariantSwiftCore"]),
    .library(name: "InvariantSwift", targets: ["InvariantSwift"]),
    .library(name: "InvariantSwiftTesting", targets: ["InvariantSwiftTesting"]),
    .library(name: "InvariantSwiftExperimental", targets: ["InvariantSwiftExperimental"]),
    .library(name: "InvariantSwiftDomainGenerators", targets: ["InvariantSwiftDomainGenerators"]),
    
    // COMPILE-TIME ONLY (swift-syntax isolated)
    // Note: Macro targets are automatically available, no explicit product needed
    
    // PLUGINS
    .plugin(name: "GhostwriterPlugin", targets: ["GhostwriterPlugin"]),
  ],
  
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
    .package(url: "https://github.com/google/swift-benchmark", from: "0.1.2"),
  ],
  
  targets: [
    // ══════════════════════════════════════════════════════════════════
    // LAYER 0: CORE (Zero Dependencies)
    // ══════════════════════════════════════════════════════════════════
    .target(
      name: "InvariantSwiftCore",
      dependencies: [],
      path: "Sources/InvariantSwiftCore"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // LAYER 1: INTERNAL MODULES (Depend only on Core)
    // ══════════════════════════════════════════════════════════════════
    .target(
      name: "InvariantSwiftGenerators",
      dependencies: ["InvariantSwiftCore"],
      path: "Sources/InvariantSwiftGenerators"
    ),
    
    .target(
      name: "InvariantSwiftExecution",
      dependencies: ["InvariantSwiftCore"],
      path: "Sources/InvariantSwiftExecution"
    ),
    
    .target(
      name: "InvariantSwiftPersistence",
      dependencies: ["InvariantSwiftCore"],
      path: "Sources/InvariantSwiftPersistence"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // LAYER 2: MAIN LIBRARY (Combines internal modules)
    // ══════════════════════════════════════════════════════════════════
    .target(
      name: "InvariantSwift",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwiftGenerators",
        "InvariantSwiftExecution",
        "InvariantSwiftPersistence",
      ],
      path: "Sources/InvariantSwift"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // LAYER 3: MACRO API (Declarations only - NO swift-syntax!)
    // ══════════════════════════════════════════════════════════════════
    .target(
      name: "InvariantSwiftMacroAPI",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwift",
      ],
      path: "Sources/InvariantSwiftMacroAPI"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // LAYER 3: EXPERIMENTAL (Advanced features)
    // ══════════════════════════════════════════════════════════════════
    .target(
      name: "InvariantSwiftExperimental",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwift",
      ],
      path: "Sources/InvariantSwiftExperimental"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // LAYER 4: TESTING INTEGRATION (Swift Testing bridge)
    // ══════════════════════════════════════════════════════════════════
    .target(
      name: "InvariantSwiftTesting",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwift",
        "InvariantSwiftExperimental",
        "InvariantSwiftMacroAPI",  // Declarations only!
        "InvariantSwiftMacroImpl", // Macro implementation
      ],
      path: "Sources/InvariantSwiftTesting"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // LAYER 4: DOMAIN GENERATORS (Optional add-on)
    // ══════════════════════════════════════════════════════════════════
    .target(
      name: "InvariantSwiftDomainGenerators",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwift",
      ],
      path: "Sources/InvariantSwiftDomainGenerators"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // COMPILE-TIME TARGETS (swift-syntax ISOLATED here)
    // ══════════════════════════════════════════════════════════════════
    .macro(
      name: "InvariantSwiftMacroImpl",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ],
      path: "Sources/InvariantSwiftMacroImpl"
    ),
    
    .target(
      name: "GhostwriterSyntax",
      dependencies: [
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ],
      path: "Sources/GhostwriterSyntax"
    ),
    
    .executableTarget(
      name: "GhostwriterCLI",
      dependencies: ["GhostwriterSyntax"],
      path: "Sources/GhostwriterCLI"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // PLUGINS
    // ══════════════════════════════════════════════════════════════════
    .plugin(
      name: "GhostwriterPlugin",
      capability: .command(
        intent: .custom(verb: "ghostwrite", description: "Generate property tests"),
        permissions: [.writeToPackageDirectory(reason: "Generate test files")]
      ),
      dependencies: ["GhostwriterCLI"],
      path: "Plugins/GhostwriterPlugin"
    ),
    
    // ══════════════════════════════════════════════════════════════════
    // TEST TARGETS
    // ══════════════════════════════════════════════════════════════════
    .testTarget(
      name: "InvariantSwiftCoreTests",
      dependencies: ["InvariantSwiftCore"],
      path: "Tests/InvariantSwiftCoreTests"
    ),
    
    .testTarget(
      name: "InvariantSwiftTests",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwift",
        "InvariantSwiftTesting",
        "InvariantSwiftExperimental",
        // NO GhostwriterSyntax here!
      ],
      path: "Tests/InvariantSwiftTests"
    ),
    
    .testTarget(
      name: "InvariantSwiftMacroTests",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwiftMacroImpl",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      path: "Tests/InvariantSwiftMacroTests"
    ),
    
    .testTarget(
      name: "GhostwriterSyntaxTests",
      dependencies: ["GhostwriterSyntax"],
      path: "Tests/GhostwriterSyntaxTests"
    ),
  ]
)
```

---

## Migration Strategy

### Phase 1: Create New Directory Structure (Non-Breaking)

1. Create new directories under `Sources/`
2. **Copy** (don't move) files to new locations
3. Update new Package.swift with new targets
4. Verify everything compiles

### Phase 2: Update Imports and Dependencies

1. Update import statements in moved files
2. Add `@_exported import` where needed for API compatibility
3. Run full test suite
4. Fix any broken dependencies

### Phase 3: Remove Old Structure

1. Remove duplicate files from old locations
2. Clean up old exclude lists
3. Update CI/CD pipelines
4. Update documentation

### Phase 4: Verification

1. Build clean (delete `.build/`)
2. Run all tests
3. Check that consumers can still import as before
4. Measure build time improvements

---

## Benefits

### 1. Swift-Syntax Isolation ✓

- **Main library users** (`InvariantSwift`, `InvariantSwiftTesting`) never see swift-syntax
- **Only compile-time targets** (`InvariantSwiftMacroImpl`, `GhostwriterSyntax`) depend on swift-syntax
- **Build times improve** for projects not using macros

### 2. Clean Target Boundaries ✓

- Each target has its **own source directory**
- No more **exclude lists** to maintain
- **IDE navigation** is clear
- **Build parallelization** works correctly

### 3. Explicit Dependencies ✓

- Every dependency is **intentional and visible**
- No **transitive pollution** through shared paths
- **Easier to reason about** what depends on what

### 4. API Stability ✓

- `InvariantSwiftMacroAPI` contains **stable macro declarations**
- `InvariantSwiftMacroImpl` contains **implementation details**
- Can update **implementation without breaking API**

### 5. Testability ✓

- Each module can be **tested in isolation**
- **Macro tests** are separate from **runtime tests**
- **Ghostwriter syntax tests** are separate from **main library tests**

---

## Backwards Compatibility

### Public API Preservation

The public API surface remains identical:

```swift
// These imports continue to work:
import InvariantSwift
import InvariantSwiftCore
import InvariantSwiftTesting
import InvariantSwiftExperimental
import InvariantSwiftDomainGenerators

// Macros continue to work:
@Property func test(x: Int) -> Bool { ... }
@Arbitrary struct MyType { ... }
```

### Re-export Strategy

`InvariantSwift/InvariantSwift.swift`:
```swift
@_exported import InvariantSwiftCore
@_exported import InvariantSwiftGenerators
@_exported import InvariantSwiftExecution
@_exported import InvariantSwiftPersistence
```

`InvariantSwiftTesting/InvariantSwiftTesting.swift`:
```swift
@_exported import InvariantSwiftCore
@_exported import InvariantSwift
@_exported import InvariantSwiftMacroAPI
```

---

## Estimated Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Targets with swift-syntax | 5 | 3 | 40% reduction |
| Exclude list entries | 43 | 0 | 100% elimination |
| Build parallelization | Limited | Full | Significant |
| Clean build time (est.) | 100% | ~70% | 30% faster |
| Incremental build | Limited | Optimal | Significant |

---

## Implementation Checklist

- [ ] Create `Sources/InvariantSwiftCore/` directory
- [ ] Create `Sources/InvariantSwiftGenerators/` directory
- [ ] Create `Sources/InvariantSwiftExecution/` directory
- [ ] Create `Sources/InvariantSwiftPersistence/` directory
- [ ] Create `Sources/InvariantSwiftMacroAPI/` directory
- [ ] Create `Sources/InvariantSwiftExperimental/` directory
- [ ] Create `Sources/InvariantSwiftTesting/` directory
- [ ] Rename `Sources/InvariantSwiftMacros/` → `Sources/InvariantSwiftMacroImpl/`
- [ ] Rename `Sources/GhostwriterLib/` → `Sources/GhostwriterSyntax/`
- [ ] Move files to appropriate directories
- [ ] Update all import statements
- [ ] Create re-export umbrella files
- [ ] Update Package.swift
- [ ] Create new test target directories
- [ ] Move/update test files
- [ ] Run full test suite
- [ ] Update documentation
- [ ] Update CI/CD workflows

---

## Questions for Review

1. Should `InvariantSwiftGenerators`, `InvariantSwiftExecution`, `InvariantSwiftPersistence` be public products or internal modules?
2. Should we keep the umbrella `InvariantSwift` target or expose granular imports?
3. Is there value in keeping both `@_exported` re-exports and explicit imports?
4. Should `GhostwriterSyntax` be a public product for tools that want to parse Swift?
