import Foundation

/// Classifies how a property test failed.
///
/// `FailureReason` distinguishes between different failure modes, enabling better
/// diagnostics and targeted fixes:
/// - `.predicateFailed`: The property's predicate returned `false`
/// - `.threwError`: The predicate threw an error during evaluation
/// - `.timedOut`: The test exceeded the configured timeout
///
/// This classification is essential for debugging: a predicate failure suggests
/// a logic bug, while a thrown error may indicate a precondition violation or
/// unexpected edge case.
///
/// - See Also: ``PropertyResult``, ``PropertyConfig``
public enum FailureReason: Sendable, Equatable, CustomStringConvertible {
  /// The property's predicate returned `false`.
  case predicateFailed

  /// The predicate threw an error during evaluation.
  ///
  /// - Parameter error: String description of the thrown error
  case threwError(String)

  /// The test exceeded the configured timeout.
  ///
  /// - Parameter seconds: The timeout duration that was exceeded
  case timedOut(seconds: Double)

  public var description: String {
    switch self {
    case .predicateFailed:
      return "predicate returned false"

    case .threwError(let error):
      return "threw error: \(error)"

    case .timedOut(let seconds):
      return "timed out after \(seconds)s"
    }
  }
}

// swiftlint:disable:next orphaned_doc_comment
/// Outcome of executing a property-based test.
///
/// `PropertyResult<T>` represents the three possible outcomes when running a property test:
/// success, failure with a minimal counterexample, or giving up due to too many discarded cases.
///
/// **Success**: The property held for all generated test cases. Confidence in the property
/// increases with more iterations.
///
/// **Failure**: The property failed on some generated input. The result includes:
/// - `counterexample`: The original failing input (as generated)
/// - `shrunk`: The minimal counterexample (simplified to make debugging easier)
/// - `iterations`: How many test cases were executed before failure
/// - `reason`: Classification of failure type (predicate failed, threw, timed out)
/// - `seed`: The seed used for deterministic reproduction
///
/// **GaveUp**: The property testing framework discarded too many generated values
/// (e.g., all generated inputs violated preconditions). This indicates the property
/// cannot be adequately tested with the current generator and assumptions.
///
/// - Cases:
///   - `success(iterations:)`: Property held for all iterations
///   - `failure(counterexample:iterations:shrunk:reason:seed:)`: Property failed on this input
///   - `gaveUp(discarded:iterations:)`: Too many inputs discarded due to assumptions
///
/// - Example:
///   ```swift
///   let gen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
///   let property = Property(generator: gen) { n in n >= 0 }
///
///   let result = /* run property */
///
///   switch result {
///   case .success(let iterations):
// swiftlint:disable:next no_print
///       print("Passed \(iterations) tests")
///   case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
// swiftlint:disable:next no_print
///       print("Failed after \(iterations) tests (\(reason))")
// swiftlint:disable:next no_print
///       print("Original: \(counterexample), Minimal: \(shrunk)")
// swiftlint:disable:next no_print
///       print("Reproduce with seed: \(seed.rawValue)")
///   case .gaveUp(let discarded, let iterations):
// swiftlint:disable:next no_print
///       print("Gave up after discarding \(discarded) cases in \(iterations) attempts")
///   }
///   ```
///
/// - See Also: ``Property``, ``PropertyRunner``, ``FailureReason``
public enum PropertyResult<T>: Sendable where T: Sendable {
  /// Property held for all generated test cases.
  ///
  /// - Parameters:
  ///   - iterations: Number of test cases successfully checked
  case success(iterations: Int)

  /// Property failed on a generated input.
  ///
  /// - Parameters:
  ///   - counterexample: The original failing input as generated
  ///   - iterations: Number of iterations before failure
  ///   - shrunk: The minimized failing input (typically simpler than counterexample)
  ///   - reason: Classification of how the property failed
  ///   - seed: The seed used for this test run (for reproduction)
  case failure(counterexample: T, iterations: Int, shrunk: T, reason: FailureReason, seed: Seed)

  /// Property testing gave up due to too many discarded cases.
  ///
  /// - Parameters:
  ///   - discarded: Number of generated inputs rejected by the property's assumption
  ///   - iterations: Total number of generation attempts
  case gaveUp(discarded: Int, iterations: Int)
}

/// A testable proposition over generated values of type T.
///
/// `Property<T>` combines a generator with a predicate to form a property:
/// "For all generated values of type T, this predicate holds."
///
/// The property is the fundamental abstraction in property-based testing. Rather than
/// writing individual test cases, you specify a property that should hold universally.
/// The property tester generates many examples and checks the property against each.
///
/// Key concepts:
/// - **Generator**: Produces random test values via `Gen<T>`
/// - **Predicate**: Boolean function checking the property on each value
/// - **Assumption** (optional): Filter for valid test cases (e.g., "only test non-empty arrays")
/// - **Shrinking**: Automatically minimizes counterexamples for easier debugging
///
/// When a property fails, the test framework reports:
/// - The failing input (counterexample)
/// - The minimal failing input (shrunk) for easier debugging
/// - The number of iterations before failure
///
/// A property succeeds if the predicate returns true for all generated test cases.
/// It fails if the predicate returns false on any generated value.
///
/// - Example:
///   ```swift
///   // Property: "Arrays reverse twice give back the original"
///   let arrayGen = Gen.array(Gen<Int> { rng, _ in Int.random(in: 0..<100, using: &rng) })
///
///   let reverseProperty = Property(generator: arrayGen) { array in
///       array.reversed().reversed() == array
///   }
///
///   // Property with assumption: "Non-empty arrays"
///   let headProperty = Property(
///       generator: arrayGen,
///       assumption: { !$0.isEmpty },
///       predicate: { array in
///           array.first == array.reversed().last
///       }
///   )
///   ```
///
/// - See Also: ``PropertyRunner``, ``PropertyResult``, ``Gen``
public struct Property<T>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The predicate that should hold for all generated values.
  public let predicate: (T) -> Bool

  /// Initializes a property with a generator and predicate.
  ///
  /// Creates a property representing: "For all T generated by generator, predicate(T) holds."
  ///
  /// This is the fundamental form of a property. For properties with preconditions
  /// (assumptions), use the convenience initializer that accepts an `assumption` parameter.
  ///
  /// - Parameters:
  ///   - generator: Source of test values
  ///   - predicate: Function checking the property. Must be deterministic and free of side effects.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
  ///
  ///   let property = Property(generator: gen) { n in
  ///       n >= 0 && n < 100
  ///   }
  ///   ```
  ///
  /// - See Also: ``init(generator:assumption:predicate:)``
  public init(generator: Gen<T>, predicate: @escaping (T) -> Bool) {
    self.generator = generator
    self.predicate = predicate
  }

  /// Initializes a property with a generator, assumption, and predicate.
  ///
  /// Creates a property with a precondition (assumption). Only test cases satisfying
  /// the assumption are checked against the predicate. This is the preferred way to
  /// express properties with constraints.
  ///
  /// The assumption filters the generated values. Values failing the assumption are
  /// discarded and don't count toward the required number of successful tests.
  /// If too many values are discarded (default: >90%), the property gives up.
  ///
  /// **Important**: Use assumptions sparingly. If you find yourself discarding >50%
  /// of generated values, consider implementing a custom generator that produces
  /// only valid values instead.
  ///
  /// - Parameters:
  ///   - generator: Source of test values
  ///   - assumption: Filter determining which generated values are valid. Default: accepts all values.
  ///   - predicate: Function checking the property on valid values
  ///
  /// - Example:
  ///   ```swift
  ///   let arrayGen = Gen.array(Gen.pure(0))
  ///
  ///   // Test properties only on non-empty arrays
  ///   let property = Property(
  ///       generator: arrayGen,
  ///       assumption: { !$0.isEmpty },
  ///       predicate: { array in
  ///           array.first! >= 0
  ///       }
  ///   )
  ///   ```
  ///
  /// - See Also: ``init(generator:predicate:)``
  public init(
    generator: Gen<T>,
    assumption: @escaping (T) -> Bool = { _ in true },
    predicate: @escaping (T) -> Bool
  ) {
    self.generator = generator.suchThat(assumption)
    self.predicate = predicate
  }
}

/// Configuration parameters controlling property test execution.
///
/// `PropertyConfig` specifies how property tests run:
/// - How many test cases to generate (`iterations`)
/// - How much effort to spend minimizing failures (`maxShrinks`)
/// - When to give up on generating valid inputs (`maxDiscarded`)
/// - Optional seed for reproducible test runs
///
/// Default configuration (100 iterations, 1000 shrink attempts) balances:
/// - **Coverage**: 100 iterations usually find bugs in well-written code
/// - **Performance**: Reasonable runtime for CI/CD pipelines
/// - **Debugging**: 1000 shrink attempts minimize counterexamples nicely
///
/// Adjust configuration based on your needs:
/// - **Quick sanity check**: Use fewer iterations (10-20)
/// - **Thorough testing**: Use more iterations (1000+)
/// - **Flaky tests**: Fix or skip them, don't increase iterations
/// - **Hard-to-minimize failures**: Increase maxShrinks
///
/// **Precondition handling**: When a generator's assumption filters out values,
/// discarded counts increase. If discarded > maxDiscarded, the property "gives up"
/// to avoid infinite loops. This typically indicates the assumption is too restrictive.
///
/// - Example:
///   ```swift
///   let quickConfig = PropertyConfig(iterations: 10)
///   let thoroughConfig = PropertyConfig(iterations: 10000, maxShrinks: 5000)
///   let reproducibleConfig = PropertyConfig(seed: Seed(value: 42))
///   ```
///
/// - See Also: ``Property``, ``PropertyRunner``
public struct PropertyConfig: Sendable {
  /// Number of test cases to generate and check.
  ///
  /// Typical ranges:
  /// - 10-50: Quick sanity checks
  /// - 100: Default, good for most properties
  /// - 1000+: Thorough testing or difficult properties
  ///
  /// More iterations increase confidence but take longer.
  public let iterations: Int

  /// Maximum shrinking attempts when a property fails.
  ///
  /// Shrinking tries to find the simplest input that still fails the property.
  /// More attempts may find smaller counterexamples but take longer.
  ///
  /// Typical ranges:
  /// - 0: Disable shrinking (return original failing input)
  /// - 100-500: Fast, minimal shrinking
  /// - 1000: Default, usually finds very minimal examples
  /// - 5000+: Aggressive, for properties that are hard to shrink
  public let maxShrinks: Int

  /// Maximum generated values to discard before giving up.
  ///
  /// When a property has assumptions (via `assumption` parameter),
  /// generated values violating the assumption are discarded. If too many
  /// are discarded, the property tester gives up.
  ///
  /// High discardRate (>90%) indicates a misconfigured generator or
  /// assumption. Consider using dependent generation instead.
  public let maxDiscarded: Int

  /// Optional seed for reproducible test runs.
  ///
  /// When set, the test uses this seed for its random number generator,
  /// ensuring identical test runs. Useful for:
  /// - Reproducing failing tests
  /// - Regression testing
  /// - Deterministic testing in CI/CD
  ///
  /// When nil, uses system randomness (different each run).
  public let seed: Seed?

  /// Enables verbose output during test execution.
  ///
  /// When true, prints progress information during test runs:
  /// - Iteration count updates
  /// - Generated test case summaries
  /// - Shrinking progress
  ///
  /// Useful for debugging slow tests or understanding test behavior.
  public let verbose: Bool

  /// Timeout per iteration in seconds.
  ///
  /// When set, each iteration must complete within this time limit.
  /// Iterations exceeding the timeout are treated as failures with
  /// `FailureReason.timedOut`.
  ///
  /// When nil, no timeout is enforced.
  public let timeout: TimeInterval?

  /// Verbosity level for structured output control.
  ///
  /// Provides more granular control than the `verbose` boolean:
  /// - `.silent`: No output
  /// - `.normal`: Only failures and summary
  /// - `.verbose`: All progress information
  public let verbosity: Verbosity

  /// Verbosity level for property test output.
  public enum Verbosity: Sendable {
    /// No output during test execution.
    case silent
    /// Only failures and final summary.
    case normal
    /// All progress including iteration counts and shrinking.
    case verbose
  }

  /// Initializes a property testing configuration.
  ///
  /// - Parameters:
  ///   - iterations: Number of test cases (default: 100). Clamped to at least 1.
  ///   - maxShrinks: Maximum shrink attempts (default: 1000). Clamped to at least 0.
  ///   - maxDiscarded: Maximum discarded cases (default: 1000). Clamped to at least 0.
  ///   - seed: Optional seed for reproducibility. Default: nil (system randomness).
  ///   - verbose: Enable verbose output. Default: false.
  ///   - timeout: Optional per-iteration timeout. Default: nil (no timeout).
  ///   - verbosity: Output verbosity level. Default: .normal.
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig(
  ///       iterations: 500,
  ///       maxShrinks: 2000,
  ///       maxDiscarded: 500,
  ///       seed: Seed(value: 42),
  ///       timeout: 5.0,
  ///       verbosity: .verbose
  ///   )
  ///   ```
  public init(
    iterations: Int = 100,
    maxShrinks: Int = 1000,
    maxDiscarded: Int = 1000,
    seed: Seed? = nil,
    verbose: Bool = false,
    timeout: TimeInterval? = nil,
    verbosity: Verbosity = .normal
  ) {
    self.iterations = max(1, iterations)
    self.maxShrinks = max(0, maxShrinks)
    self.maxDiscarded = max(0, maxDiscarded)
    self.seed = seed
    self.verbose = verbose
    self.timeout = timeout
    self.verbosity = verbosity
  }

  /// Default configuration: 100 iterations, 1000 shrinks, 1000 max discarded.
  ///
  /// A balanced default suitable for most properties. Adjust if needed for
  /// your specific testing requirements.
  public static let `default` = Self()
}

// swiftlint:disable:next orphaned_doc_comment
/// Actor for thread-safe property test execution with shrinking support.
///
/// `PropertyRunner` is the main entry point for executing property-based tests.
/// It coordinates:
/// - Generating test values via the property's generator
/// - Checking the property's predicate on each value
/// - Shrinking when failures occur to find minimal counterexamples
///
/// Actor isolation ensures thread-safe execution. Property tests can run
/// concurrently on different actors without data races.
///
/// **Workflow**:
/// 1. Initialize runner with optional seed
/// 2. Create a property with generator and predicate
/// 3. Call `runProperty` with the property and configuration
/// 4. Interpret the `PropertyResult` (success, failure, or gaveUp)
///
/// **Seeding**:
/// - With seed: All test runs are identical (deterministic)
/// - Without seed: Uses system randomness (different each run)
///
/// Deterministic execution is useful for:
/// - Reproducing test failures for debugging
/// - Regression testing with specific seeds
/// - Distributed testing by seed ranges
///
/// - Example:
///   ```swift
///   let runner = PropertyRunner()
///   let property = Property(generator: Gen.pure(5)) { n in n > 0 }
///
///   let result = await runner.runProperty(property)
///   switch result {
///   case .success(let iterations):
// swiftlint:disable:next no_print
///       print("✓ Passed \(iterations) tests")
///   case .failure(let counterexample, let iterations, let shrunk, _, _):
// swiftlint:disable:next no_print
///       print("✗ Failed: \(shrunk)")
///   case .gaveUp(let discarded, let iterations):
// swiftlint:disable:next no_print
///       print("? Gave up after \(discarded) discards")
///   }
///   ```
///
/// - See Also: ``Property``, ``PropertyConfig``, ``PropertyResult``
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor PropertyRunner {
  private var rng: any RandomNumberGenerator
  private let seed: Seed

  /// Initializes a property runner with optional seed.
  ///
  /// Creates a runner for executing properties. The optional seed determines
  /// whether test execution is deterministic (with seed) or random (without).
  ///
  /// - Parameters:
  ///   - seed: Optional seed for deterministic execution. If nil, uses system randomness.
  ///
  /// - Example:
  ///   ```swift
  ///   let deterministicRunner = PropertyRunner(seed: Seed(value: 42))
  ///   let randomRunner = PropertyRunner()
  ///   ```
  public init(seed: Seed? = nil) {
    let actualSeed = seed ?? Seed.random
    self.seed = actualSeed
    self.rng = SeedBasedRandomNumberGenerator(seed: actualSeed)
  }

  /// Executes a property test with given configuration.
  ///
  /// Runs the property on generated test cases and reports the outcome:
  /// - `.success` if the property holds for all iterations
  /// - `.failure` with minimal counterexample if property fails
  /// - `.gaveUp` if too many generated values violate assumptions
  ///
  /// **Execution process**:
  /// 1. For each iteration (up to config.iterations):
  ///    - Generate a test value using the property's generator
  ///    - Check the predicate on the generated value
  ///    - If predicate fails, begin shrinking the counterexample
  /// 2. Return result (success, failure with shrunk counterexample, or gave up)
  ///
  /// **Shrinking**: When a property fails, the runner uses the generator's
  /// shrinking strategy to find the minimal failing input. This typically
  /// produces much simpler counterexamples, making debugging easier.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - config: Configuration controlling iterations and shrinking. Default: `PropertyConfig.default`
  ///
  /// - Returns: Result indicating success, failure with counterexample, or giving up
  ///
  /// - Example:
  ///   ```swift
  ///   let runner = PropertyRunner()
  ///   let gen = Gen.array(Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) })
  ///   let property = Property(generator: gen) { array in
  ///       array.sorted() == array.sorted().sorted()
  ///   }
  ///
  ///   let result = await runner.runProperty(property, config: PropertyConfig(iterations: 100))
  ///   ```
  ///
  /// - See Also: ``PropertyConfig``, ``PropertyResult``
  public func runProperty<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    for iteration in 0..<config.iterations {
      let size = Size(value: min(iteration, 100))
      let testCase = property.generator.generate(&rng, size)

      // Check if the property holds
      if !property.predicate(testCase) {
        // Property failed - begin shrinking
        let shrunkCase = shrinkFailure(
          testCase,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: iteration + 1,
          shrunk: shrunkCase,
          reason: .predicateFailed,
          seed: seed
        )
      }
    }

    return .success(iterations: config.iterations)
  }

  /// Shrink a failing test case to find the minimal counterexample
  private func shrinkFailure<T>(
    _ failingCase: T,
    property: Property<T>,
    maxShrinks: Int
  ) -> T {
    var current = failingCase
    var shrinkAttempts = 0

    while shrinkAttempts < maxShrinks {
      let candidates = property.generator.shrink.shrink(current)

      // Find the first shrunk value that still fails the property
      let nextFailure = candidates.first { candidate in
        !property.predicate(candidate)
      }

      if let nextFailure = nextFailure {
        current = nextFailure
        shrinkAttempts += 1
      } else {
        // No more shrinking possible
        break
      }
    }

    return current
  }
}

// MARK: - Convenience Extensions

extension Property {
  /// Create a property that checks a boolean condition
  public static func check(
    _ generator: Gen<T>,
    _ condition: @escaping (T) -> Bool
  ) -> Property<T> {
    Property(generator: generator, predicate: condition)
  }

  /// Create a property with an implication (assumption -> conclusion)
  public static func implies(
    _ generator: Gen<T>,
    assumption: @escaping (T) -> Bool,
    conclusion: @escaping (T) -> Bool
  ) -> Property<T> {
    Property(
      generator: generator,
      predicate: { value in
        !assumption(value) || conclusion(value)
      }
    )
  }
}

// MARK: - Property Combinators

extension Property {
  /// Combine two properties with logical AND
  public func and<U>(_ other: Property<U>) -> Property<(T, U)> {
    Property<(T, U)>(
      generator: self.generator.zip(other.generator),
      predicate: { pair in
        self.predicate(pair.0) && other.predicate(pair.1)
      }
    )
  }

  /// Combine two properties with logical OR
  public func or<U>(_ other: Property<U>) -> Property<(T, U)> {
    Property<(T, U)>(
      generator: self.generator.zip(other.generator),
      predicate: { pair in
        self.predicate(pair.0) || other.predicate(pair.1)
      }
    )
  }

  /// Negate this property (logical NOT).
  ///
  /// Creates a new property that passes when this property fails, and fails when
  /// this property passes. Useful for testing boolean algebra laws like:
  /// - `p ∧ ¬p = ⊥` (contradiction)
  /// - `p ∨ ¬p = ⊤` (tautology)
  ///
  /// - Returns: A property with inverted predicate semantics
  ///
  /// - Example:
  ///   ```swift
  ///   let positive = Property(generator: Gen.int) { $0 > 0 }
  ///   let nonPositive = positive.negation()  // $0 <= 0
  ///   ```
  public func negation() -> Property<T> {
    Property(generator: self.generator, predicate: { value in !self.predicate(value) })
  }

  /// A property that always passes (logical TRUE / tautology).
  ///
  /// Creates a property that passes for any generated value. Useful as an identity
  /// element for testing boolean algebra laws like `p ∧ ⊤ = p`.
  ///
  /// - Parameter generator: The generator to use for test values
  /// - Returns: A property that always returns true
  ///
  /// - Example:
  ///   ```swift
  ///   let tautology = Property<Int>.tautology(Gen.int)
  ///   let result = runPropertySynchronously(tautology)
  ///   // Always .success
  ///   ```
  public static func tautology(_ generator: Gen<T>) -> Property<T> {
    Property(generator: generator, predicate: { _ in true })
  }

  /// A property that always fails (logical FALSE / contradiction).
  ///
  /// Creates a property that fails for any generated value. Useful as an identity
  /// element for testing boolean algebra laws like `p ∨ ⊥ = p`.
  ///
  /// - Parameter generator: The generator to use for test values
  /// - Returns: A property that always returns false
  ///
  /// - Example:
  ///   ```swift
  ///   let contradiction = Property<Int>.contradiction(Gen.int)
  ///   let result = runPropertySynchronously(contradiction)
  ///   // Always .failure
  ///   ```
  public static func contradiction(_ generator: Gen<T>) -> Property<T> {
    Property(generator: generator, predicate: { _ in false })
  }

  // MARK: - Transformation Combinators

  // swiftlint:disable:next orphaned_doc_comment
  /// Transform the predicate while keeping the same generator.
  ///
  /// Useful for wrapping or modifying the predicate logic without changing generation.
  ///
  /// - Parameter transform: Function that takes the current predicate and returns a new one
  /// - Returns: Property with transformed predicate
  ///
  /// - Example:
  ///   ```swift
  ///   let prop = Property(generator: Gen.int) { $0 > 0 }
  ///   let wrapped = prop.mapPredicate { predicate in
  ///       { value in
  // swiftlint:disable:next no_print
  ///           print("Testing: \(value)")
  ///           return predicate(value)
  ///       }
  ///   }
  ///   ```
  public func mapPredicate(
    _ transform: @escaping (@escaping (T) -> Bool) -> (T) -> Bool
  ) -> Property<T> {
    Property(generator: self.generator, predicate: transform(self.predicate))
  }

  /// Transform the generator while keeping the same predicate.
  ///
  /// Useful for modifying how values are generated without changing the property assertion.
  ///
  /// - Parameter transform: Function that takes the current generator and returns a new one
  /// - Returns: Property with transformed generator
  ///
  /// - Example:
  ///   ```swift
  ///   let prop = Property(generator: Gen.int) { $0 >= 0 }
  ///   let nonNegative = prop.mapGenerator { gen in
  ///       gen.map { abs($0) }
  ///   }
  ///   ```
  public func mapGenerator(_ transform: @escaping (Gen<T>) -> Gen<T>) -> Property<T> {
    Property(generator: transform(self.generator), predicate: self.predicate)
  }

  /// Filter generated values using an assumption (alias for suchThat).
  ///
  /// Values that don't satisfy the filter condition are discarded. Be careful not to
  /// filter out too many values, as this can cause the property test to give up.
  ///
  /// - Parameter condition: Predicate that generated values must satisfy
  /// - Returns: Property that only tests values satisfying the condition
  ///
  /// - Example:
  ///   ```swift
  ///   let prop = Property(generator: Gen.int) { $0 * $0 >= 0 }
  ///   let positiveOnly = prop.filter { $0 > 0 }
  ///   ```
  public func filter(_ condition: @escaping (T) -> Bool) -> Property<T> {
    Property(generator: self.generator.suchThat(condition), predicate: self.predicate)
  }

  /// Attach a descriptive label to this property for better failure messages.
  ///
  /// Labels appear in test output and help identify which property failed when
  /// running multiple properties.
  ///
  /// - Parameter name: Descriptive label for the property
  /// - Returns: A labeled property wrapper
  ///
  /// - Example:
  ///   ```swift
  ///   let prop = Property(generator: Gen.int) { $0 >= 0 }
  ///       .label("non-negative integers")
  ///   ```
  public func label(_ name: String) -> LabeledProperty<T> {
    LabeledProperty(property: self, label: name)
  }
}

// MARK: - Labeled Property

/// A property with an attached descriptive label for failure reporting.
///
/// Use the `label(_:)` method on `Property` to create a `LabeledProperty`.
/// The label appears in test output and helps identify which property failed.
public struct LabeledProperty<T>: @unchecked Sendable {
  /// The underlying property.
  public let property: Property<T>

  /// Descriptive label for test output.
  public let label: String

  /// Initialize a labeled property.
  public init(property: Property<T>, label: String) {
    self.property = property
    self.label = label
  }
}

// MARK: - Synchronous Property Testing Helper

/// Helper function to run a property test synchronously from synchronous contexts.
///
/// **Important**: This function is provided for compatibility with synchronous test contexts
/// like performance benchmarks. For new code, prefer async/await patterns with `PropertyRunner`.
///
/// This creates a new runner, seeds it, and executes the property test synchronously.
/// The result is guaranteed to be deterministic if a seed is provided.
///
/// - Parameters:
///   - property: The property to test
///   - config: Configuration for the test execution
///
/// - Returns: The result of running the property (success, failure, or gave up)
///
/// - Example:
///   ```swift
///   let property = Property(generator: Gen.int) { $0 >= 0 }
///   let result = runPropertySynchronously(property, config: PropertyConfig(iterations: 100))
///   ```
///
/// - See Also: ``PropertyRunner.runProperty(_:config:)`` for async variant
public func runPropertySynchronously<T>(
  _ property: Property<T>,
  config: PropertyConfig = .default
) -> PropertyResult<T> {
  let actualSeed = config.seed ?? Seed.random
  var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: actualSeed)

  for iteration in 0..<config.iterations {
    let size = Size(value: min(iteration, 100))
    let testCase = property.generator.generate(&rng, size)

    if !property.predicate(testCase) {
      let shrunkCase = shrinkFailureSynchronously(
        testCase,
        property: property,
        maxShrinks: config.maxShrinks
      )
      return .failure(
        counterexample: testCase,
        iterations: iteration + 1,
        shrunk: shrunkCase,
        reason: .predicateFailed,
        seed: actualSeed
      )
    }
  }

  return .success(iterations: config.iterations)
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func runPropertyAsync<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig = .default
) async -> PropertyResult<T> {
  let runner = PropertyRunner(seed: config.seed)
  return await runner.runProperty(property, config: config)
}

private func shrinkFailureSynchronously<T>(
  _ failingCase: T,
  property: Property<T>,
  maxShrinks: Int
) -> T {
  var current = failingCase
  var shrinkAttempts = 0

  while shrinkAttempts < maxShrinks {
    let candidates = property.generator.shrink.shrink(current)

    let nextFailure = candidates.first { candidate in
      !property.predicate(candidate)
    }

    if let nextFailure = nextFailure {
      current = nextFailure
      shrinkAttempts += 1
    } else {
      break
    }
  }

  return current
}

// MARK: - Coverage-Guided Property Testing Extensions

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PropertyRunner {
  /// Run property with coverage guidance
  public func runPropertyWithCoverageGuidance<T>(
    _ property: Property<T>,
    collector: CoverageCollector,
    config: PropertyConfig = .default,
    coverageConfig: CoverageConfig = .default,
    coverageStrategy: CoverageStrategy = .frequency
  ) async -> (PropertyResult<T>, CoverageReport) {

    // Phase 1: Baseline execution to establish initial coverage
    let baselineIterations = min(20, config.iterations / 5)
    let baselineResult = self.runProperty(
      property,
      config: PropertyConfig(
        iterations: baselineIterations,
        maxShrinks: config.maxShrinks,
        maxDiscarded: config.maxDiscarded,
        seed: config.seed
      )
    )

    // Record baseline execution
    let baselineCoverage = await collector.currentBudget()
    let initialCoverage = baselineCoverage.coveragePercentage

    // Phase 2: Coverage-guided execution
    let remainingIterations = config.iterations - baselineIterations
    var finalResult = baselineResult

    if remainingIterations > 0 && !baselineResult.isFailure {
      let currentBudget = await collector.currentBudget()
      let guidedProperty = property.withCoverageGuidance(
        budget: currentBudget,
        strategy: coverageStrategy,
        config: coverageConfig
      )

      let guidedResult = self.runProperty(
        guidedProperty,
        config: PropertyConfig(
          iterations: remainingIterations,
          maxShrinks: config.maxShrinks,
          maxDiscarded: config.maxDiscarded,
          seed: config.seed
        )
      )

      // Use the guided result if baseline succeeded
      if case .success = baselineResult {
        finalResult = guidedResult
      }
    }

    // Generate coverage report
    let finalBudget = await collector.currentBudget()
    let finalCoverage = finalBudget.coveragePercentage
    let report = CoverageReport(
      initialCoverage: initialCoverage,
      finalCoverage: finalCoverage,
      improvement: finalCoverage - initialCoverage,
      executionCount: config.iterations,
      uncoveredSymbols: Array(finalBudget.uncoveredSymbols).sorted()
    )

    return (finalResult, report)
  }

  /// Run property with automatic coverage tracking
  public func runPropertyWithCoverageTracking<T>(
    _ property: Property<T>,
    knownSymbols: Set<String> = [],
    config: PropertyConfig = .default,
    coverageConfig: CoverageConfig = .default
  ) async -> (PropertyResult<T>, CoverageReport) {

    let collector = CoverageCollector(config: coverageConfig)

    // Add known symbols if provided
    if !knownSymbols.isEmpty {
      await collector.addKnownSymbols(knownSymbols)
    }

    return await runPropertyWithCoverageGuidance(
      property,
      collector: collector,
      config: config,
      coverageConfig: coverageConfig
    )
  }
}

extension PropertyResult {
  /// Check if the property result represents a failure
  public var isFailure: Bool {
    switch self {
    case .failure:
      return true

    case .success, .gaveUp:
      return false
    }
  }

  /// Check if the property result represents success
  public var isSuccess: Bool {
    switch self {
    case .success:
      return true

    case .failure, .gaveUp:
      return false
    }
  }

  /// Check if the property result represents giving up due to too many discards
  public var isGaveUp: Bool {
    switch self {
    case .gaveUp:
      return true

    case .success, .failure:
      return false
    }
  }

  /// Extract the iteration count from any result case.
  ///
  /// - Returns: Number of iterations that were executed
  public var iterationCount: Int {
    switch self {
    case .success(let iterations):
      return iterations

    case .failure(_, let iterations, _, _, _):
      return iterations

    case .gaveUp(_, let iterations):
      return iterations
    }
  }

  /// Convert result to CLI exit code.
  ///
  /// - Returns: 0 for success, 1 for failure, 2 for gave up
  public func toExitCode() -> Int32 {
    switch self {
    case .success:
      return 0

    case .failure:
      return 1

    case .gaveUp:
      return 2
    }
  }

  /// Short one-line description suitable for logs.
  public var shortDescription: String {
    switch self {
    case .success(let iterations):
      return "PASS (\(iterations) iterations)"

    case .failure:
      return "FAIL"

    case .gaveUp(let discarded, _):
      return "GAVE_UP (\(discarded) discarded)"
    }
  }
}

extension PropertyResult: CustomStringConvertible {
  /// Human-readable description of the property result.
  public var description: String {
    switch self {
    case .success(let iterations):
      return "✓ Passed \(iterations) tests"

    case .failure(_, let iterations, let shrunk, let reason, let seed):
      return """
        ✗ Failed after \(iterations) tests: \(reason)
          Minimal counterexample: \(shrunk)
          Reproduce with seed: \(seed.rawValue)
        """

    case .gaveUp(let discarded, let iterations):
      return "? Gave up after \(iterations) tests (\(discarded) inputs discarded)"
    }
  }
}

// MARK: - Reproduction String

/// A deterministic reproduction string for property test failures.
///
/// `ReproString` encapsulates all information needed to reproduce a failing property test:
/// - The seed used for random generation
/// - The iteration count where failure occurred
/// - The configuration used (iterations, maxShrinks)
/// - The minimal counterexample (shrunk value)
/// - The failure reason
///
/// The string format is designed to be copy-pasteable from test output into code or CLI.
///
/// - Example:
///   ```swift
///   // From test output:
///   // REPRO:seed=12345678,iter=42,shrunk="[1, 2]",reason=predicateFailed
///
///   // Parse and re-run:
///   let repro = ReproString.parse("REPRO:seed=12345678,iter=42,shrunk=\"[1, 2]\",reason=predicateFailed")
///   ```
public struct ReproString: Sendable, Equatable, CustomStringConvertible {
  public let seed: UInt64
  public let iteration: Int
  public let shrunkDescription: String
  public let reason: FailureReason

  public init(seed: UInt64, iteration: Int, shrunkDescription: String, reason: FailureReason) {
    self.seed = seed
    self.iteration = iteration
    self.shrunkDescription = shrunkDescription
    self.reason = reason
  }

  public var description: String {
    let reasonStr: String
    switch reason {
    case .predicateFailed:
      reasonStr = "predicateFailed"

    case .threwError(let error):
      reasonStr = "threwError(\(error))"

    case .timedOut(let seconds):
      reasonStr = "timedOut(\(seconds)s)"
    }
    return
      "REPRO:seed=\(seed),iter=\(iteration),shrunk=\"\(shrunkDescription)\",reason=\(reasonStr)"
  }

  /// Parses a reproduction string back into its components.
  ///
  /// Format: `REPRO:seed=<uint64>,iter=<int>,shrunk="<description>",reason=<reason>`
  ///
  /// - Parameter string: The reproduction string to parse
  /// - Returns: A `ReproString` if parsing succeeds, nil otherwise
  public static func parse(_ string: String) -> Self? {
    guard string.hasPrefix("REPRO:") else { return nil }

    let content = String(string.dropFirst(6))
    let parts = splitQuoteAware(content)

    var seed: UInt64?
    var iteration: Int?
    var shrunk: String?
    var reason: FailureReason = .predicateFailed

    for part in parts {
      let trimmed = part.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("seed=") {
        seed = UInt64(String(trimmed.dropFirst(5)))
      } else if trimmed.hasPrefix("iter=") {
        iteration = Int(String(trimmed.dropFirst(5)))
      } else if trimmed.hasPrefix("shrunk=\"") {
        shrunk = parseShrunkValue(trimmed)
      } else if trimmed.hasPrefix("reason=") {
        reason = parseReason(String(trimmed.dropFirst(7)))
      }
    }

    guard let parsedSeed = seed, let parsedIteration = iteration, let parsedShrunk = shrunk else {
      return nil
    }

    return Self(
      seed: parsedSeed,
      iteration: parsedIteration,
      shrunkDescription: parsedShrunk,
      reason: reason
    )
  }

  private static func splitQuoteAware(_ content: String) -> [String] {
    var parts: [String] = []
    var current = ""
    var inQuotes = false

    for char in content {
      if char == "\"" {
        inQuotes.toggle()
        current.append(char)
      } else if char == "," && !inQuotes {
        parts.append(current)
        current = ""
      } else {
        current.append(char)
      }
    }
    if !current.isEmpty {
      parts.append(current)
    }
    return parts
  }

  private static func parseShrunkValue(_ trimmed: String) -> String? {
    if trimmed == "shrunk=\"\"" {
      return ""
    }
    let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 8)
    guard let endQuote = trimmed.lastIndex(of: "\""), endQuote > startIndex else {
      return nil
    }
    return String(trimmed[startIndex..<endQuote])
  }

  private static func parseReason(_ reasonStr: String) -> FailureReason {
    if reasonStr == "predicateFailed" {
      return .predicateFailed
    }
    if reasonStr.hasPrefix("threwError("), let errorEnd = reasonStr.lastIndex(of: ")") {
      let errorStart = reasonStr.index(reasonStr.startIndex, offsetBy: 11)
      return .threwError(String(reasonStr[errorStart..<errorEnd]))
    }
    if reasonStr.hasPrefix("timedOut("), let timeEnd = reasonStr.lastIndex(of: "s") {
      let timeStart = reasonStr.index(reasonStr.startIndex, offsetBy: 9)
      if let seconds = Double(String(reasonStr[timeStart..<timeEnd])) {
        return .timedOut(seconds: seconds)
      }
    }
    return .predicateFailed
  }
}

extension PropertyResult {
  /// Generates a deterministic reproduction string for failures.
  ///
  /// Returns nil for success or gaveUp results. For failures, returns a
  /// `ReproString` that can be used to reproduce the exact failure.
  public var reproString: ReproString? {
    switch self {
    case .success, .gaveUp:
      return nil

    case .failure(_, let iterations, let shrunk, let reason, let seed):
      return ReproString(
        seed: seed.rawValue,
        iteration: iterations,
        shrunkDescription: "\(shrunk)",
        reason: reason
      )
    }
  }
  // swiftlint:disable:next file_length
}
