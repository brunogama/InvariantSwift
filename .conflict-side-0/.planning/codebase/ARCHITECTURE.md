# Architecture

**Analysis Date:** 2026-01-23

## Pattern Overview

**Overall:** Property-Based Testing Framework with Layered Multi-Domain Architecture

**Key Characteristics:**
- **Protocol-Witness Pattern**: Core generator/shrinking uses witness protocols over concrete implementations
- **Actor-Based Concurrency**: All I/O and state management uses actor isolation for thread safety
- **Coalgebraic Shrinking**: Shrink strategies implement coalgebras (dual of algebras) for lazy evaluation
- **Functor/Applicative/Monad Stack**: Generators implement full category theory typeclass hierarchy
- **Macro-Driven Code Generation**: Swift macros handle test framework integration and boilerplate elimination
- **Modular Testing Infrastructure**: Separate concerns for generation, execution, reporting, and persistence

## Layers

**Foundation Layer (Core):**
- Purpose: Fundamental types and protocols for property-based testing
- Location: `Sources/InvariantSwift/Core/`
- Contains: `Gen<T>`, `Shrink<T>`, `Size`, `Seed`, `Property`, `ShrinkTree<T>`, `RegressionBank`, `RunReport`, `ModelTesting` protocols
- Depends on: Foundation only (zero external dependencies in Core)
- Used by: All other layers
- Key file: `Generator.swift` (~600 LOC, defines generator protocol and shrinking strategies)

**Generation Layer:**
- Purpose: Specialized generators for primitives, collections, and domain types
- Location: `Sources/InvariantSwift/Generators/`
- Contains: `PrimitiveGenerators` (Int, Bool, String), `CollectionGenerators` (Array, Set), `CombinatorGenerators` (sequence, traverse, flatMap), `OptionalResultGenerators`, `FloatingPointMode` (configurable float generation)
- Depends on: Core layer
- Used by: Testing layer, Experimental layer
- Pattern: Each generator file focuses on a single domain (numeric, string, collection)

**Testing Layer:**
- Purpose: Property test execution engine and configuration
- Location: `Sources/InvariantSwift/Testing/`
- Contains: `TargetedRunner`, `TargetedTesting`, `TargetCollector`, test configuration
- Depends on: Core, Generation layers
- Used by: SwiftTesting integration, Macros
- Pattern: Stateful runners that manage test iteration, shrinking, and result collection

**Swift Testing Integration Layer:**
- Purpose: Bridge InvariantSwift to Swift Testing framework
- Location: `Sources/InvariantSwift/SwiftTesting/`
- Contains: `PropertyTestIntegration`, `FailureReporting`, `ExpectDifference`, `FailurePersistence`, `TestStatistics`
- Depends on: Core, Testing layers
- Used by: Test code compiled with Swift Testing
- Pattern: Adapters that convert Property results to Swift Testing Issue format

**Macro Layer:**
- Purpose: Compile-time code generation for test boilerplate
- Location: `Sources/InvariantSwiftMacros/`
- Contains: 30+ macros including `@PropertyTest`, `@Arbitrary`, `@Gen`, `@StateMachine`, `@Contract`, etc.
- Depends on: SwiftSyntax (600.0.0), no runtime InvariantSwift imports
- Used by: User code via macro attributes
- Pattern: MemberMacro, PeerMacro, AttributeMacro for code expansion

**Presentation Layer:**
- Purpose: Human-readable output for test results and counterexamples
- Location: `Sources/InvariantSwift/Presentation/`
- Contains: `PrettyPrint` (Wadler-style pretty-printing), diff generation, cycle detection
- Depends on: Core layer
- Used by: Swift Testing integration, CLI tools
- Pattern: Formatter adopting custom dump for structured output

**Persistence Layer:**
- Purpose: Store and retrieve test artifacts (shrink trees, regressions, corpus)
- Location: `Sources/InvariantSwift/Persistence/`, `Sources/InvariantSwift/Database/`
- Contains: `CorpusDatabase` (SQLite-backed), shrink tree serialization, corpus management
- Depends on: Core, SQLite3 (system)
- Used by: Coverage-guided generation, regression testing
- Pattern: Actor-based database with async/await API

**Advanced Testing Layer (Experimental):**
- Purpose: Sophisticated testing patterns and optimizations
- Location: `Sources/InvariantSwift/Advanced/`
- Contains:
  - `CoverageGuided.swift`: Coverage-directed input generation (Libfuzzer-style)
  - `Linearizability.swift`: Concurrent linearizability testing
  - `Metamorphic.swift`: Metamorphic testing (multiple input variations)
  - `InvariantMining.swift`: Automatic invariant discovery
  - `LensSystem.swift`: Functional optics (Lens, Prism, Traversal)
  - `PropertyEffect.swift`: Effectful properties with actor isolation
  - `AsyncProperties.swift`: Async/await property patterns
  - `DICE.swift`: Distributed test coverage analysis
  - `SMTSolver.swift`: SMT solver integration
  - `Scheduler.swift`: Deterministic scheduling for concurrency
  - `ShrinkPredicates.swift`: Custom predicate-based shrinking
  - `GeneratorRegistry.swift`: Dynamic generator registration
- Depends on: Core, Generation, Testing layers
- Used by: Advanced testing scenarios, research prototypes
- Pattern: Optional capabilities built on foundation layers

**Fuzzing Layer:**
- Purpose: Fuzzer integration and corpus-based testing
- Location: `Sources/InvariantSwift/Fuzzing/`
- Contains: `LibFuzzerIntegration` (libfuzzer harness generation)
- Depends on: Core, Generation, Database layers
- Used by: Fuzzing infrastructure
- Pattern: Adapter between property tests and fuzzer frameworks

**Contract Testing Layer:**
- Purpose: Service/API contract testing
- Location: `Sources/InvariantSwift/Contract/`
- Contains: Contract definition, validation, pact-like semantics
- Depends on: Core, Testing layers
- Used by: Distributed system testing
- Pattern: Bilateral contract with consumer/provider expectations

**Differential Testing Layer:**
- Purpose: Test multiple implementations against specification
- Location: `Sources/InvariantSwift/Differential/`
- Contains: Differential property patterns, oracle functions
- Depends on: Core, Testing layers
- Used by: Cross-version or cross-implementation testing
- Pattern: Specify oracle (reference implementation) and verify implementation

**Reliability Layer:**
- Purpose: Test reliability analysis (flake detection)
- Location: `Sources/InvariantSwift/Reliability/`
- Contains: `FlakeHunter` (identifies unreliable tests)
- Depends on: Core, Testing layers
- Used by: Test quality assurance
- Pattern: Multiple runs with statistical analysis

**Coverage Layer:**
- Purpose: Code coverage tracking and analysis
- Location: `Sources/InvariantSwift/Coverage/`
- Contains: LLVM coverage integration, coverage-guided strategies
- Depends on: Core, Database layers
- Used by: Coverage-guided generation
- Pattern: Actor-based coverage collector with symbol tracking

**Observability Layer:**
- Purpose: Metrics, telemetry, and diagnostics
- Location: `Sources/InvariantSwift/Observability/`
- Contains: `TelemetrySystem` (event tracking, metrics)
- Depends on: Core layer
- Used by: All layers for diagnostics
- Pattern: Observer pattern with async event collection

**Domain Generators Layer:**
- Purpose: Specialized generators for realistic domain data
- Location: `Sources/InvariantSwiftDomainGenerators/`
- Contains: `FakerGenerator` (100+ fake data types), `DomainGenerators` (business domain specifics)
- Depends on: Core, Generation layers
- Used by: Domain-specific tests
- Pattern: Enumeration-based generator selection

**CLI & Plugins:**
- Purpose: Command-line tools and SwiftPM plugins
- Location: `Sources/GhostwriterCLI/`, `Plugins/`
- Contains: `Ghostwriter` (auto-test generation), `InvariantSwiftPlugin` (test runner), `GhostwriterPlugin`
- Depends on: All library layers
- Used by: Package developers
- Pattern: Plugin interface with capability declarations

**Ghostwriter (Auto-test Generation):**
- Purpose: Automatic property test generation from source code
- Location: `Sources/InvariantSwift/Ghostwriter/`
- Contains: `Ghostwriter` (main orchestrator), `SourceAnalyzer`, `TestGenerator`, `SourceKittenClient`, `TypeInfo`
- Depends on: Core, Generation, Macros layers
- Used by: `GhostwriterPlugin` and CLI
- Pattern: Actor-based pipeline: FileDiscovery → SourceAnalysis → TypeExtraction → TestGeneration → CodeEmission

## Data Flow

**Standard Property Test Execution:**

1. **Generator Phase**: User calls `Property(generator: Gen<T>) { predicate }`
2. **Iteration Loop**: PropertyRunner generates N values using generator
3. **Predicate Evaluation**: Each generated value runs through the property predicate
4. **Failure Detection**: If predicate returns false or throws, enter shrinking phase
5. **Shrinking Phase**: Convert `Shrink<T>` to `ShrinkTree<T>` via `ShrinkTree.from()`
6. **BFS Search**: Use breadth-first search to find minimal counterexample within `maxShrinks` budget
7. **Result Reporting**: Create `PropertyResult` with minimal counterexample, original seed, shrink steps
8. **Swift Testing Integration**: Convert to `Issue` for Swift Testing framework

**Macro Expansion Pipeline (at compile-time):**

1. **Macro Invocation**: User writes `@PropertyTest func myTest(x: Int) -> Bool { ... }`
2. **Macro Plugin**: SwiftCompilerPlugin invokes `PropertyTestMacro.expansion()`
3. **AST Analysis**: Extract function signature, parameter types, return type
4. **Generator Inference**: Use `TypeExtraction.inferGenerator()` to match types to generators
5. **Code Generation**: Build new function declaration (test wrapper) using SwiftSyntax builders
6. **Peer Declaration**: Emit peer declaration with `@Test` for Swift Testing
7. **Code Emission**: Return expanded source with generated test code

**Coverage-Guided Generation Flow:**

1. **Execution Tracking**: PropertyRunner collects coverage symbols during test execution
2. **Coverage Collection**: CoverageCollector actor maintains set of seen/unseen symbols
3. **Feedback Loop**: Generators receive coverage budget and bias generation toward unseen paths
4. **Corpus Management**: Interesting inputs stored in CorpusDatabase for future runs
5. **Cross-Run Learning**: Subsequent runs use corpus to jump-start exploration

**Ghostwriter Analysis Pipeline:**

1. **File Discovery**: Find Swift source files matching patterns in config
2. **Source Parsing**: Parse each file to AST using SwiftParser
3. **Type Analysis**: Extract struct/class/enum definitions, methods, computed properties
4. **Pattern Detection**: Identify testable patterns (init, properties, methods)
5. **Generator Suggestion**: Infer @Arbitrary conformance for custom types
6. **Test Template Expansion**: Fill test templates with discovered type info
7. **Code Emission**: Generate test file with full property test suite

**State Management Flow (Model-Based Testing):**

1. **Initial State**: Define zero/nil state value
2. **Command Generation**: Gen<Command> creates random command sequence
3. **Model Update**: Apply each command to abstract state using `apply(state:)`
4. **Real Execution**: Execute same command on actual system using `execute()`
5. **Verification**: Check postcondition `postcondition(state: State, result: Result) -> Bool`
6. **Failure Shrinking**: Shrink command sequence to minimal reproducer

**Error Handling Flow:**

1. **Predicate Error**: If property predicate throws, convert to `.threwError(String)`
2. **Timeout**: If execution exceeds `config.timeout`, mark as `.timedOut(seconds)`
3. **Discard**: If assumption fails via `assume()`, increment discard counter
4. **GaveUp**: If discards > `maxDiscarded`, return `.gaveUp`
5. **Reporting**: FailureReporting converts to Swift Testing Issue with detailed context

## Key Abstractions

**Generator (Gen<T>):**
- Purpose: Combines generation function and shrinking strategy
- Example: `Gen<Int>.int` = `{ rng, size in Int.random(...) }` + `Shrink { n in [n-1, n/2, 0] }`
- Pattern: Witness pattern with `(inout RandomNumberGenerator, Size) -> T` closure + `Shrink<T>`
- Composability: Functor (map), Applicative (pure, zip), Monad (flatMap) laws

**Shrink<T>:**
- Purpose: Coalgebraic shrinking strategy
- Example: `Shrink<Int> { n in var result: [Int] = []; if n > 0 { result.append(0) }; ... }`
- Pattern: Function `(T) -> [T]` that lazily computes simpler candidates
- Mathematical: Unfolds values into shrink trees; dual of algebra

**ShrinkTree<T>:**
- Purpose: Lazy tree for BFS-based minimal counterexample search
- Example: Root at 100, children [50, 75, 99], grandchildren from each child, etc.
- Pattern: Final class with lazy `children` closure `@Sendable () -> [ShrinkTree<T>]`
- Advantage: Reproducible, deterministic search order; prevents greedy local minima

**Property<T>:**
- Purpose: Complete property test specification
- Contains: Generator, predicate function, configuration (iterations, maxShrinks, seed, timeout)
- Pattern: Struct combining all test parameters; can be serialized for regression storage

**PropertyRunner:**
- Purpose: Executes property test from specification to result
- Responsibilities: Iterate generator, apply predicate, shrink failures, collect statistics
- Pattern: Async actor with deterministic RNG seeding for reproducibility

**PropertyConfig:**
- Purpose: Tune property test execution
- Contains: iterations (default 100), maxShrinks (default 1000), maxDiscarded, seed, timeout, verbosity
- Pattern: Struct with sensible defaults; passed through all layers

**PropertyResult<T>:**
- Purpose: Complete test execution outcome
- Contains: `success` or `failure(reason, seed, shrunkenValue, shrinksCount, originalValue)`
- Pattern: Generic over input type for type-safe result handling

**Macro Pattern:**
- Purpose: Compile-time code generation without runtime cost
- Example: `@PropertyTest func testXYZ(a: Int) -> Bool { ... }` generates test function + boilerplate
- Pattern: AttachedMacro (peer/member) with SwiftSyntax AST builders
- Advantage: Zero-cost abstraction, compile-time verification, IDE-aware

**Actor Pattern (Persistence/Fuzzing):**
- Purpose: Thread-safe concurrent state management
- Example: `actor CorpusDatabase { @MainActor ... }`
- Pattern: Actor with async/await for all mutations
- Used by: Database operations, coverage collection, ghostwriter analysis

**Optics (Lens/Prism/Traversal):**
- Purpose: Composable focus and update for immutable data
- Example: `Lens<Config, Int> { get: { $0.iterations }, set: { ... } }`
- Pattern: Functional programming with immutable updates
- Used by: Complex property transformations, coverage-guided generation

## Entry Points

**User Code (Test Writing):**
- Location: User's test files (e.g., `Tests/MyTests.swift`)
- Triggers: XCTest runner or Swift Testing runner
- Responsibilities:
  - Write `@PropertyTest func myTest(x: T) -> Bool { ... }` or
  - Create `Property` manually with generators
  - Invoke `await checkProperty(property)`

**Macro Entry (Compile-Time):**
- Location: `Sources/InvariantSwiftMacros/MacroPlugin.swift`
- Triggers: Swift compiler during compilation
- Responsibilities: Register 30+ macros with compiler

**Ghostwriter Entry (CLI):**
- Location: `Sources/GhostwriterCLI/main.swift` via plugin
- Triggers: `swift package ghostwrite` command
- Responsibilities: Run analysis, generate tests, emit code

**Library Entry (Programmatic):**
- Location: `Sources/InvariantSwift/FunctionalTesting.swift`
- Exports: All public types (Gen, Property, PropertyRunner, etc.)
- Usage: `import InvariantSwift` to use library programmatically

## Error Handling

**Strategy:**
- Non-fatal errors return within type system (Result, Optional)
- Macros return empty with Diagnostic instead of throwing
- Property predicates can throw or return `PropertyEvaluation`
- Runners track errors in `PropertyResult`

**Patterns:**
- **Predicate Errors**: Wrapped in `FailureReason.threwError(String)`
- **Assumption Failures**: Return `.discard(reason)` via `assume()` function
- **Timeout Failures**: Caught by runner, converted to `FailureReason.timedOut(seconds)`
- **Macro Errors**: Emitted as SwiftUI diagnostics, source continues to compile with empty expansion
- **Persistence Errors**: Logged to telemetry, never crash user code

**Error Propagation:**
```
Property Execution
  ├─ Predicate throws → FailureReason.threwError
  ├─ Predicate returns false → FailureReason.predicateFailed
  ├─ Timeout exceeded → FailureReason.timedOut
  └─ Assumption violated → PropertyEvaluation.discard
    └─ Too many discards → PropertyResult.gaveUp
```

## Cross-Cutting Concerns

**Logging:**
- Implementation: No built-in logging; uses `@unchecked Sendable` for RNG capture
- Location: Observability layer via `TelemetrySystem`
- Pattern: Event-based metrics collection through hooks

**Validation:**
- Location: Generator layer validates parameter bounds (int ranges, collection sizes)
- Pattern: Guard let or precondition in generator initialization
- Never crashes: Clamps values instead of failing

**Authentication:**
- Not applicable: Property-based testing framework has no auth layer

**Concurrency:**
- Location: All I/O layers (Database, Coverage, Ghostwriter, Plugins)
- Pattern: Actor-based isolation with async/await
- Sendability: `@unchecked Sendable` for RNG (closed over mutable state)

**Security:**
- No external network access except Ghostwriter's optional SourceKittenClient
- SourceKit API calls are optional, framework functions without it
- All test data is local/in-memory by default
- CorpusDatabase is local SQLite file

---

*Architecture analysis: 2026-01-23*
