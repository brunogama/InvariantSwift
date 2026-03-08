import Foundation

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
  private static let maxSupportedIterations = 50_000

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

  /// Failing example database for automatic persistence and replay.
  ///
  /// When set, failed test cases are automatically saved to the database
  /// and replayed on subsequent runs before random generation.
  public let failingExampleDatabase: FailingExampleDatabase?

  /// Test identifier for database lookup.
  ///
  /// Required when using failingExampleDatabase. Generated from function context.
  public let testIdentifier: TestIdentifier?

  /// Whether to replay saved failures before random generation.
  ///
  /// When true (default), saved failing examples are tested first.
  /// If they now pass, they're marked as fixed.
  public let replayFirst: Bool

  /// Maximum examples to replay from database (nil = all).
  public let maxReplayExamples: Int?

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

  /// Enable progress tracking for long-running tests.
  ///
  /// When true, progress updates are emitted during test execution.
  /// Progress is automatically suppressed for fast tests (< 5 seconds).
  ///
  /// Default: false
  public let showProgress: Bool

  /// Interval for progress reporting.
  ///
  /// Controls how frequently progress updates are emitted:
  /// - `.iterations(N)`: Report every N iterations
  /// - `.seconds(T)`: Report every T seconds
  /// - `.adaptive`: Report every 1000 iterations OR 5 seconds (default)
  ///
  /// Default: `.adaptive`
  public let progressInterval: ProgressInterval

  /// Initializes a property testing configuration.
  ///
  /// - Parameters:
  ///   - iterations: Number of test cases (default: 100). Clamped to 1...50_000.
  ///   - maxShrinks: Maximum shrink attempts (default: 1000). Clamped to at least 0.
  ///   - maxDiscarded: Maximum discarded cases (default: 1000). Clamped to at least 0.
  ///   - seed: Optional seed for reproducibility. Default: nil (system randomness).
  ///   - verbose: Enable verbose output. Default: false.
  ///   - timeout: Optional per-iteration timeout. Default: nil (no timeout).
  ///   - verbosity: Output verbosity level. Default: .normal.
  ///   - regressionBank: Optional regression bank for persisting failures. Default: nil.
  ///   - propertyId: Unique identifier for regression storage. Default: nil.
  ///   - failingExampleDatabase: Optional database for persisting failures. Default: nil.
  ///   - testIdentifier: TestIdentifier for database lookup. Default: nil.
  ///   - replayFirst: Whether to replay saved failures first. Default: true.
  ///   - maxReplayExamples: Max examples to replay (nil = all). Default: nil.
  ///   - unicodeMode: Unicode handling mode for strings. Default: .scalarSafe.
  ///   - maxStringShrinkSteps: Maximum steps for string shrinking. Default: 500.
  ///   - showProgress: Enable progress tracking. Default: false.
  ///   - progressInterval: Progress reporting interval. Default: .adaptive.
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
  ///       maxStringShrinkSteps: 1000,
  ///       showProgress: true,
  ///       progressInterval: .seconds(10.0)
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
    failingExampleDatabase: FailingExampleDatabase? = nil,
    testIdentifier: TestIdentifier? = nil,
    replayFirst: Bool = true,
    maxReplayExamples: Int? = nil,
    unicodeMode: UnicodeMode = .scalarSafe,
    maxStringShrinkSteps: Int = 500,
    coverage: CoverageConfig = .default,
    discard: DiscardConfig = .default,
    showProgress: Bool = false,
    progressInterval: ProgressInterval = .adaptive
  ) {
    self.iterations = min(max(1, iterations), Self.maxSupportedIterations)
    self.maxShrinks = max(0, maxShrinks)
    self.maxDiscarded = max(0, maxDiscarded)
    self.seed = seed
    self.verbose = verbose
    self.timeout = timeout
    self.verbosity = verbosity
    self.regressionBank = regressionBank
    self.propertyId = propertyId
    self.failingExampleDatabase = failingExampleDatabase
    self.testIdentifier = testIdentifier
    self.replayFirst = replayFirst
    self.maxReplayExamples = maxReplayExamples
    self.unicodeMode = unicodeMode
    self.maxStringShrinkSteps = max(1, maxStringShrinkSteps)
    self.coverage = coverage
    self.discard = discard
    self.showProgress = showProgress
    self.progressInterval = progressInterval
  }

  /// Default configuration: 100 iterations, 1000 shrinks, 1000 max discarded.
  ///
  /// A balanced default suitable for most properties. Adjust if needed for
  /// your specific testing requirements.
  public static let `default` = Self()
}
