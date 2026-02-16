import Foundation

// MARK: - Seed Strategy

/// Strategy for test seed selection
public enum SeedStrategy: Sendable, Equatable {
  /// Use random seed on every run
  case random

  /// Use fixed seed for reproducibility
  case fixed(Seed)

  /// Get the seed value
  public var seed: Seed {
    switch self {
    case .random:
      return Seed.random

    case .fixed(let seed):
      return seed
    }
  }
}

// MARK: - PropertyConfig Builder

/// Fluent builder API for PropertyConfig
///
/// Example:
/// ```swift
/// let config = PropertyConfigBuilder()
///   .withIterations(100)
///   .withSeed(42)
///   .withVerbose(true)
///   .build()
/// ```
public struct PropertyConfigBuilder: Sendable {
  private var iterations: Int = 100
  private var maxShrinks: Int = 1000
  private var maxDiscarded: Int = 1000
  private var seedStrategy: SeedStrategy = .random
  private var verbose: Bool = false
  private var timeout: TimeInterval?
  private var verbosity: PropertyConfig.Verbosity = .normal
  private var regressionBank: RegressionBank?
  private var propertyId: String?
  private var failingExampleDatabase: FailingExampleDatabase?
  private var testIdentifier: TestIdentifier?
  private var replayFirst: Bool = true
  private var maxReplayExamples: Int?
  private var unicodeMode: PropertyConfig.UnicodeMode = .scalarSafe
  private var maxStringShrinkSteps: Int = 500
  private var coverage: PropertyConfig.CoverageConfig = .default
  private var discard: PropertyConfig.DiscardConfig = .default
  private var showProgress: Bool = false
  private var progressInterval: ProgressInterval = .adaptive

  /// Create a new builder with default values
  public init() {}

  /// Set number of iterations
  @discardableResult
  public func withIterations(_ iterations: Int) -> Self {
    var builder = self
    builder.iterations = iterations
    return builder
  }

  /// Set maximum shrink attempts
  @discardableResult
  public func withMaxShrinks(_ maxShrinks: Int) -> Self {
    var builder = self
    builder.maxShrinks = maxShrinks
    return builder
  }

  /// Set maximum discarded cases
  @discardableResult
  public func withMaxDiscarded(_ maxDiscarded: Int) -> Self {
    var builder = self
    builder.maxDiscarded = maxDiscarded
    return builder
  }

  /// Set seed strategy
  @discardableResult
  public func withSeedStrategy(_ strategy: SeedStrategy) -> Self {
    var builder = self
    builder.seedStrategy = strategy
    return builder
  }

  /// Set fixed seed (convenience for .fixed(Seed(value:)))
  @discardableResult
  public func withSeed(_ seedValue: UInt64) -> Self {
    var builder = self
    builder.seedStrategy = .fixed(Seed(value: seedValue))
    return builder
  }

  /// Set verbose output
  @discardableResult
  public func withVerbose(_ verbose: Bool) -> Self {
    var builder = self
    builder.verbose = verbose
    return builder
  }

  /// Set timeout per iteration
  @discardableResult
  public func withTimeout(_ timeout: TimeInterval?) -> Self {
    var builder = self
    builder.timeout = timeout
    return builder
  }

  /// Set verbosity level
  @discardableResult
  public func withVerbosity(_ verbosity: PropertyConfig.Verbosity) -> Self {
    var builder = self
    builder.verbosity = verbosity
    return builder
  }

  /// Set regression bank
  @discardableResult
  public func withRegressionBank(_ bank: RegressionBank?, propertyId: String?) -> Self {
    var builder = self
    builder.regressionBank = bank
    builder.propertyId = propertyId
    return builder
  }

  /// Set failing example database
  @discardableResult
  public func withFailingExampleDatabase(
    _ database: FailingExampleDatabase?,
    testIdentifier: TestIdentifier?
  ) -> Self {
    var builder = self
    builder.failingExampleDatabase = database
    builder.testIdentifier = testIdentifier
    return builder
  }

  /// Set replay first behavior
  @discardableResult
  public func withReplayFirst(_ replayFirst: Bool) -> Self {
    var builder = self
    builder.replayFirst = replayFirst
    return builder
  }

  /// Set max replay examples
  @discardableResult
  public func withMaxReplayExamples(_ max: Int?) -> Self {
    var builder = self
    builder.maxReplayExamples = max
    return builder
  }

  /// Set unicode mode
  @discardableResult
  public func withUnicodeMode(_ mode: PropertyConfig.UnicodeMode) -> Self {
    var builder = self
    builder.unicodeMode = mode
    return builder
  }

  /// Set max string shrink steps
  @discardableResult
  public func withMaxStringShrinkSteps(_ steps: Int) -> Self {
    var builder = self
    builder.maxStringShrinkSteps = steps
    return builder
  }

  /// Set coverage config
  @discardableResult
  public func withCoverage(_ coverage: PropertyConfig.CoverageConfig) -> Self {
    var builder = self
    builder.coverage = coverage
    return builder
  }

  /// Set discard config
  @discardableResult
  public func withDiscard(_ discard: PropertyConfig.DiscardConfig) -> Self {
    var builder = self
    builder.discard = discard
    return builder
  }

  /// Set progress reporting
  @discardableResult
  public func withShowProgress(_ show: Bool) -> Self {
    var builder = self
    builder.showProgress = show
    return builder
  }

  /// Set progress interval
  @discardableResult
  public func withProgressInterval(_ interval: ProgressInterval) -> Self {
    var builder = self
    builder.progressInterval = interval
    return builder
  }

  /// Build the final PropertyConfig
  public func build() -> PropertyConfig {
    PropertyConfig(
      iterations: iterations,
      maxShrinks: maxShrinks,
      maxDiscarded: maxDiscarded,
      seed: seedStrategy.seed,
      verbose: verbose,
      timeout: timeout,
      verbosity: verbosity,
      regressionBank: regressionBank,
      propertyId: propertyId,
      failingExampleDatabase: failingExampleDatabase,
      testIdentifier: testIdentifier,
      replayFirst: replayFirst,
      maxReplayExamples: maxReplayExamples,
      unicodeMode: unicodeMode,
      maxStringShrinkSteps: maxStringShrinkSteps,
      coverage: coverage,
      discard: discard,
      showProgress: showProgress,
      progressInterval: progressInterval
    )
  }
}

// MARK: - PropertyConfig Extensions

extension PropertyConfig {
  /// Create a builder from this config
  public func toBuilder() -> PropertyConfigBuilder {
    PropertyConfigBuilder()
      .withIterations(iterations)
      .withMaxShrinks(maxShrinks)
      .withMaxDiscarded(maxDiscarded)
      .withSeedStrategy(seed.map { .fixed($0) } ?? .random)
      .withVerbose(verbose)
      .withTimeout(timeout)
      .withVerbosity(verbosity)
      .withRegressionBank(regressionBank, propertyId: propertyId)
      .withFailingExampleDatabase(failingExampleDatabase, testIdentifier: testIdentifier)
      .withReplayFirst(replayFirst)
      .withMaxReplayExamples(maxReplayExamples)
      .withUnicodeMode(unicodeMode)
      .withMaxStringShrinkSteps(maxStringShrinkSteps)
      .withCoverage(coverage)
      .withDiscard(discard)
      .withShowProgress(showProgress)
      .withProgressInterval(progressInterval)
  }
}
