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

// MARK: - Property Evaluation (S012)

/// Outcome of evaluating a single property test case.
///
/// `PropertyEvaluation` enables explicit assumptions inside property bodies,
/// providing proper discard tracking without relying on generator filtering.
///
/// - Cases:
///   - `.pass`: The property holds for this input
///   - `.fail(reason:)`: The property failed with optional explanation
///   - `.discard(reason:)`: The input should be discarded (assumption violated)
///
/// - Example:
///   ```swift
///   let property = Property(generator: Gen.int) { n -> PropertyEvaluation in
///       guard n > 0 else { return .discard(reason: "need positive") }
///       guard n.isMultiple(of: 2) else { return .discard(reason: "need even") }
///       return n * 2 > n ? .pass : .fail(reason: "doubling should increase")
///   }
///   ```
///
/// - See Also: ``assume(_:reason:)``, ``Property``
public enum PropertyEvaluation: Sendable, Equatable {
  /// The property holds for this input.
  case pass

  /// The property failed for this input.
  ///
  /// - Parameter reason: Optional explanation of why it failed
  case fail(reason: String?)

  /// The input should be discarded (assumption violated).
  ///
  /// Discarded inputs are not counted as failures. The runner tracks discards
  /// and returns `.gaveUp` if too many inputs are discarded.
  ///
  /// - Parameter reason: Optional explanation of why it was discarded
  case discard(reason: String?)
}

/// Express an assumption inside a property body.
///
/// If the condition is false, the current test case is discarded (not failed).
/// This enables filtering at the property level with proper discard tracking,
/// avoiding the problems with generator-level filtering (`Gen.suchThat`).
///
/// - Parameters:
///   - condition: If false, the test case is discarded
///   - reason: Optional explanation for debug output
///
/// - Returns: `.pass` if condition is true, `.discard` if false
///
/// - Example:
///   ```swift
///   let property = Property(generator: Gen.int) { n -> PropertyEvaluation in
///       try assume(n > 0, reason: "need positive number")
///       try assume(n < 100, reason: "need small number")
///       return n * 2 > n ? .pass : .fail(reason: nil)
///   }
///   ```
///
/// - See Also: ``PropertyEvaluation``
public func assume(_ condition: Bool, reason: String? = nil) -> PropertyEvaluation {
  condition ? .pass : .discard(reason: reason)
}

/// Express a requirement that must hold or the property fails.
///
/// Unlike `assume()`, if the condition is false, the property *fails* (not discards).
/// Use this for postconditions and invariants that should always hold.
///
/// - Parameters:
///   - condition: If false, the property fails
///   - reason: Optional explanation for debug output
///
/// - Returns: `.pass` if condition is true, `.fail` if false
public func require(_ condition: Bool, reason: String? = nil) -> PropertyEvaluation {
  condition ? .pass : .fail(reason: reason)
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

  // swiftlint:disable:next orphaned_doc_comment
  /// Property failed on a generated input.
  ///
  /// - Parameters:
  ///   - counterexample: The original failing input as generated
  ///   - iterations: Number of iterations before failure
  ///   - shrunk: The minimized failing input (typically simpler than counterexample)
  ///   - reason: Classification of how the property failed
  ///   - seed: The seed used for this test run (for reproduction)
  // swiftlint:disable:next enum_case_associated_values_count
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
public struct Property<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The assumption (precondition) that filters valid test cases.
  ///
  /// Assumptions are used to filter the input space. If a generated value
  /// doesn't satisfy the assumption, it is discarded and another value is tried.
  public let assumption: @Sendable (T) -> Bool
  /// The predicate that must hold true for all valid test cases.
  public let predicate: @Sendable (T) -> Bool

  /// Initialize a property with a generator and predicate.
  ///
  /// - Parameters:
  ///   - generator: Values to test
  ///   - assumption: Filter for valid values (default: all valid)
  ///   - predicate: Condition that must hold true
  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T) -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Throwing Property

/// A property that can throw errors during execution.
///
/// If the predicate throws, it's considered a failure unless it's a known
/// discard signal.
public struct ThrowingProperty<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The assumption (precondition) that filters valid test cases.
  public let assumption: @Sendable (T) -> Bool
  /// The predicate that must hold true (or not throw).
  public let predicate: @Sendable (T) throws -> Bool

  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T) throws -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Evaluating Property

/// A property that returns explicit evaluation results.
///
/// Useful for complex properties that need to signal success, failure,
/// or discard with detailed reasons.
public struct EvaluatingProperty<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The predicate returning explicit evaluation outcomes.
  public let evaluate: @Sendable (T) -> PropertyEvaluation

  public init(
    generator: Gen<T>,
    evaluate: @escaping @Sendable (T) -> PropertyEvaluation
  ) {
    self.generator = generator
    self.evaluate = evaluate
  }
}

// MARK: - Async Property

/// A property with an async predicate.
///
/// Supports properties that require asynchronous operations during evaluation,
/// such as network calls, database queries, or concurrent computations.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct AsyncProperty<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The assumption (precondition) that filters valid test cases.
  public let assumption: @Sendable (T) -> Bool
  /// The async predicate that must hold true for all valid test cases.
  public let predicate: @Sendable (T) async -> Bool

  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T) async -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Async Throwing Property

/// A property with an async predicate that can throw errors.
///
/// Combines async operations with error handling. Thrown errors are captured
/// and reported as failures with `.threwError` reason.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct AsyncThrowingProperty<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The assumption (precondition) that filters valid test cases.
  public let assumption: @Sendable (T) -> Bool
  /// The async predicate that must hold true (or not throw).
  public let predicate: @Sendable (T) async throws -> Bool

  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T) async throws -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

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

  /// Opt-in regression bank for storing and replaying minimal counterexamples.
  ///
  /// When enabled, failed test cases are persisted to the regression bank
  /// and replayed on subsequent runs before random exploration.
  public let regressionBank: RegressionBank?

  /// Unique identifier for this property, used for regression storage.
  ///
  /// Required when using regression bank. Should be stable across runs.
  public let propertyId: String?

  /// Unicode handling mode for string shrinking.
  ///
  /// Controls how Unicode characters are handled during string shrinking:
  /// - `.scalarSafe`: Use Swift String indices (default, safe for all Unicode)
  /// - `.asciiOnly`: Restrict to ASCII characters for deterministic behavior
  ///
  /// ASCII-only mode provides more predictable shrinking but may miss
  /// Unicode-specific counterexamples.
  public let unicodeMode: UnicodeMode

  /// Maximum steps for string shrinking to prevent infinite loops.
  ///
  /// String shrinking can explore many candidates. This bounds the search
  /// space to ensure termination. Higher values find smaller counterexamples
  /// but take longer.
  ///
  /// Typical ranges:
  /// - 100-500: Fast shrinking with good results
  /// - 1000+: Thorough shrinking (may be slow for long strings)
  public let maxStringShrinkSteps: Int

  /// Unicode handling modes for string operations.
  public enum UnicodeMode: Sendable {
    /// Use Swift String indices (safe for all Unicode text).
    case scalarSafe
    /// Restrict to ASCII characters for deterministic behavior.
    case asciiOnly
  }

  // MARK: - Coverage Configuration

  /// Configuration options for coverage tracking during property tests.
  ///
  /// Controls how coverage thresholds are enforced and what happens when
  /// they are not met.
  ///
  /// - Example:
  ///   ```swift
  ///   var config = PropertyConfig.default
  ///   config.coverage.enforceCoverage = true  // Fail on unmet thresholds
  ///   config.coverage.warnOnLowCoverage = true  // Also warn on close misses
  ///   config.coverage.maxLabels = 500  // Limit memory usage
  ///   ```
  public struct CoverageConfig: Sendable, Equatable {

    /// Whether to fail the test when coverage thresholds are unmet.
    ///
    /// When `true`, the property test fails if any `.cover()` requirement
    /// is not satisfied after all iterations complete.
    ///
    /// Default: `true` (strict enforcement)
    public var enforceCoverage: Bool

    /// Whether to emit a warning when coverage is below threshold.
    ///
    /// When `true`, logs a warning for each unmet threshold even if
    /// `enforceCoverage` is false (the test still passes).
    ///
    /// Default: `true`
    public var warnOnLowCoverage: Bool

    /// Maximum number of unique labels to track per category.
    ///
    /// Prevents unbounded memory growth when `.collect()` is used
    /// with high-cardinality values. Labels beyond this limit are
    /// dropped with a warning.
    ///
    /// Default: `1000`
    public var maxLabels: Int

    /// Default coverage configuration.
    public static let `default` = Self(
      enforceCoverage: true,
      warnOnLowCoverage: true,
      maxLabels: 1000
    )

    /// Lenient configuration that warns but doesn't fail.
    public static let lenient = Self(
      enforceCoverage: false,
      warnOnLowCoverage: true,
      maxLabels: 1000
    )

    public init(
      enforceCoverage: Bool = true,
      warnOnLowCoverage: Bool = true,
      maxLabels: Int = 1000
    ) {
      self.enforceCoverage = enforceCoverage
      self.warnOnLowCoverage = warnOnLowCoverage
      self.maxLabels = maxLabels
    }
  }

  // MARK: - Discard Configuration

  /// Configuration for discard ratio tracking and enforcement.
  ///
  /// Controls when warnings are emitted and when tests fail due to excessive discards.
  /// A high discard ratio indicates the generator produces many invalid inputs,
  /// suggesting it should be redesigned.
  ///
  /// - Example:
  ///   ```swift
  ///   var config = PropertyConfig.default
  ///   config.discard.warnRatio = 3.0   // Warn if >3 discards per success
  ///   config.discard.failRatio = 5.0   // Fail if >5 discards per success
  ///   ```
  public struct DiscardConfig: Sendable, Equatable {
    /// Discard ratio above which a warning is emitted.
    ///
    /// Ratio = discards / successful iterations.
    /// Default: 5.0 (warn if more than 5 discards per successful test)
    public var warnRatio: Double

    /// Discard ratio above which the test fails.
    ///
    /// Default: 10.0 (fail if more than 10 discards per successful test)
    public var failRatio: Double

    /// Enable or disable discard ratio enforcement.
    ///
    /// When disabled, only `maxDiscarded` absolute limit is enforced.
    /// Default: true
    public var enforceRatio: Bool

    /// Default configuration: warn at 5x, fail at 10x.
    public static let `default` = Self(warnRatio: 5.0, failRatio: 10.0, enforceRatio: true)

    /// Lenient configuration: warn at 10x, fail at 50x.
    public static let lenient = Self(warnRatio: 10.0, failRatio: 50.0, enforceRatio: true)

    /// Disabled configuration: no ratio enforcement.
    public static let disabled = Self(
      warnRatio: .infinity,
      failRatio: .infinity,
      enforceRatio: false
    )

    public init(warnRatio: Double = 5.0, failRatio: Double = 10.0, enforceRatio: Bool = true) {
      self.warnRatio = warnRatio
      self.failRatio = failRatio
      self.enforceRatio = enforceRatio
    }
  }

  /// Coverage tracking configuration.
  public var coverage: CoverageConfig

  /// Discard ratio tracking configuration.
  ///
  /// Controls warnings and failures for excessive discards.
  public var discard: DiscardConfig

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
  ///   - regressionBank: Optional regression bank for persisting failures. Default: nil.
  ///   - propertyId: Unique identifier for regression storage. Default: nil.
  ///   - unicodeMode: Unicode handling mode for strings. Default: .scalarSafe.
  ///   - maxStringShrinkSteps: Maximum steps for string shrinking. Default: 500.
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig(
  ///       iterations: 500,
  ///       maxShrinks: 2000,
  ///       maxDiscarded: 500,
  ///       seed: Seed(value: 42),
  ///       timeout: 5.0,
  ///       verbosity: .verbose,
  ///       regressionBank: RegressionBank(),
  ///       propertyId: "testArrayReverse",
  ///       unicodeMode: .asciiOnly,
  ///       maxStringShrinkSteps: 1000
  ///   )
  ///   ```
  public init(
    iterations: Int = 100,
    maxShrinks: Int = 1000,
    maxDiscarded: Int = 1000,
    seed: Seed? = nil,
    verbose: Bool = false,
    timeout: TimeInterval? = nil,
    verbosity: Verbosity = .normal,
    regressionBank: RegressionBank? = nil,
    propertyId: String? = nil,
    unicodeMode: UnicodeMode = .scalarSafe,
    maxStringShrinkSteps: Int = 500,
    coverage: CoverageConfig = .default,
    discard: DiscardConfig = .default
  ) {
    self.iterations = max(1, iterations)
    self.maxShrinks = max(0, maxShrinks)
    self.maxDiscarded = max(0, maxDiscarded)
    self.seed = seed
    self.verbose = verbose
    self.timeout = timeout
    self.verbosity = verbosity
    self.regressionBank = regressionBank
    self.propertyId = propertyId
    self.unicodeMode = unicodeMode
    self.maxStringShrinkSteps = max(1, maxStringShrinkSteps)
    self.coverage = coverage
    self.discard = discard
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
// swiftlint:disable:next type_body_length
public actor PropertyRunner {
  private var rng: any RandomNumberGenerator
  /// Internal seed for extensions to access during property execution.
  let seed: Seed

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
    if let bank = config.regressionBank, let propertyId = config.propertyId {
      let semaphore = DispatchSemaphore(value: 0)
      var result: PropertyResult<T>!
      Task {
        result = await runPropertyWithRegressions(
          property,
          config: config,
          bank: bank,
          propertyId: propertyId
        )
        semaphore.signal()
      }
      semaphore.wait()
      return result
    }
    return runPropertyCore(property, config: config)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  private func runPropertyWithRegressions<T>(
    _ property: Property<T>,
    config: PropertyConfig,
    bank: RegressionBank,
    propertyId: String
  ) async -> PropertyResult<T> {
    let seedsToReplay = await bank.seedsForProperty(propertyId)

    for regressionSeed in seedsToReplay {
      let regressionRunner = PropertyRunner(seed: regressionSeed)
      let regressionResult = await regressionRunner.runProperty(property, config: config)

      switch regressionResult {
      case .failure:
        return regressionResult

      case .success, .gaveUp:
        continue
      }
    }

    let result = runPropertyCore(property, config: config)

    if case .failure(_, _, let shrunk, let reason, let seed) = result {
      let iteration = 0
      let counterexampleStr = String(describing: shrunk)
      let entry = FailureEntry(
        propertyLabel: propertyId,
        seedValue: seed.rawValue,
        counterexampleDescription: counterexampleStr,
        failureReason: reason.description,
        failedAtIteration: iteration
      )
      try? await bank.recordFailureEntry(entry)
    }

    return result
  }

  private func runPropertyCore<T>(
    _ property: Property<T>,
    config: PropertyConfig
  ) -> PropertyResult<T> {
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      // Generate tree for proper shrinking (essential for flatMap)
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      // Check assumption first - discarded values never reach the predicate
      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }
        continue
      }

      // Assumption passed, check the predicate
      if !property.predicate(testCase) {
        // Property failed - begin shrinking using the pre-built tree
        let shrunkCase = shrinkFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .predicateFailed,
          seed: seed
        )
      }

      successfulIterations += 1
    }

    // Check discard ratio before returning success
    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      // Log warning but continue with success
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }

    case .fail:
      // Return gaveUp since test couldn't be adequately tested
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }

  /// Run a throwing property test and return the result.
  ///
  /// Similar to `runProperty`, but supports predicates that may throw errors.
  /// Thrown errors are caught and classified as `.threwError` failures.
  ///
  /// - Parameters:
  ///   - property: The throwing property to test
  ///   - config: Configuration for test execution
  ///
  /// - Returns: The result of running the property
  public func runThrowingProperty<T>(
    _ property: ThrowingProperty<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      // Generate tree for proper shrinking (essential for flatMap)
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      // Check assumption first
      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }
        continue
      }

      // Assumption passed, check the predicate
      do {
        if try !property.predicate(testCase) {
          // Predicate returned false - use tree-based shrinking
          let shrunkCase = shrinkThrowingFailureWithTree(
            tree,
            property: property,
            maxShrinks: config.maxShrinks
          )
          return .failure(
            counterexample: testCase,
            iterations: successfulIterations + 1,
            shrunk: shrunkCase,
            reason: .predicateFailed,
            seed: seed
          )
        }
      } catch {
        // Predicate threw an error - use tree-based shrinking
        let errorDescription = String(describing: error)
        let shrunkCase = shrinkThrowingFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .threwError(errorDescription),
          seed: seed
        )
      }

      successfulIterations += 1
    }

    // Check discard ratio before returning success
    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }

  // MARK: - Evaluating Property Runner (S012)

  /// Run an evaluating property test and return the result.
  ///
  /// Supports properties with explicit `PropertyEvaluation` outcomes, enabling
  /// assumptions and failures to be expressed directly in the property body.
  ///
  /// - Parameters:
  ///   - property: The evaluating property to test
  ///   - config: Configuration for test execution
  ///
  /// - Returns: The result of running the property
  ///
  /// - Example:
  ///   ```swift
  ///   let property = EvaluatingProperty(generator: Gen.int) { n in
  ///       guard n > 0 else { return .discard(reason: "need positive") }
  ///       return n * 2 > n ? .pass : .fail(reason: "doubling should increase")
  ///   }
  ///   let result = runner.runEvaluatingProperty(property)
  ///   ```
  public func runEvaluatingProperty<T>(
    _ property: EvaluatingProperty<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      // Generate tree for proper shrinking (essential for flatMap)
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      // Evaluate the property - may return pass, fail, or discard
      let evaluation = property.evaluate(testCase)

      switch evaluation {
      case .pass:
        successfulIterations += 1

      case .discard:
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }

      case .fail(let reason):
        // Shrink the failing case using tree-based shrinking
        let shrunkCase = shrinkEvaluatingFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        let failureReason: FailureReason = reason.map { .threwError($0) } ?? .predicateFailed
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: failureReason,
          seed: seed
        )
      }
    }

    // Check discard ratio before returning success
    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }

  /// Shrink a failing test case for an evaluating property using BFS.
  private func shrinkEvaluatingFailure<T>(
    _ failingCase: T,
    property: EvaluatingProperty<T>,
    maxShrinks: Int
  ) -> T {
    let tree = ShrinkTree.from(failingCase, shrink: property.generator.shrink)
    return shrinkEvaluatingFailureWithTree(tree, property: property, maxShrinks: maxShrinks)
  }

  /// Shrink an evaluating property failure using a pre-built shrink tree.
  ///
  /// This version uses the tree generated during test execution, enabling
  /// proper shrinking for dependent generators created via flatMap.
  private func shrinkEvaluatingFailureWithTree<T>(
    _ tree: ShrinkTree<T>,
    property: EvaluatingProperty<T>,
    maxShrinks: Int
  ) -> T {
    // Filter to only values that don't discard
    let filteredTree = tree.filter { candidate in
      if case .discard = property.evaluate(candidate) {
        return false
      }
      return true
    }

    // Find minimal case that still fails
    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      if case .fail = property.evaluate(candidate) {
        return true
      }
      return false
    }

    return minimal ?? tree.value
  }

  /// Shrink a failing test case for a throwing property using BFS.
  private func shrinkThrowingFailure<T>(
    _ failingCase: T,
    property: ThrowingProperty<T>,
    failureReason: FailureReason,
    maxShrinks: Int
  ) -> T {
    // Build shrink tree from the failing case
    let tree = ShrinkTree.from(failingCase, shrink: property.generator.shrink)

    // Filter tree to respect assumptions
    let filteredTree = tree.filter { property.assumption($0) }

    // BFS search for minimal counterexample that still fails (returns false or throws)
    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      do {
        return try !property.predicate(candidate)
      } catch {
        return true  // Throws = still fails
      }
    }

    return minimal ?? failingCase
  }

  /// Shrink a failing test case to find the minimal counterexample using BFS.
  ///
  /// Uses breadth-first search on the shrink tree to find smaller counterexamples.
  /// BFS typically finds better (more minimal) counterexamples than greedy-first.
  private func shrinkFailure<T: Sendable>(
    _ failingCase: T,
    property: Property<T>,
    maxShrinks: Int
  ) -> T {
    // Build shrink tree from the failing case
    let tree = ShrinkTree.from(failingCase, shrink: property.generator.shrink)

    // Filter tree to respect assumptions, then search for minimal failing case
    let filteredTree = tree.filter { property.assumption($0) }

    // BFS search for minimal counterexample that still fails the predicate
    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      !property.predicate(candidate)
    }

    return minimal ?? failingCase
  }

  /// Shrink using a pre-built shrink tree (essential for flatMap dependent shrinking).
  ///
  /// This version uses the tree generated during test execution, which includes
  /// proper shrinking for dependent generators created via flatMap.
  private func shrinkFailureWithTree<T: Sendable>(
    _ tree: ShrinkTree<T>,
    property: Property<T>,
    maxShrinks: Int
  ) -> T {
    // Filter tree to respect assumptions
    let filteredTree = tree.filter { property.assumption($0) }

    // BFS search for minimal counterexample that still fails the predicate
    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      !property.predicate(candidate)
    }

    return minimal ?? tree.value
  }

  /// Shrink a throwing property failure using a pre-built shrink tree.
  ///
  /// This version uses the tree generated during test execution, enabling
  /// proper shrinking for dependent generators created via flatMap.
  private func shrinkThrowingFailureWithTree<T: Sendable>(
    _ tree: ShrinkTree<T>,
    property: ThrowingProperty<T>,
    maxShrinks: Int
  ) -> T {
    // Filter tree to respect assumptions
    let filteredTree = tree.filter { property.assumption($0) }

    // BFS search for minimal counterexample that still fails (returns false or throws)
    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      do {
        return try !property.predicate(candidate)
      } catch {
        return true  // Throws = still fails
      }
    }

    return minimal ?? tree.value
  }

  // MARK: - Timeout-Enforced Property Testing

  /// Run a property test with per-iteration timeout enforcement.
  ///
  /// Similar to `runProperty`, but enforces a timeout for each predicate evaluation.
  /// If any iteration exceeds the configured timeout, the test fails with
  /// `FailureReason.timedOut`.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - config: Configuration including timeout. If `config.timeout` is nil, uses 30.0s default.
  ///
  /// - Returns: The result of running the property, including `.timedOut` if timeout exceeded
  ///
  /// - Example:
  ///   ```swift
  ///   let property = Property<Int>(generator: Gen.int) { n in
  ///     // Some potentially slow computation
  ///     expensiveCheck(n)
  ///   }
  ///
  ///   let result = await runner.runPropertyWithTimeout(
  ///     property,
  ///     config: PropertyConfig(timeout: 1.0)
  ///   )
  ///   ```
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  public func runPropertyWithTimeout<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) async -> PropertyResult<T> {
    let timeout = config.timeout ?? 30.0
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      // Generate tree for proper shrinking (essential for flatMap)
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      // Check assumption first - discarded values never reach the predicate
      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }
        continue
      }

      // Run predicate with timeout using deadline check
      let startTime = CFAbsoluteTimeGetCurrent()
      let passed = property.predicate(testCase)
      let elapsed = CFAbsoluteTimeGetCurrent() - startTime

      if elapsed > timeout {
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: testCase,  // No shrinking for timeout
          reason: .timedOut(seconds: timeout),
          seed: seed
        )
      }

      if !passed {
        // Property failed - use tree-based shrinking
        let shrunkCase = shrinkFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .predicateFailed,
          seed: seed
        )
      }

      successfulIterations += 1
    }

    // Check discard ratio before returning success
    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  public func runAsyncProperty<T>(
    _ property: AsyncProperty<T>,
    config: PropertyConfig = .default
  ) async -> PropertyResult<T> {
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }
        continue
      }

      if await !property.predicate(testCase) {
        let shrunkCase = await shrinkAsyncFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .predicateFailed,
          seed: seed
        )
      }

      successfulIterations += 1
    }

    // Check discard ratio before returning success
    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  public func runAsyncThrowingProperty<T>(
    _ property: AsyncThrowingProperty<T>,
    config: PropertyConfig = .default
  ) async -> PropertyResult<T> {
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }
        continue
      }

      do {
        if try await !property.predicate(testCase) {
          let shrunkCase = await shrinkAsyncThrowingFailureWithTree(
            tree,
            property: property,
            maxShrinks: config.maxShrinks
          )
          return .failure(
            counterexample: testCase,
            iterations: successfulIterations + 1,
            shrunk: shrunkCase,
            reason: .predicateFailed,
            seed: seed
          )
        }
      } catch {
        let errorDescription = String(describing: error)
        let shrunkCase = await shrinkAsyncThrowingFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .threwError(errorDescription),
          seed: seed
        )
      }

      successfulIterations += 1
    }

    // Check discard ratio before returning success
    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  private func shrinkAsyncFailureWithTree<T: Sendable>(
    _ tree: ShrinkTree<T>,
    property: AsyncProperty<T>,
    maxShrinks: Int
  ) async -> T {
    let filteredTree = tree.filter { property.assumption($0) }

    let minimal = await filteredTree.findMinimalAsync(budget: maxShrinks) { candidate in
      await !property.predicate(candidate)
    }

    return minimal ?? tree.value
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  private func shrinkAsyncThrowingFailureWithTree<T: Sendable>(
    _ tree: ShrinkTree<T>,
    property: AsyncThrowingProperty<T>,
    maxShrinks: Int
  ) async -> T {
    let filteredTree = tree.filter { property.assumption($0) }

    let minimal = await filteredTree.findMinimalAsync(budget: maxShrinks) { candidate in
      do {
        return try await !property.predicate(candidate)
      } catch {
        return true
      }
    }

    return minimal ?? tree.value
  }

  // MARK: - Replay from Token

  /// Runs a property using a replay token to reproduce a previous failure.
  ///
  /// This enables deterministic reproduction of test failures by re-running
  /// with the exact seed and configuration captured in the token.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - token: The replay token from a previous failure
  ///
  /// - Returns: Result of running the property with the token's configuration
  ///
  /// - Example:
  ///   ```swift
  ///   // Parse a previously captured token
  ///   let token = ReplayToken.parse("eyJzZWVkIjo0Mn0")!
  ///
  ///   // Replay the failure
  ///   let result = await PropertyRunner.runFromToken(property, token: token)
  ///   ```
  public static func runFromToken<T>(
    _ property: Property<T>,
    token: ReplayToken
  ) async -> PropertyResult<T> {
    let config = token.toConfig()
    let runner = PropertyRunner(seed: Seed(value: token.seed))
    return await runner.runProperty(property, config: config)
  }

  /// Runs a throwing property using a replay token.
  ///
  /// - Parameters:
  ///   - property: The throwing property to test
  ///   - token: The replay token from a previous failure
  ///
  /// - Returns: Result of running the property with the token's configuration
  public static func runFromToken<T>(
    _ property: ThrowingProperty<T>,
    token: ReplayToken
  ) async -> PropertyResult<T> {
    let config = token.toConfig()
    let runner = PropertyRunner(seed: Seed(value: token.seed))
    return await runner.runThrowingProperty(property, config: config)
  }

  /// Runs an evaluating property using a replay token.
  ///
  /// - Parameters:
  ///   - property: The evaluating property to test
  ///   - token: The replay token from a previous failure
  ///
  /// - Returns: Result of running the property with the token's configuration
  public static func runFromToken<T>(
    _ property: EvaluatingProperty<T>,
    token: ReplayToken
  ) async -> PropertyResult<T> {
    let config = token.toConfig()
    let runner = PropertyRunner(seed: Seed(value: token.seed))
    return await runner.runEvaluatingProperty(property, config: config)
  }
}

/// Result of running a predicate with timeout.
private enum PredicateTimeoutResult {
  case success(Bool)
  case timedOut
}

/// Internal result type for predicate/timeout race.
private enum PredicateRaceResult {
  case predicateFinished(Bool)
  case timeoutReached
}

// MARK: - Convenience Extensions

extension Property {
  /// Create a property that checks a boolean condition
  public static func check(
    _ generator: Gen<T>,
    _ condition: @escaping @Sendable (T) -> Bool
  ) -> Property<T> {
    Property(generator: generator, predicate: condition)
  }

  /// Create a property with an implication (assumption -> conclusion)
  public static func implies(
    _ generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool,
    conclusion: @escaping @Sendable (T) -> Bool
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
    _ transform: @escaping (@escaping @Sendable (T) -> Bool) -> @Sendable (T) -> Bool
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
  public func filter(_ condition: @escaping @Sendable (T) -> Bool) -> Property<T> {
    // Combine the filter condition with the existing assumption
    let combinedAssumption: @Sendable (T) -> Bool = { value in
      self.assumption(value) && condition(value)
    }
    return Property(
      generator: self.generator,
      assumption: combinedAssumption,
      predicate: self.predicate
    )
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
public struct LabeledProperty<T: Sendable>: @unchecked Sendable {
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

  var discarded = 0
  var successfulIterations = 0

  while successfulIterations < config.iterations {
    let size = Size(value: min(successfulIterations, 100))
    // Generate tree for proper shrinking (essential for flatMap)
    let tree = property.generator.generateTree(&rng, size)
    let testCase = tree.value

    // Check assumption first - discarded values never reach the predicate
    if !property.assumption(testCase) {
      discarded += 1
      if discarded > config.maxDiscarded {
        return .gaveUp(discarded: discarded, iterations: successfulIterations)
      }
      continue
    }

    // Assumption passed, check the predicate
    if !property.predicate(testCase) {
      // Use tree-based shrinking for proper dependent generator support
      let shrunkCase = shrinkFailureWithTreeSynchronously(
        tree,
        property: property,
        maxShrinks: config.maxShrinks
      )
      return .failure(
        counterexample: testCase,
        iterations: successfulIterations + 1,
        shrunk: shrunkCase,
        reason: .predicateFailed,
        seed: actualSeed
      )
    }

    successfulIterations += 1
  }

  return .success(iterations: successfulIterations)
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func runPropertyAsync<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig = .default
) async -> PropertyResult<T> {
  let runner = PropertyRunner(seed: config.seed)
  return await runner.runProperty(property, config: config)
}

private func shrinkFailureWithTreeSynchronously<T>(
  _ tree: ShrinkTree<T>,
  property: Property<T>,
  maxShrinks: Int
) -> T {
  // Filter tree to respect assumptions
  let filteredTree = tree.filter { property.assumption($0) }

  // BFS search for minimal counterexample that still fails the predicate
  let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
    !property.predicate(candidate)
  }

  return minimal ?? tree.value
}

private func shrinkFailureSynchronously<T>(
  _ failingCase: T,
  property: Property<T>,
  maxShrinks: Int
) -> T {
  // Build shrink tree from the failing case
  let tree = ShrinkTree.from(failingCase, shrink: property.generator.shrink)

  // Use tree-based shrinking
  return shrinkFailureWithTreeSynchronously(tree, property: property, maxShrinks: maxShrinks)
}

/// Run a throwing property test synchronously.
///
/// Similar to `runPropertySynchronously`, but supports predicates that may throw.
/// Thrown errors are caught and classified as `.threwError` failures.
///
/// - Parameters:
///   - property: The throwing property to test
///   - config: Configuration for test execution
///
/// - Returns: The result of running the property
public func runThrowingPropertySynchronously<T>(
  _ property: ThrowingProperty<T>,
  config: PropertyConfig = .default
) -> PropertyResult<T> {
  let actualSeed = config.seed ?? Seed.random
  var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: actualSeed)

  var discarded = 0
  var successfulIterations = 0

  while successfulIterations < config.iterations {
    let size = Size(value: min(successfulIterations, 100))
    let testCase = property.generator.generate(&rng, size)

    // Check assumption first
    if !property.assumption(testCase) {
      discarded += 1
      if discarded > config.maxDiscarded {
        return .gaveUp(discarded: discarded, iterations: successfulIterations)
      }
      continue
    }

    // Assumption passed, check the predicate
    do {
      if try !property.predicate(testCase) {
        // Predicate returned false
        let shrunkCase = shrinkThrowingFailureSynchronously(
          testCase,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .predicateFailed,
          seed: actualSeed
        )
      }
    } catch {
      // Predicate threw an error
      let errorDescription = String(describing: error)
      let shrunkCase = shrinkThrowingFailureSynchronously(
        testCase,
        property: property,
        maxShrinks: config.maxShrinks
      )
      return .failure(
        counterexample: testCase,
        iterations: successfulIterations + 1,
        shrunk: shrunkCase,
        reason: .threwError(errorDescription),
        seed: actualSeed
      )
    }

    successfulIterations += 1
  }

  return .success(iterations: successfulIterations)
}

private func shrinkThrowingFailureSynchronously<T>(
  _ failingCase: T,
  property: ThrowingProperty<T>,
  maxShrinks: Int
) -> T {
  // Build shrink tree from the failing case
  let tree = ShrinkTree.from(failingCase, shrink: property.generator.shrink)

  // Filter tree to respect assumptions
  let filteredTree = tree.filter { property.assumption($0) }

  // BFS search for minimal counterexample that still fails (returns false or throws)
  let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
    do {
      return try !property.predicate(candidate)
    } catch {
      return true  // Throws = still fails
    }
  }

  return minimal ?? failingCase
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
