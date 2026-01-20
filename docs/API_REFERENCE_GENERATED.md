# InvariantSwift API Reference

_Auto-generated API documentation_

## Table of Contents

- [GhostwriterCLI](#ghostwritercli)
- [InvariantSwift](#invariantswift)
- [InvariantSwiftMacros](#invariantswiftmacros)

---

## GhostwriterCLI

_1 enums, 6 funcs, 2 inits, 30 lets, 6 structs_

### 📦 Structs

| Name | Description |
|------|-------------|
| `AnalysisResult` | Result of analyzing a source file. |
| `ExtractedMethod` | Represents a method extracted from source code. |
| `ExtractedParameter` | Represents a method parameter. |
| `ExtractedProperty` | Represents a property extracted from source code. |
| `ExtractedTypeInfo` | Represents a Swift type extracted from source code. |
| `TestCodeGenerator` | Generates property test code from extracted types. |

### 🔢 Enums

| Name | Description |
|------|-------------|
| `GhostwriterTestPattern` | Test patterns that can be generated. |

### ⚡ Funcs

| Name | Description |
|------|-------------|
| `analyze` | Analyze a Swift source file. |
| `analyze` | Analyze Swift source code. |
| `detectPatterns` | Detect applicable test patterns for a type based on conformances. |
| `generateArbitraryExtension` | Generate Arbitrary extension for a type. |
| `generateTest` | Generate a single test for a type and pattern. |
| `generateTestFile` | Generate a complete test file for multiple types. |

---

## InvariantSwift

_28 actors, 103 enums, 444 funcs, 252 inits, 833 lets, 9 protocols, 235 structs, 14 typealiass, 230 vars_

### 📋 Protocols

| Name | Description |
|------|-------------|
| `Command` | **Protocol for stateful commands in model-based testing** |
| `ContractProtocol` | Marker protocol for types that have behavioral contracts. |
| `Diffable` | **Protocol for types that can be diffed** |
| `FuzzTargetProtocol` | Protocol for type-erasing fuzz targets |
| `Generatable` | Protocol for types that can generate instances. |
| `InvariantMiner` | _No documentation_ |
| `PrettyPrintable` | **Protocol for types that can be pretty-printed** |
| `RuleBasedStateMachine` | Protocol for rule-based state machine tests. |
| `StateMachine` | **Abstract model of a stateful system for testing** |

### 📦 Structs

| Name | Description |
|------|-------------|
| `ActorID` | Unique identifier for actors in the scheduler |
| `AddressGenerators` | Generators for realistic addresses and geographic data. |
| `AggregateStatistics` | Aggregated statistics across multiple property test runs. |
| `AnyBundle` | A type-erased bundle for accumulating values. |
| `AnyGenerator` | A type-erased generator wrapper for storage in the registry. |
| `AnyOperation` | Type-erased operation for collections |
| `AnyRelationViolation` | Type-erased relation violation for collection storage |
| `AnyRule` | A type-erased rule that can be executed on a state machine. |
| `AsyncDifferentialTester` | Async variant of DifferentialTester. |
| `AsyncIterator` | Async iterator for lazy invariant mining |
| `AsyncPredicate` | Async predicate that can suspend and perform async operations |
| `AsyncProperty` | Property that can be tested asynchronously with concurrency support |
| `AsyncPropertyConfig` | Configuration for async property execution |
| `AsyncPropertyFailure` | Detailed failure information for async properties |
| `AsyncPropertyResult` | Result of async property execution |
| `BankStatistics` | Statistics about the regression bank. |
| `BoundedPriorityQueue` | **Bounded priority queue for top-K selection** |
| `Box` | **Box wrapper for recursive JSON Schema structures** |
| `BranchID` | print(branch)  // Prints: "findValue:0" |
| `BundleRef` | Reference to a value in a bundle. |
| `BusinessRuleGaveUp` | print("Testing incomplete: \(error.suggestion)") |
| `BusinessRuleViolation` | **Business-friendly error reporting for property test failures** |
| `CausalEdge` | Edge in the happens-before graph |
| `CheckerConfig` | Configuration for linearizability checker |
| `Classification` | **Coverage classification for inputs** |
| `ClassificationCoverage` | **Coverage statistics for a single classification** |
| `ClusteringMiner` | _No documentation_ |
| `CommerceGenerators` | Generators for realistic commerce data. |
| `CompanyGenerators` | Generators for realistic company data. |
| `ComplianceViolation` | **Contract compliance violation** |
| `ConcurrencyStats` | Concurrency statistics |
| `ConfidenceInterval` | **Confidence interval for statistical analysis** |
| `Config` | **Telemetry configuration** |
| `Config` | **Flake detection configuration** |
| `ConfigBuilder` | **Configuration Builder Pattern** |
| `ContractOperation` | Represents an operation that can be performed on a contracted type. |
| `ContractTestResult` | Result of testing a contract on a conforming type. |
| `ContractTestRunner` | Runs contract tests on a conforming type. |
| `ContractViolation` | Error thrown when a contract is violated. |
| `CorpusEntry` | Entry in the corpus database |
| `CorpusKey` | Unique key for identifying test cases in the corpus |
| `CorpusQuery` | Query parameters for corpus retrieval |
| `CorpusStatistics` | Statistics about the corpus database |
| `CounterStateMachine` | A simple counter state machine for testing |
| `CoverageAnalysis` | **Coverage analysis result** |
| `CoverageBudget` | print(budget.criticalGaps)  // ["edgeCase", "errorHandler"] (sorted) |
| `CoverageConfig` | Configuration for coverage-guided testing |
| `CoverageContract` | **Coverage requirement contract** |
| `CoverageObservation` | **Coverage observation for a single test input** |
| `CoverageRecommendation` | **Coverage improvement recommendation** |
| `CoverageReport` | print(report.summary()) |
| `CoverageSummary` | **High-level coverage summary** |
| `DICEExecutionContext` | DICE execution context information |
| `DatabaseRecord` | **Database-like record structure** |
| `DeterminismCheckResult` | Result of a determinism check. |
| `DiffFormat` | Format options for diff output. |
| `DifferentialResult` | Result of comparing two implementations on the same input. |
| `DifferentialTestError` | Error thrown when differential test finds a divergence. |
| `DifferentialTester` | Utility for running differential tests between two implementations. |
| `DirectedGraph` | **Directed graph structure for testing graph algorithms** |
| `DiscoveredInvariant` | An invariant discovered through execution analysis |
| `DistributionCheckResult` | Result of a distribution check. |
| `Edge` | **Edge in a directed graph** |
| `EffectConfig` | Configuration for PropertyEffect execution behavior |
| `ExecutedStep` | Record of a single executed step for reporting and shrinking. |
| `ExecutionContext` | Execution context information |
| `ExecutionEnvironment` | **System environment snapshot** |
| `ExecutionMetrics` | Execution performance and behavior metrics |
| `ExecutionRecord` | Records execution information for coverage analysis |
| `ExecutionState` | State of execution at a point in time |
| `ExecutionStatistics` | Statistics collected during execution |
| `ExecutionTrace` | A recorded execution trace |
| `FailingExample` | A recorded failing example from a property test. |
| `FailingExampleStatistics` | Statistics about the example database |
| `FailureDatabase` | Container for multiple persisted failures. |
| `FailureEntry` | A stored failure case for regression testing. |
| `FailureReport` | Detailed failure report for a property test. |
| `FailureReporter` | Generates and records failure reports for property tests. |
| `FakeAddressGenerators` | _No documentation_ |
| `FakeCommerceGenerators` | _No documentation_ |
| `FakeCompanyGenerators` | _No documentation_ |
| `FakeConfig` | Configuration for fake data edge case generation. |
| `FakeGeneratorNamespace` | _No documentation_ |
| `FakeGenerators` | Root struct for all fake data generators. |
| `FakeInternetGenerators` | _No documentation_ |
| `FakeLoremGenerators` | _No documentation_ |
| `FakeNameGenerators` | _No documentation_ |
| `FileDiscovery` | Discovers Swift source files in directories. |
| `FlakePatterns` | **Pattern analysis in flaky test behavior** |
| `FlakeReport` | **Comprehensive flake report** |
| `FlakeStatistics` | **Flake detection statistics** |
| `FlakyCommand` | Command that can fail probabilistically |
| `FuzzDataProvider` | **Consumes bytes from fuzzing engine to produce typed values** |
| `FuzzStatistics` | Statistics from fuzz execution |
| `FuzzTarget` | **Fuzz target wrapping a property test** |
| `FuzzableConfig` | Configuration for a fuzzable target. |
| `FuzzableRNG` | **Random number generator backed by fuzz data** |
| `FuzzingCrash` | Represents a crash discovered during fuzzing. |
| `Gen` | Generates random values of type `T` with built-in shrinking support. |
| `GeneratedTest` | Information about a generated test. |
| `GeneratorConstraint` | Constraints for the `#draw` expression macro. |
| `GeneratorExpression` | A type representing generator expressions for the @Gen DSL. |
| `GhostwriterConfig` | Configuration for the Ghostwriter test generator. |
| `GhostwriterManifest` | Manifest tracking generated tests for incremental regeneration. |
| `GhostwriterResult` | Result of running the Ghostwriter. |
| `HBEdge` | Edge in happens-before graph |
| `HBGraph` | Happens-before relationship graph for operations |
| `HTTPRequest` | **HTTP-like request structure for API testing** |
| `HappensBefore` | Happens-before relationship graph with causal reasoning |
| `IncrementCommand` | A command that modifies a simple counter |
| `InheritedType` | Inherited type from SourceKitten. |
| `InputClassifier` | **Classifier function for inputs** |
| `InterleavingPath` | Records the exact sequence of operation orderings for reproduction. |
| `InterleavingTrace` | Complete execution trace with rich metadata |
| `InternetGenerators` | Generators for realistic internet-related data. |
| `InvariantStream` | **Lazy invariant stream with O(k) memory overhead** |
| `InvariantVerificationResult` | _No documentation_ |
| `IsolationReport` | Actor isolation compliance report |
| `IsolationViolation` | _No documentation_ |
| `JSONSchemaData` | **JSON Schema data structure** |
| `LabelStats` | Statistics for a single target label |
| `LabeledProperty` | A property with an attached descriptive label for failure reporting. |
| `Lazy` | Lazy container for deferred computation of shrink options |
| `Lens` | A composable functional optic providing focused immutable access and updates ... |
| `Linearization` | Linearization ordering of steps |
| `LinearizationWitness` | Witness for linearizability (valid sequential execution) |
| `LocaleData` | _No documentation_ |
| `LoremGenerators` | Generators for Lorem Ipsum placeholder text. |
| `MetamorphicDiscoveryEngine` | Engine for discovering new metamorphic relations |
| `MetamorphicProperty` | A property that verifies metamorphic relations |
| `MetamorphicRelation` | A metamorphic relation between inputs and outputs |
| `MetamorphicTestResult` | Result of metamorphic testing |
| `MetamorphicTestRunner` | Runner for executing metamorphic tests |
| `MethodInfo` | Information about a type's method. |
| `MiningConfig` | Configuration for invariant mining |
| `MiningStatistics` | _No documentation_ |
| `ModelCommandSequenceGenerator` | print("Generated sequence of \(sample.count) commands") |
| `ModelTestConfig` | **Configuration parameters for model-based testing** |
| `NameGenerators` | Generators for realistic person names. |
| `Node` | A node in the shrink tree containing a value and its potential shrinks |
| `NonLinearizableWitness` | Witness for non-linearizability |
| `ObjectTracker` | Tracks object references to detect cycles during pretty-printing. |
| `Operation` | Operation with complete timing and context information |
| `OperationContext` | Context information for operations |
| `ParallelExecutionConfig` | Configuration for parallel execution |
| `ParallelExecutionResult` | Result of parallel property execution |
| `PartialAnalysis` | Partial analysis results for timeout cases |
| `PathCondition` | Represents a path condition in program execution |
| `PendingOperation` | Represents an operation waiting to be scheduled |
| `PerformanceMetrics` | **Performance metrics** |
| `PersistedFailure` | A persisted record of a property test failure. |
| `PrettyConfig` | **Pretty-printing configuration** |
| `PrettyPrinter` | **Core pretty-printing engine** |
| `Prism` | A functional optic for focusing on one case of a sum type (like Optional or R... |
| `Property` | A testable proposition over generated values of type T. |
| `PropertyConfig` | Configuration parameters controlling property test execution. |
| `PropertyEffect` | Represents an effectful property test that can be executed on specific actors |
| `PropertyEffectFailure` | Detailed failure information for PropertyEffect execution |
| `PropertyEffectResult` | Result of executing a PropertyEffect |
| `PropertyInfo` | Information about a type's property. |
| `PropertyTestFailure` | Property test failure with DICE trace information |
| `QuarantineReasonBuilder` | **Efficient quarantine reason builder** |
| `QuarantineRecord` | **Quarantine record** |
| `RegressionMiner` | _No documentation_ |
| `RelationCatalog` | Catalog of common metamorphic relations |
| `RelationResult` | Result of testing a metamorphic relation |
| `RelationViolation` | A violation of a metamorphic relation |
| `ReportSummary` | **Report summary statistics** |
| `ReproString` | A deterministic reproduction string for property test failures. |
| `ReproduceReport` | Formatted report with reproduction information for a failing example. |
| `ResourceCorrelation` | **Resource usage correlation analysis** |
| `ResourceSnapshot` | **Resource monitoring data** |
| `RoseTree` | Rose tree (multi-way tree) for complex hierarchical structures. |
| `SMTConstraint` | Represents a constraint that can be solved by SMT solvers |
| `SMTGenerator` | SMT-guided generator that uses constraint solving for intelligent input synth... |
| `SMTSolverConfig` | Configuration for SMT solver execution |
| `SMTSolverStatistics` | Statistics for SMT solver usage |
| `SMTVariableDeclaration` | Variable declaration with sort information |
| `Sanitizer` | Compiler sanitizers for fuzzing. |
| `Scheduler` | Controls the execution order of concurrent operations for deterministic testing. |
| `SchedulerConfig` | Configuration for deterministic scheduling exploration |
| `SchedulerResult` | Result of scheduler exploration |
| `ScoredInput` | An input with its associated target score |
| `ScoredInvariant` | **Scored invariant for priority queue operations** |
| `SearchState` | Search state during Wing-Gong algorithm |
| `Seed` | A 64-bit deterministic seed enabling reproducible random generation. |
| `SeedBasedRandomNumberGenerator` | Adapter integrating `Seed` with Swift's `RandomNumberGenerator` protocol. |
| `SeededRNG` | Seeded random number generator for deterministic execution |
| `SeededRandomNumberGenerator` | A seeded random number generator for reproducible tests. |
| `Shrink` | Generates progressively simpler versions of a value to find minimal counterex... |
| `ShrinkPredicate` | A predicate that controls shrinking behavior for a generator. |
| `ShrinkResult` | Result of property testing with enhanced shrinking information |
| `ShrinkStep` | Represents a single step in the shrinking process. |
| `ShrinkTreeRunner` | Enhanced property runner with shrink tree integration |
| `ShrinkingCheckResult` | Result of a shrinking behavior check. |
| `Size` | Controls the complexity of generated values in property-based testing. |
| `SourceFileInfo` | Information about a parsed source file. |
| `SourceKittenItem` | Individual item in SourceKitten structure. |
| `SourceKittenStructure` | Root structure from SourceKitten JSON output. |
| `SourceLocation` | Source location information for debugging |
| `Spec` | Sequential specification for concurrent data structure |
| `StackStateMachine` | Stack-based state machine for testing |
| `StateFingerprint` | Fingerprint for state compression and cycle detection |
| `StatisticalMiner` | _No documentation_ |
| `Step` | Individual execution step with complete context |
| `StepID` | Unique identifier for execution steps |
| `StreamingCorrelation` | **Streaming correlation using single-pass algorithm** |
| `StreamingStats` | **Streaming statistics using Welford's algorithm** |
| `TargetRecord` | A single recorded target value from a test execution |
| `TargetStatistics` | Statistics about targets collected during a test run |
| `TargetedConfig` | Configuration for targeted property testing |
| `TargetedRunResult` | Result from a targeted property test run |
| `TargetedRunner` | Runs property tests with targeted feedback to find interesting inputs |
| `TaskContext` | Task context for preemption decisions |
| `TaskID` | Unique identifier for tasks in the scheduler |
| `TaskRegistry` | Registry of active tasks |
| `TelemetryEvent` | **Telemetry event** |
| `TelemetryStatistics` | **Telemetry system statistics** |
| `TemplateMiner` | _No documentation_ |
| `TestAsyncIterator` | Test implementation of AsyncIteratorProtocol |
| `TestAsyncSequence` | Test implementation of AsyncSequence for generator testing |
| `TestExecution` | **Test execution result with metadata** |
| `TestFlakeReport` | **Individual test flake report** |
| `TestGenerator` | _No documentation_ |
| `TestIdentifier` | Identifies a specific property test for database lookup. |
| `TestRunStatistics` | Statistics for a single property test run. |
| `ThreadID` | Unique identifier for threads in concurrent execution |
| `TimePatterns` | **Time-based pattern analysis** |
| `TraceViolation` | _No documentation_ |
| `TracingOptions` | _No documentation_ |
| `Traversal` | A functional optic for focusing on zero or more elements within a structure. |
| `TreeGen` | Enhanced generator that produces shrink trees instead of simple values |
| `TypeInfo` | Complete information about a Swift type extracted from source code. |
| `VerificationStep` | Single step in verification process |
| `Vertex` | **Vertex in a directed graph** |

### 🔢 Enums

| Name | Description |
|------|-------------|
| `ActorIsolationStrategy` | Defines how property effects should be isolated across actors |
| `ArbitraryShrinkStrategy` | Shrinking strategy for @Arbitrary macro. |
| `AsyncSequenceGen` | Static generators for AsyncSequence |
| `Backend` | Storage backend options |
| `CombinedGen` | Static generators for combined Optional-Result patterns |
| `ConfigTemplate` | **Configuration Template System** |
| `ConsoleColor` | **Console colors for terminal output** |
| `ConsoleStyle` | **Console styling options** |
| `ContractConfig` | Global configuration for contract testing. |
| `CorpusDatabaseError` | _No documentation_ |
| `CounterOp` | Operations for counter specification |
| `CoverageStrategy` | Strategies for biasing test generation toward uncovered code paths. |
| `CrashType` | Type of crash detected by fuzzer. |
| `DICEOperation` | Types of operations that can be scheduled |
| `DatabaseValue` | **Typed values for database records** |
| `DiffResult` | **Diff representation for comparing values** |
| `DiscoveryMethod` | Methods for discovering invariants |
| `DomainFaker` | Domain-specific faker types for specialized data. |
| `EntryClassification` | Classification of corpus entries |
| `ErrorBehavior` | How to handle error cases in differential testing. |
| `EventType` | **Telemetry event types** |
| `ExecutionOutcome` | Outcome of entire execution |
| `ExecutorMode` | Execution mode for async properties |
| `FailingExampleConfig` | Global configuration for the failing example database. |
| `FailureReason` | Classifies how a property test failed. |
| `FailureReporting` | Failure reporting strategy |
| `Fairness` | Fairness models for task scheduling |
| `FakerLocale` | Supported locales for faker data generation. |
| `FakerType` | Types of fake data that can be generated. |
| `FuzzBridge` | **LibFuzzer entry point** |
| `FuzzResult` | Result of a fuzz execution |
| `FuzzingMode` | Determines how a fuzzable target should be executed. |
| `GeneratorTestHelpers` | Utilities for testing generator behavior. |
| `GhostwriterError` | Errors that can occur during ghostwriting. |
| `HTTPMethod` | **HTTP methods for request generation** |
| `IntModifier` | Modifiers for Int generation |
| `InterleavingHeuristic` | Heuristics for targeted interleaving exploration. |
| `InterleavingResult` | Individual interleaving result |
| `InvariantCategory` | Categories of invariants |
| `IsolatedPropertyResult` | Result of a property test run with crash isolation |
| `IsolationValidation` | Actor isolation validation level |
| `JSONSchemaType` | **JSON Schema type definitions** |
| `JitteringStrategy` | Jittering strategies for inducing race conditions |
| `LinearizabilityResult` | Result of linearizability analysis |
| `MemoryPressureLevel` | _No documentation_ |
| `ModelTestError` | _No documentation_ |
| `ModelTestResult` | print("Review command generation and preconditions") |
| `MutationStrategy` | Strategy for mutating elite inputs during targeted testing |
| `OptionalGen` | Static generators for Optional types |
| `OrderBy` | _No documentation_ |
| `PasswordStrength` | Password strength levels for generation. |
| `PreemptionCause` | Cause of task preemption |
| `PreemptionStrategy` | Preemption strategies for deterministic control |
| `PropertyResult` | print("Gave up after discarding \(discarded) cases in \(iterations) attempts") |
| `PropertyTestResult` | print("Gave up: \(discarded) discarded in \(iterations) iterations") |
| `ProtocolConformance` | Known protocol conformances that trigger test generation. |
| `ProtocolConformanceMapper` | Maps SourceKitten protocol names to Ghostwriter ProtocolConformance. |
| `RecommendationType` | _No documentation_ |
| `RegistryScope` | Defines the scope of a generator registration. |
| `RelationCategory` | Categories of metamorphic relations |
| `ResultGen` | Static generators for Result types |
| `RetryStrategy` | Retry strategy for failed property effects |
| `RuleBasedTestError` | Errors from rule-based tests |
| `RuleBasedTestResult` | Result of a rule-based test run. |
| `SMTBinaryOp` | Binary operators in SMT |
| `SMTExamples` | Example usage of SMT-assisted constraint solving for property-based testing |
| `SMTQuantifier` | Quantifiers in SMT |
| `SMTResult` | Result of SMT constraint solving |
| `SMTSolverError` | Errors that can occur during SMT solving |
| `SMTUnaryOp` | Unary operators in SMT |
| `SMTValue` | SMT values with type information |
| `SchedulerContext` | Container for thread-local scheduler context |
| `SetOp` | Operations for set specification |
| `SetResult` | Results for set specification |
| `Severity` | _No documentation_ |
| `StackCommand` | Commands for stack operations |
| `StackResult` | Result type for stack operations |
| `StateValue` | Value that can be stored in execution state |
| `Strategy` | Scheduling strategy |
| `Strategy` | Exploration strategy for interleavings |
| `StringModifier` | Modifiers for String generation |
| `SuspensionReason` | Reason for task suspension |
| `TargetNormalization` | How to normalize target values for scoring |
| `TargetStrategy` | Strategy for balancing multiple optimization targets |
| `TargetedTestingContext` | Namespace for task-local storage |
| `TaskResult` | Result of task execution |
| `TestError` | Common error types for property-based testing scenarios |
| `TestErrorGen` | Static generators for TestError |
| `TestPattern` | Available test patterns that Ghostwriter can detect and generate. |
| `TestResult` | **Test result enumeration** |
| `TestResult` | _No documentation_ |
| `TestStatus` | **Test status enumeration** |
| `ThrowingFunctionGen` | Static generators for throwing functions |
| `TracingConfig` | Tracing configuration for property effect execution |
| `Trend` | **Trend direction** |
| `TypeKind` | The kind of Swift type. |
| `ValidationMode` | _No documentation_ |
| `Verbosity` | Verbosity level for property test output. |
| `ViolationType` | _No documentation_ |
| `ViolationType` | Type of contract that was violated |
| `ViolationType` | _No documentation_ |
| `VisitResult` | Result of visiting an object |
| `WeightedGen` | Static generators for weighted value distribution |

### 🎭 Actors

| Name | Description |
|------|-------------|
| `AsyncPropertyRunner` | Main runner for executing async properties with concurrency control |
| `ClassificationCoverageSystem` | _No documentation_ |
| `ConcurrencyScheduler` | Active scheduler for inducing specific interleavings |
| `CorpusDatabase` | _No documentation_ |
| `CoverageCollector` | print("Coverage: \(budget.coveragePercentage)%") |
| `DeterministicScheduler` | Deterministic scheduler with complete control |
| `ElitePool` | Priority queue of best inputs for exploitation |
| `FailingExampleDatabase` | Persistent storage for failing test examples. |
| `FlakeHunter` | **Main Flake Hunter system** |
| `FuzzTestRunner` | **Orchestrates fuzzing execution and reporting** |
| `GeneratorExhaustionTracker` | **Actor-based exhaustion tracking for generators** |
| `GeneratorRegistry` | Thread-safe registry for custom generator registration and lookup. |
| `Ghostwriter` | Main Ghostwriter class that orchestrates automatic test generation. |
| `InvariantMiningEngine` | Main engine for discovering invariants from execution traces |
| `IsolatedPropertyRunner` | print("Crashed with signal \(signal) on: \(shrunk)") |
| `LinearizabilityChecker` | Main linearizability checker with Wing-Gong algorithm |
| `ModelTestRunner` | print("Gave up with \(discarded) discarded sequences") |
| `ParallelPropertyRunner` | **ParallelPropertyRunner**: Executes property tests with concurrent jittering |
| `PropertyEffectExecutor` | Actor-based executor for PropertyEffect with isolation guarantees |
| `PropertyRunner` | print("? Gave up after \(discarded) discards") |
| `RegressionBank` | Actor-based regression bank for persisting and replaying failed test cases. |
| `RuleBasedTestRunner` | Runner for executing rule-based state machine tests. |
| `SMTSolver` | Actor for managing SMT solver interactions |
| `SerialPropertyExecutor` | Actor that ensures deterministic serial execution of async properties |
| `SourceAnalyzer` | Analyzes Swift source files to extract type information. |
| `SourceKittenClient` | Client for interacting with SourceKitten CLI to get accurate type information. |
| `StringPool` | **String pool for efficient string interning** |
| `TelemetrySystem` | _No documentation_ |

### ⚡ Funcs

| Name | Description |
|------|-------------|
| `I` | _No documentation_ |
| `K` | _No documentation_ |
| `S` | _No documentation_ |
| `Y` | _No documentation_ |
| `addKnownSymbols` | Register known symbols to track (typically from static analysis). |
| `addTraces` | Add execution traces for analysis |
| `adding` | Return new statistics with added value (non-mutating) |
| `adding` | Return new correlation with added pair (non-mutating) |
| `allFailures` | Get all banked failure entries. |
| `analyze` | Analyze a single source file. |
| `analyze` | Analyze multiple source files. |
| `analyzeCoverage` | **Analyze coverage for a contract** |
| `analyzeStructure` | Analyze a Swift file and return type structure information. |
| `and` | Combine with another async predicate using AND |
| `and` | Combines this predicate with another using AND logic. |
| `and` | Combine with another PropertyEffect using logical AND |
| `and` | Combine two properties with logical AND |
| `and` | Combine constraints with AND logic |
| `append` | Lens for appending to a collection |
| `appending` | Create a new path with an additional step |
| `apply` | Applicative apply |
| `apply` | Applies a generated function to generated values. |
| `apply` | _No documentation_ |
| `apply` | _No documentation_ |
| `apply` | _No documentation_ |
| `applyN` | **Apply function multiple times** |
| `arrayElementLens` | **Lens for array element access** |
| `asGen` | **Convert to a generator for use in property-based testing** |
| `asMetamorphic` | Convert to metamorphic property with automatic relation discovery |
| `best` | Get best value for a label |
| `biased` | Create a coverage-guided version of this generator |
| `breadthFirst` | Breadth-first traversal of the shrink tree |
| `build` | **Build the final configuration** |
| `build` | _No documentation_ |
| `build` | Build the final reason string |
| `build` | Returns the trace without marking it complete. |
| `captureResourceSnapshot` | _No documentation_ |
| `check` | Check linearizability using Wing-Gong algorithm with optimizations |
| `check` | Test if this relation holds for a given input and function |
| `checkInvariant` | Check an invariant at runtime. |
| `checkPostcondition` | Check a postcondition at runtime. |
| `checkPrecondition` | Check a precondition at runtime. |
| `checkPropertiesAsyncConcurrently` | Execute multiple PropertyEffect instances concurrently with isolation guarantees |
| `checkProperty` | Execute a property-based test and record results with Swift Testing's issue s... |
| `checkPropertyAsync` | Asynchronously execute a property-based test with integration to Swift Testing. |
| `checkPropertyAsyncDetached` | Execute a PropertyEffect in a detached task context |
| `checkPropertyAsyncOnActor` | Execute a PropertyEffect on the MainActor with comprehensive validation |
| `checkPropertyAsyncOnGlobalActor` | Execute a PropertyEffect on a specific global actor |
| `checkPropertyAsyncSerially` | Execute a PropertyEffect with serial execution guarantees |
| `checkSat` | Check satisfiability without retrieving model |
| `checkWithConfidence` | Test relation with multiple inputs for statistical confidence |
| `cleanup` | Clean up old entries based on retention policy |
| `clear` | Clear all recorded targets (for reuse) |
| `clear` | Clear all interned strings |
| `clear` | Clear all examples for a test |
| `clearAll` | Clears all registrations. |
| `clearAll` | Removes all failures. |
| `clearAll` | Remove all banked failures. |
| `clearAll` | Clear entire database |
| `clearFailures` | Removes all failures for a specific test. |
| `clearFailuresForProperty` | Remove all failures for a given property. |
| `clearObservations` | **Clear observations for a contract** |
| `colorized` | **Apply color with fallback for non-color terminals** |
| `compact` | Formats statistics as a compact one-liner. |
| `complete` | Marks the shrinking as complete with the minimal counterexample. |
| `complete` | Completes the trace and returns it. |
| `compose` | Compose this lens with another lens to focus deeper into nested structures. |
| `compose` | **Function Composition (Mathematical)** |
| `computeScore` | Compute aggregate score from all targets |
| `computeStatistics` | Compute statistics for all labels |
| `concurrent` | Create concurrent version of this property |
| `concurrent` | Check if two steps are concurrent (neither precedes the other) |
| `condensedSummary` | Generates a condensed one-line summary. |
| `conditionally` | **Conditional updates** |
| `constant` | **Constant Function** |
| `constrained` | Apply a constraint to the generator |
| `constrained` | Apply multiple constraints to the generator |
| `contramap` | Transform input before testing |
| `contramap` | Transforms the shrinking context via a function. |
| `contramapWith` | Create a new PropertyEffect with a different input type by providing both |
| `convertPropertyResult` | print("Original: \(original), Minimized: \(shrunk)") |
| `copy` | **Functional Setter Utilities** |
| `currentBudget` | Get the current coverage budget for guiding test generation. |
| `curry` | **Curry a binary function** |
| `curry` | **Curry a ternary function** |
| `data` | Get locale data, loading lazily if needed. |
| `debounce` | **Debounce function execution** |
| `debugInfo` | Generate debugging information |
| `delay` | Calculate delay for attempt number (0-indexed) |
| `dependent` | Create generators that depend on previously generated values. |
| `depthFirst` | Depth-first traversal of the shrink tree |
| `deregister` | Deregisters a generator for a type. |
| `dictionaryValueLens` | **Lens for dictionary value access** |
| `diff` | _No documentation_ |
| `diff` | _No documentation_ |
| `diff` | _No documentation_ |
| `diff` | **Create a diff visualization** |
| `diffAny` | **Create a diff visualization for any Equatable types** |
| `discover` | Attempt to discover relations by analyzing function behavior |
| `diverges` | _No documentation_ |
| `encode` | _No documentation_ |
| `encode` | _No documentation_ |
| `encode` | _No documentation_ |
| `encode` | _No documentation_ |
| `encode` | _No documentation_ |
| `endGenerationPhase` | Records the end of generation phase. |
| `endShrinkingPhase` | Records the end of shrinking phase. |
| `endSpan` | **End a span** |
| `endTrace` | **End a trace** |
| `enqueue` | _No documentation_ |
| `examples` | Retrieve all known failing examples for a test |
| `execute` | Execute task serially with deterministic ordering |
| `execute` | Execute the target with given fuzz data |
| `execute` | Execute a target with given data |
| `execute` | _No documentation_ |
| `execute` | _No documentation_ |
| `execute` | _No documentation_ |
| `executeAll` | Execute all scheduled operations according to strategy |
| `executeAny` | _No documentation_ |
| `executeDefault` | Execute the default (first registered) target |
| `executing` | Create child state by executing an operation |
| `expectDifference` | Assert that a value changes in expected ways after an operation. |
| `expectDifference` | Async version of `expectDifference` for testing async operations. |
| `expectNoDifference` | Assert that two values have no difference. |
| `explanation` | Generate human-readable explanation |
| `extractConformances` | Extract protocol conformances for a type from SourceKitten output. |
| `failures` | Returns failures for a specific test. |
| `failures` | Returns failures for a specific test. |
| `failuresForProperty` | Get failures for a specific property. |
| `filter` | Filter shrinks based on a predicate while preserving structure |
| `filter` | Filter generated values while preserving shrinking. |
| `filter` | Filter generated values using an assumption (alias for suchThat). |
| `filterWithIndex` | **Filter with index** |
| `filtered` | Filters shrink candidates using a predicate. |
| `finalize` | Finalizes and returns the collected statistics. |
| `findMinimal` | Find the minimal shrink that satisfies a property |
| `fingerprint` | Generate fingerprint for cycle detection |
| `flatMap` | FlatMap for composing lazy computations |
| `flatMap` | Bind operation for monadic composition |
| `flatMap` | Monadic bind |
| `flatMap` | Monadic bind for dependent shrinking structures. |
| `flatMap` | Sequences dependent generators, where the second depends on the first's output. |
| `flattenTuple` | _No documentation_ |
| `flattenTuple` | _No documentation_ |
| `flattenTuple` | _No documentation_ |
| `flip` | **Flip the arguments of a binary function** |
| `flush` | **Flush all buffered events** |
| `formatMessage` | Formats a failure report as a message string. |
| `formatted` | Formats statistics as a human-readable string. |
| `formatted` | Formats aggregate statistics as a summary. |
| `formattedOutput` | Generates a formatted text representation of the trace. |
| `formattedReport` | Generates a formatted failure report. |
| `functionalUpdate` | **Copy with functional updates** |
| `fuzz` | Execute this generator with fuzz data |
| `fuzz` | Execute this property with fuzz data |
| `fuzzTarget` | Create a fuzz target from this generator |
| `generate` | Generate value satisfying constraints |
| `generateCommand` | _No documentation_ |
| `generateCommand` | _No documentation_ |
| `generateInputs` | Generate inputs that satisfy this path condition |
| `generateMultiple` | Generate multiple values satisfying constraints |
| `generatePropertyTest` | Generate code for this invariant as a property test |
| `generateReport` | **Generate comprehensive flake report** |
| `generateSequence` | Generates a sequence of values deterministically using this seed. |
| `generateSequenceDiagram` | Visualize trace as sequence diagram |
| `generateSolutions` | Generate multiple solutions for constraint |
| `generateTest` | _No documentation_ |
| `generateTestFile` | Generate a complete test file for a source file's types. |
| `generateTests` | Generate all tests for a type. |
| `get` | _No documentation_ |
| `getAll` | Get all inputs |
| `getAllQuarantinedTests` | **Get all quarantined tests** |
| `getAndResetExhaustionCount` | Get and reset exhaustion statistics |
| `getCoverageSummary` | **Get coverage summary** |
| `getCurrentTargetCollector` | Global accessor for the current target collector |
| `getEnabledOps` | Get operations that can be executed next (respecting HB constraints) |
| `getExecutionOrder` | Get the execution order from last run |
| `getExhaustionCount` | Get current exhaustion count without resetting |
| `getExhaustionEvents` | Get current exhaustion event count |
| `getQuarantineRecord` | **Get quarantine record for a test** |
| `getRecordedHistories` | Get recorded histories for debugging |
| `getStatistics` | Get runner statistics |
| `getStatistics` | Get statistics about mining progress |
| `getStatistics` | _No documentation_ |
| `getStatistics` | Get solver statistics |
| `getStatistics` | Get corpus statistics |
| `getStatistics` | Get execution statistics |
| `getStatistics` | **Get telemetry statistics** |
| `getStatistics` | **Get flake statistics for a test** |
| `getTask` | _No documentation_ |
| `ghostwrite` | Run Ghostwriter with default configuration for a source path. |
| `ghostwrite` | Run Ghostwriter for multiple sources. |
| `happensBefore` | Check if operation happens-before another |
| `happensBefore` | Check if operation A happens-before operation B |
| `hash` | _No documentation_ |
| `hash` | _No documentation_ |
| `hash` | _No documentation_ |
| `hash` | _No documentation_ |
| `hash` | _No documentation_ |
| `identity` | **Identity Function** |
| `insert` | Insert a scored input, maintaining max size |
| `intern` | Intern a string, returning the canonical instance |
| `internAll` | Intern multiple strings |
| `invariant` | _No documentation_ |
| `invariant` | _No documentation_ |
| `isAvailable` | Check if SourceKitten is installed and available. |
| `isQuarantined` | **Check if a test is quarantined** |
| `isRegistered` | Checks if a generator is registered for a type. |
| `isSatisfiable` | Check if path condition is satisfiable |
| `iterations` | _No documentation_ |
| `label` | Attach a descriptive label to this property for better failure messages. |
| `lazyY` | **Lazy Y Combinator** |
| `loadAll` | Loads all failures. |
| `loadDatabase` | Loads the failure database from disk. |
| `lookup` | Looks up a registered generator for a type. |
| `makeAsyncIterator` | _No documentation_ |
| `makeAsyncIterator` | _No documentation_ |
| `map` | Map over lazy computation while preserving laziness |
| `map` | Map over the node value while preserving shrink structure |
| `map` | Functor map - preserves shrink structure |
| `map` | Transforms generated values using a pure function. |
| `mapGenerator` | Transform the generator while keeping the same predicate. |
| `mapPredicate` | print("Testing: \(value)") |
| `mapWithIndex` | **Map with index** |
| `markComplete` | Marks the test as complete. |
| `markFixed` | Mark an example as fixed (remove from database) |
| `memoize` | **Memoization** |
| `metamorphic` | Create a metamorphic property for this generator |
| `mine` | _No documentation_ |
| `mine` | _No documentation_ |
| `mine` | _No documentation_ |
| `mine` | _No documentation_ |
| `mineInvariants` | Mine invariants from collected traces |
| `minimizeTrace` | Extract minimal trace that reproduces outcome |
| `needsRegeneration` | Check if regeneration is needed. |
| `negation` | Negate this property (logical NOT). |
| `next` | Advances the seed and returns both the next random value and next seed. |
| `noShrink` | Disables shrinking for this generator. |
| `observeExecution` | **Observe test execution with input classification** |
| `old` | Captures a value before method execution for use in postconditions. |
| `optionalLens` | **Lens for nested optional configurations** |
| `or` | Combine with another async predicate using OR |
| `or` | Combines this predicate with another using OR logic. |
| `or` | Combine two properties with logical OR |
| `or` | Combine constraints with OR logic |
| `originalValue` | _No documentation_ |
| `over` | Apply a transformation function to the focused value. |
| `over` | Modify a value if it matches this prism |
| `overlaps` | Check if operation overlaps with another |
| `parensIf` | **Add parentheses if condition is true** |
| `partial` | **Partial application for binary functions** |
| `pipe` | **Forward Composition (Pipeline)** |
| `popScope` | Pops the most recent scope from the active scope stack. |
| `postcondition` | _No documentation_ |
| `postcondition` | _No documentation_ |
| `postcondition` | _No documentation_ |
| `precedes` | Check if step A happens-before step B |
| `precondition` | _No documentation_ |
| `precondition` | _No documentation_ |
| `precondition` | _No documentation_ |
| `predecessors` | Find all steps that happen-before given step |
| `prepend` | Lens for prepending to a collection |
| `preserveField` | Creates a shrink predicate that preserves a specific field. |
| `preserveFields` | Creates a shrink predicate that preserves multiple fields. |
| `prettyDescription` | **Pretty-print the property result** |
| `prettyDiff` | **Global diff function** |
| `prettyDoc` | _No documentation_ |
| `prettyDoc` | _No documentation_ |
| `prettyDoc` | _No documentation_ |
| `prettyDoc` | _No documentation_ |
| `prettyDoc` | _No documentation_ |
| `prettyDoc` | _No documentation_ |
| `prettyDoc` | _No documentation_ |
| `prettyPrint` | **Global pretty-print function** |
| `print` | **Pretty-print any printable value** |
| `promoteInteresting` | Promote interesting entries to higher priority |
| `propertyEffect` | Create a PropertyEffect from this generator |
| `prune` | Prune the tree to a maximum depth for performance |
| `pushScope` | Pushes a new scope onto the active scope stack. |
| `put` | Store entry in the corpus |
| `quarantineTest` | **Manually quarantine a test** |
| `randomElement` | Get a random elite input for mutation |
| `reason` | _No documentation_ |
| `recentFailures` | Returns the most recent failures. |
| `recentFailures` | Returns the most recent failures. |
| `record` | Record a target value to maximize |
| `record` | Record a floating-point target value to maximize |
| `record` | Record an integer target value with a goal (minimizing distance) |
| `record` | Record a floating-point target value with a goal (minimizing distance) |
| `record` | Record targets from a single iteration |
| `record` | Records a shrinking step. |
| `recordCounterexample` | **Record a counterexample event** |
| `recordEvent` | **Record a telemetry event** |
| `recordExecution` | Record a test execution with observed coverage data. |
| `recordExecution` | **Record a test execution** |
| `recordExhaustion` | Record generator exhaustion attempts |
| `recordFailure` | Records a failure with Swift Testing's issue system. |
| `recordFailure` | Records a failure and optionally persists it. |
| `recordFailure` | _No documentation_ |
| `recordFromResult` | Convenience method to record a failure from a PropertyResult. |
| `recordGeneration` | Records that a value was generated. |
| `recordPerformanceMetrics` | **Record performance metrics** |
| `recordResourceSnapshot` | **Record resource utilization** |
| `recordShrinkAttempt` | Records a shrink attempt. |
| `recordTarget` | Record an integer target value to maximize during testing |
| `recordTarget` | Record a floating-point target value to maximize during testing |
| `recordTarget` | Record an integer target value to reach a specific goal |
| `recordTarget` | Record a floating-point target value to reach a specific goal |
| `reduceWithIndex` | **Reduce with index** |
| `referenceID` | Check if an object has been seen before (without starting a visit) |
| `register` | Registers a generator for a specific type. |
| `register` | Registers this generator in the shared registry. |
| `register` | Register a fuzz target |
| `registerClassifier` | **Register an input classifier** |
| `registerContract` | **Register a coverage contract** |
| `releaseFromQuarantine` | **Manually release a test from quarantine** |
| `remove` | Removes a failure by ID. |
| `removeContract` | **Remove a contract** |
| `removeFailure` | Remove a specific failure from the bank (e.g., when bug is fixed). |
| `removeLast` | Remove the last element from a collection |
| `render` | Render the diff to a string with the given format |
| `render` | **Render a document to a string** |
| `reproduceAnnotation` | Generate @Reproduce annotation string |
| `rescue` | **Rescue combinator** |
| `reset` | Reset statistics and recorded histories |
| `reset` | Reset scheduler state |
| `resetStatistics` | Reset statistics |
| `run` | Run an async property with the configured settings |
| `run` | Run this property once with default runner |
| `run` | Run the PropertyEffect with full actor isolation and tracing |
| `run` | _No documentation_ |
| `run` | Run a single metamorphic property |
| `run` | Run a sequence of random operations and verify contracts. |
| `run` | Run the state machine test |
| `run` | Run a targeted property test |
| `run` | _No documentation_ |
| `runAll` | Run multiple properties in sequence |
| `runAll` | Run multiple metamorphic properties in parallel |
| `runConcurrently` | Run concurrent operations with randomized scheduling |
| `runDetached` | Execute this PropertyEffect in a detached task |
| `runModelTest` | print("Test gave up: \(discarded)/\(iterations) sequences discarded") |
| `runOnMainActor` | Execute this PropertyEffect on MainActor |
| `runProperty` | Executes a property test with given configuration. |
| `runProperty` | Run a property test with crash isolation |
| `runPropertyAsync` | _No documentation_ |
| `runPropertySynchronously` | Helper function to run a property test synchronously from synchronous contexts. |
| `runPropertyWithCoverage` | **Run property test with classification coverage** |
| `runPropertyWithCoverageGuidance` | Run property with coverage guidance |
| `runPropertyWithCoverageTracking` | Run property with automatic coverage tracking |
| `runPropertyWithFlakeDetection` | Run property test with flake detection |
| `runPropertyWithTelemetry` | _No documentation_ |
| `runSerially` | Execute this PropertyEffect with serial execution |
| `runWithCorpus` | Run property test with corpus database integration |
| `sample` | Sample a value using explicit seed for deterministic generation. |
| `save` | Save crash to file for corpus. |
| `save` | Saves a single failure. |
| `save` | Save a failing example for a test |
| `save` | Save manifest to file |
| `saveDatabase` | Saves the failure database to disk. |
| `saveFailure` | Save a failure with all metadata |
| `scaled` | Scales the size by a multiplicative factor. |
| `schedule` | Schedule an operation for execution |
| `seed` | _No documentation_ |
| `seedsForProperty` | Get all seeds that should be replayed for a given property. |
| `serialize` | Export trace for external analysis tools |
| `set` | Update the focused value to a new value in the root structure. |
| `set` | Set all focused values to a specific value |
| `set` | **Apply lens-based update** |
| `setEnabled` | **Enable or disable telemetry** |
| `shrink` | Shrink the path to find minimal counterexample |
| `shrinkTrace` | Shrink failed execution trace to minimal counterexample |
| `shrinking` | _No documentation_ |
| `shrunkValue` | _No documentation_ |
| `solve` | Solve a constraint using the configured SMT solver |
| `sorted` | Get sorted array of all items (ascending) |
| `sortedDescending` | Get sorted array of all items (descending) |
| `split` | Splits the seed to create an independent parallel seed. |
| `split` | Creates multiple independent seeds for parallel test execution. |
| `startGenerationPhase` | Records the start of generation phase. |
| `startShrinkingPhase` | Records the start of shrinking phase. |
| `startSpan` | **Start a span within a trace** |
| `startTrace` | **Start a new trace** |
| `statistics` | Get summary statistics about the regression bank. |
| `statistics` | Get statistics about the database |
| `step` | Records a shrink attempt. |
| `styled` | **Apply multiple colors/styles** |
| `suchThat` | Filters generated values to only those satisfying a predicate. |
| `summary` | _No documentation_ |
| `summary` | print(report.summary()) |
| `summary` | Summary for diagnostics |
| `summary` | Generate human-readable summary |
| `surrounded` | **Surround document with delimiters** |
| `take` | Take only the first n shrinks for performance |
| `test` | Test the two implementations on a given input |
| `test` | Test the two implementations on a given input |
| `test` | Test the predicate with a value |
| `test` | Test all relations with generated inputs |
| `testName` | _No documentation_ |
| `testOrThrow` | Test and throw if divergence is found |
| `testOrThrow` | Test and throw if divergence is found |
| `then` | **Chain updates fluently** |
| `throttle` | **Throttle function execution** |
| `time` | **Function Timing** |
| `time` | _No documentation_ |
| `toExitCode` | Convert result to CLI exit code. |
| `toJSON` | Converts to JSON string. |
| `toJSON` | Converts to JSON string. |
| `toJSON` | Generates a JSON representation of the trace. |
| `toPropertyTest` | Convert to property test reproduction. |
| `toReproduceAnnotation` | Convert to @Reproduce annotation. |
| `toSMTLIB2` | Convert to SMTLIB2 format |
| `tryF` | **Try combinator for error handling** |
| `typed` | Attempts to cast back to a typed generator. |
| `uncurry` | **Uncurry a curried function** |
| `unfold` | Convert to all possible values in shrink order |
| `uniqueCandidates` | Filters shrink candidates to remove identical values. |
| `unknown` | _No documentation_ |
| `unknown` | _No documentation_ |
| `unknown` | _No documentation_ |
| `unknown` | _No documentation_ |
| `until` | **Until combinator** |
| `update` | **Apply lens-based transformation** |
| `validLinearizations` | Compute linearization respecting happens-before |
| `validate` | Validates whether a candidate is a valid shrink of the original. |
| `validateAllContracts` | **Validate all active contracts** |
| `validateFunctorLaws` | Validate functor laws for this generator. |
| `verifyInvariants` | Verify invariants against new traces |
| `verifyInvariants` | Default implementation returns true (no invariants defined) |
| `view` | Extract the focused value from the root structure. |
| `waitAll` | Wait for all scheduled operations to complete |
| `waitIdle` | Wait until no operations are pending |
| `when` | **Multiple conditional updates** |
| `while_` | **While combinator** |
| `with` | **Apply a transformation** |
| `withCorpusRecording` | Run property with automatic corpus recording |
| `withCorpusReplay` | Create generator that replays from corpus first, then generates new values |
| `withCoverageGuidance` | Create a coverage-guided version of this property |
| `withDeterministicScheduler` | Execute with complete deterministic control |
| `withScheduler` | Execute code with a scheduler context |
| `withScope` | Executes a closure within a specific scope. |
| `withShrink` | Replaces the shrinking strategy with a custom one. |
| `withTracing` | Generate traces while running this generator |
| `yield` | Yield control to allow other tasks to run |
| `zip` | Combines two generators into a tuple generator. |

---

## InvariantSwiftMacros

_32 enums, 35 funcs, 16 inits, 38 lets, 2 protocols, 44 structs, 25 vars_

### 📋 Protocols

| Name | Description |
|------|-------------|
| `Generatable` | **Protocol for types that can generate instances** |
| `MacroDiagnostic` | A protocol for macro-specific diagnostic messages that reduces boilerplate. |

### 📦 Structs

| Name | Description |
|------|-------------|
| `AdHocDiagnosticMessage` | _No documentation_ |
| `ArbitraryMacro` | _No documentation_ |
| `AsyncPropertyTestMacro` | `@AsyncPropertyTest` macro for concurrent property testing with controlled sc... |
| `AttributeBuilder` | Builder for constructing attribute syntax nodes. |
| `BundleMacro` | `@Bundle` macro for accumulating values across rules. |
| `BusinessRuleMacro` | _No documentation_ |
| `ClosureBuilder` | Builder for constructing closure expressions. |
| `CommandMacro` | _No documentation_ |
| `CompositeMacro` | `@Composite` macro for declarative dependent generator construction. |
| `ContextualDiagnostic` | A diagnostic message wrapper that adds context (field name, type, etc.) to ba... |
| `ContractMacro` | `@Contract` macro for marking protocols with behavioral contracts. |
| `DeriveGenMacro` | **@DeriveGen Macro** |
| `DifferentialTestConfig` | Configuration extracted from @DifferentialTest attribute |
| `DifferentialTestMacro` | `@DifferentialTest` macro for comparing reference and candidate implementations. |
| `DrawMacro` | `#draw` expression macro for drawing values in composite generators. |
| `ExtractedAssociatedValue` | Represents an associated value in an enum case |
| `ExtractedEnumCase` | Represents an extracted enum case |
| `ExtractedField` | Represents an extracted struct field |
| `ExtractedParameter` | Represents an extracted function parameter |
| `FunctionCallBuilder` | Builder for constructing function call expressions. |
| `FuzzableMacro` | `@Fuzzable` macro for generating LibFuzzer entry points. |
| `GenMacro` | _No documentation_ |
| `InvariantMacro` | `@Invariant` macro for marking methods as invariants. |
| `LabelMacro` | _No documentation_ |
| `LawCheckedMacro` | **@LawChecked Macro** |
| `LawMacro` | `@Law` - marks an algebraic law that implementations must satisfy |
| `MacroContext` | A type-safe wrapper around MacroExpansionContext for unified error emission. |
| `MacroExpansionErrorMessage` | _No documentation_ |
| `MacroFixItMessage` | A message for Fix-It suggestions in macro diagnostics. |
| `MacroNoteMessage` | _No documentation_ |
| `PostconditionContractMacro` | `@PostconditionContract` - marks a postcondition on a contract method |
| `PreconditionContractMacro` | `@PreconditionContract` - marks a precondition on a contract method |
| `PreconditionMacro` | `@Precondition` macro for adding preconditions to rules. |
| `PropertyMacro` | _No documentation_ |
| `PropertyMacroConfig` | Extracted configuration from @Property attribute |
| `PropertyTestMacro` | _No documentation_ |
| `ReproduceConfig` | Configuration extracted from @Reproduce attribute |
| `ReproduceMacro` | `@Reproduce` macro for deterministic replay of failing test cases. |
| `RuleBasedTestMacro` | `@RuleBasedTest` macro for declarative stateful testing. |
| `RuleMacro` | `@Rule` macro for marking methods as executable rules. |
| `StateMachineMacro` | _No documentation_ |
| `StructuredInputMacro` | `@StructuredInput` - marks a fuzzable function as taking structured input |
| `TargetMacro` | `#target` freestanding expression macro for targeted property testing. |
| `TestContractMacro` | `@TestContract` macro for generating property tests for a contract. |

### 🔢 Enums

| Name | Description |
|------|-------------|
| `ArbitraryMacroDiagnostic` | _No documentation_ |
| `AttributeParser` | _No documentation_ |
| `BusinessRuleDiagnostic` | _No documentation_ |
| `BusinessRuleError` | _No documentation_ |
| `CompositeMacroDiagnostic` | _No documentation_ |
| `CountModifier` | _No documentation_ |
| `DeclarationAnalyzer` | _No documentation_ |
| `DifferentialTestExtractor` | Helper to extract @DifferentialTest configuration from attributes |
| `DoubleModifier` | _No documentation_ |
| `EnumCaseExtractor` | Extracts case information from enum declarations |
| `FakeGenerator` | _No documentation_ |
| `FieldExtractor` | Extracts field information from struct declarations |
| `GenAttributeExtractor` | _No documentation_ |
| `GenMacroDiagnostic` | _No documentation_ |
| `GeneratorBuilder` | Builds generator expressions for various types. |
| `GeneratorDSL` | _No documentation_ |
| `GeneratorInference` | Complete type-to-generator mapping system. |
| `IntModifier` | _No documentation_ |
| `MathematicalLaw` | **Built-in mathematical laws** |
| `ParameterExtractor` | Extracts parameter information from function declarations |
| `PropertyConfigExtractor` | Extracts configuration from @Property attribute arguments |
| `PropertyFailureFormatter` | Generates human-readable failure messages for property test failures. |
| `PropertyMacroDiagnostic` | _No documentation_ |
| `PropertyTestBodyBuilder` | Builds the body of a property test function. |
| `PropertyTestError` | _No documentation_ |
| `ReproduceExtractor` | Helper to extract @Reproduce configuration from attributes |
| `RuleBasedTestMacroDiagnostic` | _No documentation_ |
| `StateMachineDiagnostic` | _No documentation_ |
| `StringModifier` | _No documentation_ |
| `StructOrEnum` | _No documentation_ |
| `SyntaxFactory` | Factory for creating common SwiftSyntax nodes. |
| `TypeAnalyzer` | Utilities for analyzing and extracting type information from SwiftSyntax. |

### ⚡ Funcs

| Name | Description |
|------|-------------|
| `arg` | Add an unlabeled argument |
| `arg` | Add a labeled argument |
| `arg` | Add integer argument |
| `arg` | Add an unlabeled argument |
| `arg` | Add a labeled argument |
| `arg` | Add an integer argument |
| `arg` | Add a string argument |
| `arg` | Add a boolean argument |
| `arg` | Add an identifier reference argument |
| `arg` | Add unlabeled identifier reference |
| `build` | Build the attribute |
| `build` | Build the closure |
| `build` | Build the function call expression |
| `buildExpr` | Build as ExprSyntax |
| `buildExpr` | Build as ExprSyntax |
| `error` | _No documentation_ |
| `error` | _No documentation_ |
| `error` | _No documentation_ |
| `error` | _No documentation_ |
| `error` | _No documentation_ |
| `error` | Emits an error with a Fix-It suggestion using a replacement node. |
| `expr` | Add an expression as statement |
| `makeUniqueName` | _No documentation_ |
| `param` | Add a parameter name |
| `params` | Add multiple parameters |
| `statement` | Add a statement |
| `trailing` | Add a trailing closure |
| `unknown` | Add a return expression |
| `warning` | _No documentation_ |
| `warning` | _No documentation_ |
| `withField` | Creates a contextual diagnostic with field name. |
| `withField` | Creates a contextual diagnostic with field name and type. |
| `withParameter` | Creates a contextual diagnostic with parameter name. |
| `withParameter` | Creates a contextual diagnostic with parameter name and type. |
| `withType` | Creates a contextual diagnostic with type name. |

---

## Summary

**Total Public Symbols:** 2385

| Module | Symbols |
|--------|---------|
| GhostwriterCLI | 45 |
| InvariantSwift | 2148 |
| InvariantSwiftMacros | 192 |

---

_Generated by `Scripts/generate_api_reference.py`_
