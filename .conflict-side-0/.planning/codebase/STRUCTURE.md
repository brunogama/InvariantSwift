# Codebase Structure

**Analysis Date:** 2026-01-23

## Directory Layout

```
InvariantSwift/
├── Sources/                              # All source code
│   ├── InvariantSwift/                   # Main library (multiple targets)
│   │   ├── Core/                         # Foundation types (Gen, Property, Shrink, Seed)
│   │   ├── Generators/                   # Generator implementations (primitive, collection, combinator)
│   │   ├── Advanced/                     # Experimental advanced features (coverage, linearizability, etc)
│   │   ├── SwiftTesting/                 # Swift Testing framework integration
│   │   ├── Testing/                      # Test execution engine and runners
│   │   ├── Macros/                       # Macro declarations (@PropertyTest, @Arbitrary, etc)
│   │   ├── Presentation/                 # Pretty-printing and output formatting
│   │   ├── Persistence/                  # Shrink tree serialization
│   │   ├── Database/                     # Corpus database (SQLite-backed)
│   │   ├── Ghostwriter/                  # Auto-test generation
│   │   ├── Fuzzing/                      # Fuzzer integration
│   │   ├── Contract/                     # Contract testing
│   │   ├── Differential/                 # Differential testing
│   │   ├── Reliability/                  # Flake detection
│   │   ├── Coverage/                     # Coverage tracking
│   │   ├── Observability/                # Metrics and telemetry
│   │   └── FunctionalTesting.swift       # PUBLIC API (re-exports all public types)
│   │
│   ├── InvariantSwiftMacros/             # Macro implementations (CompilerPlugin target)
│   │   ├── MacroPlugin.swift             # Plugin entry point (registers all macros)
│   │   ├── PropertyMacro/                # @PropertyTest, @AsyncPropertyTest implementations
│   │   ├── ArbitraryMacro/               # @Arbitrary for struct/class generation
│   │   ├── GenMacro/                     # @Gen DSL for custom generators
│   │   ├── StateMachineMacro/            # @StateMachine for state machines
│   │   ├── RuleBasedTestMacro/           # @RuleBasedTest for rule-based testing
│   │   ├── CompositeMacro/               # Composite generators
│   │   ├── LabelMacro/                   # @Label for test naming
│   │   ├── BusinessRuleMacro.swift       # Business rule testing
│   │   ├── ContractMacro.swift           # @Contract for contract testing
│   │   ├── DifferentialTestMacro.swift   # @DifferentialTest
│   │   ├── DeriveGenMacro.swift          # @DeriveGen
│   │   ├── LawCheckedMacro.swift         # @LawChecked for mathematical laws
│   │   ├── ReproduceMacro.swift          # @Reproduce for failing tests
│   │   ├── TargetMacro.swift             # @Target for targeted properties
│   │   ├── FuzzableMacro.swift           # @Fuzzable
│   │   └── Utilities/                    # Shared macro helpers
│   │       ├── ASTBuilders.swift         # SwiftSyntax AST construction
│   │       ├── TypeExtraction.swift      # Type info extraction
│   │       ├── DiagnosticEmitter.swift   # Error reporting
│   │       └── SyntaxFactory*.swift      # Syntax helpers (14+ files)
│   │
│   ├── InvariantSwiftDomainGenerators/   # Domain-specific generators
│   │   ├── DomainGenerators.swift        # Business domain generators
│   │   ├── Faker/                        # Fake data generation
│   │   │   ├── FakerGenerator.swift      # 100+ fake data types
│   │   │   └── FakerType.swift           # Enumeration of faker types
│   │   └── FakeryGenerators.swift        # Additional domain types
│   │
│   ├── GhostwriterCLI/                   # CLI for ghostwriter
│   │   └── main.swift                    # CLI entry point
│   │
│   └── PropertyTestHelper/               # Helper executable for test support
│       └── main.swift                    # Helper utilities
│
├── Tests/                                # All test targets
│   ├── FunctionalTesting/                # Core library tests (47 Swift files, 15K+ LOC)
│   │   ├── GeneratorTests.swift          # Tests for all generator types
│   │   ├── PropertyTests.swift           # Core property execution tests
│   │   ├── ShrinkingTests.swift          # Shrinking strategy tests
│   │   ├── PropertyEnhancementsTests.swift
│   │   ├── ClassificationTests.swift     # Classifying property tests
│   │   ├── DifferentialTesting/          # Differential test patterns
│   │   ├── ModelBasedTests.swift         # Model-based testing
│   │   ├── AsyncPropertyTests.swift      # Async property patterns
│   │   ├── SchedulerTests.swift          # Deterministic scheduling
│   │   ├── LinearizabilityTests.swift    # Concurrent linearizability
│   │   ├── MetamorphicTests.swift        # Metamorphic relations
│   │   ├── InvariantMiningTests.swift    # Automatic invariant discovery
│   │   └── ... (36+ more test files)
│   │
│   ├── InvariantSwiftMacroTests/         # Macro expansion tests
│   │   ├── PropertyMacroTests.swift      # @PropertyTest macro tests
│   │   ├── ArbitraryMacroTests.swift     # @Arbitrary macro tests
│   │   ├── StateMachineMacroTests.swift  # @StateMachine macro tests
│   │   ├── CompositeMacroTests.swift     # Composite generator tests
│   │   ├── RuleBasedTestMacroTests.swift # @RuleBasedTest tests
│   │   ├── GenMacroDSLTests.swift        # @Gen DSL tests
│   │   ├── ISPMacroTests.swift           # ISP macro integration
│   │   ├── MacroGoldenTests.swift        # Golden file tests
│   │   ├── Resources/                    # Golden test files
│   │   └── Utilities/                    # Macro test helpers
│   │       ├── TypeAnalyzerTests.swift
│   │       ├── GeneratorBuilderTests.swift
│   │       └── SyntaxFactoryTests.swift
│   │
│   ├── InvariantSwiftDomainGeneratorsTests/ # Domain generator tests
│   │   ├── FakerTests.swift              # Faker functionality
│   │   └── InvariantSwiftDomainGeneratorsTests.swift
│   │
│   ├── PerformanceTests/                 # Benchmark tests
│   │   └── PropertyPerformanceTests.swift # Generator/shrinking perf
│   │
│   ├── CoverageIntegrationTests/         # Coverage-guided testing tests
│   │   ├── AutomatedCoverageTests.swift
│   │   ├── CoverageValidationTests.swift
│   │   ├── FinalCoverageValidationTests.swift
│   │   ├── CrashIsolationTests.swift
│   │   └── LLVMCoverageRunner.swift
│   │
│   ├── Generated/                        # Auto-generated property tests
│   │   └── SeedPropertyTests.swift
│   │
│   └── SmokeTests/                       # Quick sanity check tests
│       ├── InvariantSwiftCoreSmokeTest.swift
│       ├── InvariantSwiftSmokeTest.swift
│       ├── InvariantSwiftMacrosSmokeTest.swift
│       └── InvariantSwiftExperimentalSmokeTest.swift
│
├── Benchmarks/                           # Performance benchmarks
│   ├── main.swift                        # Benchmark runner
│   ├── GeneratorBenchmarks.swift         # Generator performance
│   ├── ShrinkBenchmarks.swift            # Shrinking performance
│   ├── CollectionShrinkingBenchmarks.swift
│   └── ReplayBenchmarks.swift
│
├── Plugins/                              # SwiftPM plugins
│   ├── InvariantSwiftPlugin/             # Test runner plugin
│   │   └── main.swift                    # Plugin entry point
│   └── GhostwriterPlugin/                # Auto-test generation plugin
│       └── main.swift                    # Plugin entry point
│
├── Examples/                             # Example usage
│   ├── BasicProperties.swift
│   ├── ModelBasedTesting.swift
│   └── ... (additional examples)
│
├── docs/                                 # Documentation
│   ├── proposals/                        # ISP proposals
│   │   ├── ISP-0001.md (Architecture)
│   │   ├── ISP-0002.md (Shrinking)
│   │   ├── ISP-0003.md (Async/Await)
│   │   ├── ISP-0004.md (Database)
│   │   ├── ISP-0005.md (Differential Testing)
│   │   ├── ISP-0006.md (Contract Testing)
│   │   ├── ISP-0007.md (LibFuzzer)
│   │   ├── ISP-0008.md (Coverage-Guided)
│   │   ├── ISP-0009.md (Ghostwriter)
│   │   └── ISP-0010.md (Faker Generators)
│   ├── COOKBOOK.md                       # Usage patterns and recipes
│   ├── GENERATORS.md                     # Generator documentation
│   ├── MACROS.md                         # Macro documentation
│   ├── ONBOARDING.md                     # Contributor guide
│   └── SHRINKING_MIGRATION.md            # ShrinkTree migration
│
├── openspec/                             # OpenSpec change management
│   └── AGENTS.md                         # Specification format
│
├── .planning/                            # GSD planning documents
│   └── codebase/                         # Architecture mappings
│       ├── ARCHITECTURE.md               # This file
│       ├── STRUCTURE.md                  # Architecture decisions
│       ├── STACK.md                      # Technology stack
│       ├── INTEGRATIONS.md               # External dependencies
│       ├── CONVENTIONS.md                # Coding conventions
│       ├── TESTING.md                    # Testing patterns
│       └── CONCERNS.md                   # Technical debt
│
├── Package.swift                         # SwiftPM manifest (defines all targets)
├── .swiftlint.yml                        # SwiftLint configuration (Google style)
├── .swift-format                         # Swift formatting rules (2-space indent)
├── .pre-commit-config.yaml               # Git hooks (lint, format, tests)
├── Makefile                              # Build automation
├── CHANGELOG.md                          # Version history
├── CLAUDE.md                             # Root project guidance
└── README.md                             # Project overview
```

## Directory Purposes

**`Sources/InvariantSwift/Core/`:**
- Purpose: Fundamental types and protocols
- Contains: Generator, Shrink, Size, Seed, Property, PropertyRunner, ShrinkTree, ModelTesting protocols, RegressionBank, RunReport
- Key files: `Generator.swift` (600 LOC), `Property.swift` (200 LOC), `ShrinkTree.swift` (200 LOC)
- No external dependencies; foundation for all other modules

**`Sources/InvariantSwift/Generators/`:**
- Purpose: Built-in generator implementations
- Contains: PrimitiveGenerators (Int, Bool, String, Float, Double), CollectionGenerators (Array, Set, Dictionary), CombinatorGenerators (sequence, traverse, flatMap), OptionalResultGenerators
- Key files: `PrimitiveGenerators.swift`, `CollectionGenerators.swift`, `CombinatorGenerators.swift`
- Depends on: Core only

**`Sources/InvariantSwift/Advanced/`:**
- Purpose: Experimental advanced testing capabilities
- Contains: CoverageGuided, Linearizability, Metamorphic, InvariantMining, LensSystem, PropertyEffect, AsyncProperties, DICE, SMTSolver, Scheduler, ShrinkPredicates, GeneratorRegistry
- Depends on: Core, Generators, Testing, Database
- Optional: Features can be omitted without breaking core functionality

**`Sources/InvariantSwift/SwiftTesting/`:**
- Purpose: Swift Testing framework integration
- Contains: PropertyTestIntegration, FailureReporting, ExpectDifference, FailurePersistence, TestStatistics
- Key files: `PropertyTestIntegration.swift` (integration entry point)
- Enables: `@Test` compatibility with property tests

**`Sources/InvariantSwift/Testing/`:**
- Purpose: Property test execution engine
- Contains: TargetedRunner, TargetedTesting, TargetCollector, TargetedConfig
- Key files: `TargetedRunner.swift` (test execution), `TargetCollector.swift` (target management)
- Enables: Iteration, shrinking, result collection

**`Sources/InvariantSwiftMacros/`:**
- Purpose: Compile-time code generation via Swift macros
- Contains: 30+ macro implementations with SwiftSyntax AST builders
- Key files: `MacroPlugin.swift` (plugin registration), `PropertyMacro/PropertyMacro.swift` (main macro), `Utilities/ASTBuilders.swift` (shared helpers)
- Constraint: Cannot import InvariantSwift library (macro plugin limitation)

**`Sources/InvariantSwiftDomainGenerators/`:**
- Purpose: Domain-specific generator library
- Contains: Faker (100+ fake data types), business domain generators
- Key files: `Faker/FakerGenerator.swift` (500 LOC), `Faker/FakerType.swift` (enumeration)
- Usage: `Gen.faker(.email)`, `Gen.faker(.creditCard)`

**`Sources/GhostwriterCLI/`:**
- Purpose: CLI entry point for auto-test generation
- Depends on: All InvariantSwift targets
- Usage: `swift package ghostwrite` via plugin

**`Tests/FunctionalTesting/`:**
- Purpose: Core library test suite
- Contains: 47 test files covering generators, properties, shrinking, async patterns, model-based testing, advanced features
- Total: 15,000+ lines of test code
- Coverage: 99%+ of library code

**`Tests/InvariantSwiftMacroTests/`:**
- Purpose: Macro expansion test suite
- Pattern: Uses `assertMacroExpansion` from SwiftSyntaxMacrosTestSupport
- Resources: Golden test files in `Resources/`
- Verification: Whitespace-sensitive expansion matching

**`Tests/PerformanceTests/` & `Benchmarks/`:**
- Purpose: Performance and scalability testing
- Contains: Generator throughput, shrinking speed, collection handling benchmarks
- Tool: Swift-benchmark framework

**`Plugins/`:**
- Purpose: SwiftPM plugin entry points
- `InvariantSwiftPlugin/`: `swift package invariant` command
- `GhostwriterPlugin/`: `swift package ghostwrite` command

**`docs/proposals/`:**
- Purpose: Specification proposals (ISP = Invariant Swift Proposal)
- Format: Markdown with design, rationale, implementation details
- 10 proposals covering all major features

## Key File Locations

**Entry Points:**
- `Sources/InvariantSwift/FunctionalTesting.swift` - PUBLIC API (user imports this)
- `Sources/InvariantSwiftMacros/MacroPlugin.swift` - Macro plugin registration
- `Sources/GhostwriterCLI/main.swift` - CLI for auto-test generation
- `Plugins/InvariantSwiftPlugin/main.swift` - Test runner plugin

**Configuration:**
- `Package.swift` - Target definitions, dependencies (SwiftSyntax 602.0.0, swift-custom-dump 1.3.3+)
- `.swiftlint.yml` - Linting rules (Google style, strict)
- `.swift-format` - Formatting (2-space indentation)
- `.pre-commit-config.yaml` - Git hooks (lint, format, test)
- `Makefile` - Build commands (validate, test, lint, format)

**Core Logic:**
- `Sources/InvariantSwift/Core/Generator.swift` - Gen<T>, Shrink<T>, Size, Seed (~600 LOC)
- `Sources/InvariantSwift/Core/Property.swift` - Property definition (~200 LOC)
- `Sources/InvariantSwift/Core/ShrinkTree.swift` - BFS shrinking tree (~200 LOC)
- `Sources/InvariantSwift/Core/ModelTesting.swift` - Command, StateMachine protocols
- `Sources/InvariantSwift/Core/RegressionBank.swift` - Failure storage

**Generators:**
- `Sources/InvariantSwift/Generators/PrimitiveGenerators.swift` - Int, Bool, String, Float, Double
- `Sources/InvariantSwift/Generators/CollectionGenerators.swift` - Array, Set, Dictionary
- `Sources/InvariantSwift/Generators/CombinatorGenerators.swift` - Sequence, flatMap, traverse
- `Sources/InvariantSwiftDomainGenerators/Faker/FakerGenerator.swift` - Fake data (emails, names, credit cards, etc)

**Macro Implementations:**
- `Sources/InvariantSwiftMacros/PropertyMacro/PropertyMacro.swift` - @PropertyTest
- `Sources/InvariantSwiftMacros/ArbitraryMacro/ArbitraryMacro.swift` - @Arbitrary
- `Sources/InvariantSwiftMacros/Utilities/ASTBuilders.swift` - Shared AST construction

**Testing:**
- `Sources/InvariantSwift/Testing/TargetedRunner.swift` - Test execution engine
- `Sources/InvariantSwift/SwiftTesting/PropertyTestIntegration.swift` - Swift Testing bridge
- `Tests/FunctionalTesting/PropertyTests.swift` - Core property tests

**Persistence:**
- `Sources/InvariantSwift/Database/CorpusDatabase.swift` - SQLite corpus storage
- `Sources/InvariantSwift/Persistence/` - Shrink tree serialization

**Presentation:**
- `Sources/InvariantSwift/Presentation/PrettyPrint.swift` - Pretty-printer for output

**Ghostwriter (Auto-test generation):**
- `Sources/InvariantSwift/Ghostwriter/Ghostwriter.swift` - Main orchestrator (actor-based)
- `Sources/InvariantSwift/Ghostwriter/SourceAnalyzer.swift` - Source file parsing
- `Sources/InvariantSwift/Ghostwriter/TestGenerator.swift` - Test code generation

## Naming Conventions

**Files:**
- `[Type]+[Feature].swift` - e.g., `Generator.swift`, `Property.swift`, `ShrinkTree.swift`
- Plural for collections: `Generators/`, `Tests/`, `Macros/`
- Specific domain + suffix: `FakerGenerator.swift`, `CorpusDatabase.swift`, `PrettyPrint.swift`
- Macro files: `[MacroName]Macro.swift` - e.g., `PropertyMacro.swift`, `ArbitraryMacro.swift`

**Directories:**
- PascalCase for main folders: `Sources/`, `Tests/`, `Benchmarks/`, `Plugins/`
- Domain names: `Core/`, `Generators/`, `Advanced/`, `Ghostwriter/`, `Fuzzing/`, `Database/`
- Test convention: `[Feature]Tests/` - e.g., `FunctionalTesting/`, `InvariantSwiftMacroTests/`

**Types (Swift identifiers):**
- PascalCase for struct/class/enum: `Gen<T>`, `Property<T>`, `ShrinkTree<T>`, `Size`, `Seed`
- Protocol names: `Command`, `StateMachine`, `Generatable`, `Arbitrary`
- Macro names with @ prefix: `@PropertyTest`, `@Arbitrary`, `@Gen`, `@StateMachine`
- Function names: camelCase - `generate()`, `shrink()`, `apply(state:)`, `execute()`

## Where to Add New Code

**New Property Testing Feature:**
- Primary: `Sources/InvariantSwift/[DomainName]/[Feature].swift`
- Tests: `Tests/FunctionalTesting/[Feature]Tests.swift`
- Example: Feature for concurrent testing → `Sources/InvariantSwift/Advanced/Concurrency.swift` + `Tests/FunctionalTesting/ConcurrencyTests.swift`

**New Generator Type:**
- Implementation: `Sources/InvariantSwift/Generators/[Domain]Generators.swift`
- Tests: Add test cases to `Tests/FunctionalTesting/GeneratorTests.swift`
- Example: UUID generator → Add to `Generators/PrimitiveGenerators.swift`

**New Macro:**
- Implementation: `Sources/InvariantSwiftMacros/[MacroName]/[MacroName]Macro.swift`
- Tests: `Tests/InvariantSwiftMacroTests/[MacroName]Tests.swift`
- Registration: Add to `MacroPlugin.swift` in `providingMacros` array
- Example: @NewFeature macro → Create folder `Sources/InvariantSwiftMacros/NewFeatureMacro/`

**New Domain Generator:**
- Implementation: `Sources/InvariantSwiftDomainGenerators/[Domain]Generators.swift`
- Tests: `Tests/InvariantSwiftDomainGeneratorsTests/[Domain]Tests.swift`
- Example: Cryptocurrency addresses → `DomainGenerators.swift` + test

**Utility Functions (Helpers):**
- Macro utilities: `Sources/InvariantSwiftMacros/Utilities/[Purpose].swift`
- Shared patterns: `Sources/InvariantSwift/Core/Extensions/` (new directory pattern)
- Example: Type extraction helper → `Utilities/TypeExtraction.swift` (already exists)

**Tests for Existing Code:**
- Co-located pattern: Same directory as code under test
- Example: Testing `Sources/InvariantSwift/Core/Generator.swift` → `Tests/FunctionalTesting/GeneratorCoreTests.swift`

## Special Directories

**`.planning/codebase/`:**
- Purpose: Generated codebase analysis documents
- Generated: By `/gsd:map-codebase` command
- Committed: Yes (tracked in git)
- Contents: ARCHITECTURE.md, STRUCTURE.md, STACK.md, INTEGRATIONS.md, CONVENTIONS.md, TESTING.md, CONCERNS.md

**`.build/`:**
- Purpose: Swift build artifacts
- Generated: By `swift build`
- Committed: No (in .gitignore)
- Contains: Compiled binaries, intermediate objects

**`Benchmarks/`:**
- Purpose: Performance benchmarks (executable target)
- Run: `swift run -c release Benchmarks`
- Committed: Yes (source code)

**`Examples/`:**
- Purpose: Usage examples and recipes
- Committed: Yes (reference code)
- Pattern: Self-contained example files with doc comments

**`docs/proposals/`:**
- Purpose: Specification proposals for features
- Format: Markdown ISP-NNNN.md format
- Committed: Yes (design documentation)

**`.vscode/`:**
- Purpose: VS Code configuration
- Committed: Yes (shared settings)
- Example: Swift extensions, formatting rules

---

*Structure analysis: 2026-01-23*
