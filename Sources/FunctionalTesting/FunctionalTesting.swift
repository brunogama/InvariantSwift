/// **FunctionalTesting - Advanced Swift 6 Property-Based Testing Framework**
///
/// A comprehensive property-based testing library built on rigorous category theory foundations
/// with protocol-witness pattern architecture. This framework implements mathematical laws and
/// algebraic structures to ensure correctness and composability of test generation.
///
/// **Mathematical Foundation:**
/// Based on category theory, specifically:
/// - **Functors** for structure-preserving transformations: `fmap: (A -> B) -> F<A> -> F<B>`
/// - **Applicative Functors** for context-aware function application
/// - **Monads** for compositional test generation with binding: `(>>=): M<A> -> (A -> M<B>) -> M<B>`
/// - **Coalgebras** for shrinking structures that preserve termination properties
/// - **Lenses** for focused immutable updates following van Laarhoven representation
///
/// Version 2.1.0 introduces **Coverage-Guided Generation** - the first of 30 planned
/// Swift-exclusive capabilities that establish FunctionalTesting as the world's most
/// advanced property-based testing framework.
///
/// **Core Principles:**
/// 1. **Law Verification**: All algebraic structures satisfy their mathematical laws
/// 2. **Composability**: Small, focused generators combine to build complex test cases
/// 3. **Reproducibility**: Deterministic generation via seed-based random number generation
/// 4. **Coverage Guidance**: Intelligent test generation biased toward uncovered code paths
/// 5. **Swift 6 Concurrency**: Actor-isolated property testing with strict concurrency compliance
///
/// **External References:**
/// - [QuickCheck Original Paper](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf)
/// - [Category Theory for Programmers](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/)
/// - [Lens Laws and Applications](https://en.wikipedia.org/wiki/Lens_(computer_science))
/// - [Coalgebra in Computer Science](https://en.wikipedia.org/wiki/Coalgebra)
///
/// **Usage Example:**
/// ```swift
/// import FunctionalTesting
/// import Testing
///
/// @PropertyTest
/// func testArrayReverse(_ array: [Int]) {
///   #expect(array.reversed().reversed() == array)
/// }
///
/// // Coverage-guided testing
/// let runner = PropertyRunner()
/// let property = Property(generator: Gen.int, predicate: { $0 >= 0 })
/// let (result, coverage) = await runner.runPropertyWithCoverageTracking(
///   property,
///   knownSymbols: ["validation", "bounds_check"]
/// )
/// ```

// MARK: - Public API Exports

// Core Types are automatically available within this module
// External modules can import FunctionalTesting to access:

// MARK: Core Property Testing
// - Gen<T> for generators with functor/applicative/monad instances
// - Size for controlling generation complexity
// - Seed for deterministic reproducibility
// - Shrink<T> for counterexample minimization
// - Property<T> for property-based test definitions
// - PropertyResult<T> for test execution results
// - PropertyConfig for test configuration
// - PropertyRunner for async property execution
// - PropertyChecker for synchronous property execution
// - SeedBasedRandomNumberGenerator for Seed-based RNG

// MARK: Model-Based Testing
// - Command protocol for model-based testing commands
// - StateMachine protocol for defining state machine models
// - ModelTestRunner for executing model-based tests
// - ModelTestConfig for model test configuration
// - ModelTestResult<T> for model test execution results

// MARK: Actor-Integrated Property Testing (Phase 2: Intelligence & Automation)
// - PropertyEffect<A> for effectful property tests with actor isolation
// - PropertyEffectExecutor for deterministic actor-isolated execution
// - ActorIsolationStrategy for defining actor isolation patterns
// - EffectConfig for effect execution configuration
// - PropertyEffectResult for effect execution results
// - PropertyEffectFailure for detailed failure reporting
// - checkPropertyAsyncOnActor() for MainActor execution
// - checkPropertyAsyncSerially() for serial execution
// - checkPropertyAsyncDetached() for detached task execution

// MARK: Coverage-Guided Generation (NEW in v2.1.0)
// - CoverageBudget for coverage information and guidance
// - CoverageCollector (actor) for thread-safe coverage tracking
// - CoverageConfig for coverage-guided testing configuration
// - CoverageStrategy for different biasing approaches
// - CoverageReport for test execution coverage analysis
// - ExecutionRecord for recording test execution metadata
// - Gen.biased() for coverage-guided generator variants
// - Property.withCoverageGuidance() for coverage-guided properties
// - PropertyRunner.runPropertyWithCoverageGuidance() for advanced execution
// - PropertyRunner.runPropertyWithCoverageTracking() for automatic tracking

// MARK: Functional Programming & Lens System (NEW in v2.1.0)
// - Lens<Root, Value> for immutable focus and updates
// - Prism<Root, Value> for sum type focusing (Optional, Result)
// - Traversal<Root, Value> for collection-wide updates
// - Function composition operators (•, >>>, |>)
// - Higher-order combinators (curry, flip, compose, pipe)
// - SKI combinator calculus (S, K, I combinators)
// - Y combinator for fixed-point recursion
// - Memoization, throttling, and debouncing utilities
// - Error handling combinators (tryF, rescue)
// - Collection combinators with index access
// - Functional setters and copy utilities

// MARK: Usage Examples
//
// Basic Coverage-Guided Testing:
//     let runner = PropertyRunner()
//     let property = Property(generator: Gen.int, predicate: { $0 >= 0 })
//     let (result, report) = await runner.runPropertyWithCoverageTracking(
//         property,
//         knownSymbols: ["validation", "bounds_check"]
//     )
//
// Advanced Coverage-Guided Testing:
//     let collector = CoverageCollector()
//     await collector.addKnownSymbols(["func1", "func2", "error_path"])
//     let (result, report) = await runner.runPropertyWithCoverageGuidance(
//         property,
//         collector: collector,
//         coverageStrategy: .adaptive
//     )
//
// Functional Programming with Lenses:
//     let configLens = Lens<PropertyConfig, Int>(
//         get: { $0.iterations },
//         set: { iterations, config in
//             PropertyConfig(iterations: iterations, maxShrinks: config.maxShrinks,
//                          maxDiscarded: config.maxDiscarded, seed: config.seed)
//         }
//     )
//
//     let config = PropertyConfig.default
//     let updated = configLens.set(200, config)  // Update iterations to 200
//     let doubled = configLens.over({ $0 * 2 })(config)  // Double the iterations
//
// Function Composition:
//     let addOne = { $0 + 1 }
//     let double = { $0 * 2 }
//     let addThenDouble = addOne >>> double  // Pipeline: add then double
//     let doubleComposed = double • addOne   // Mathematical: double(add(x))
//
//     let result = 5 |> addOne |> double  // Pipeline operator: 5 -> 6 -> 12

// Note: Macros are available as separate import - import FunctionalTestingMacros
