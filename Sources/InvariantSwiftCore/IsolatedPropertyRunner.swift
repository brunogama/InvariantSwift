import Foundation

// MARK: - Isolated Property Result

/// Result of a property test run with crash isolation.
///
/// Extends `PropertyResult` with structured crash information via `CrashReport`.
public enum IsolatedPropertyResult<T: Sendable>: Sendable {

  /// All iterations passed successfully.
  case success(iterations: Int)

  // swiftlint:disable:next orphaned_doc_comment
  /// Property found a failing input.
  // swiftlint:disable:next enum_case_associated_values_count
  case failure(counterexample: T, seed: Seed, shrunk: T, iterations: Int, reason: String)

  /// Property execution crashed (fatalError, precondition failure, etc.).
  ///
  /// The `report` contains full diagnostic information including signal, counterexample,
  /// shrunk counterexample, stderr, backtrace, and isolation mechanism provenance.
  case crashed(report: CrashReport<T>, iterations: Int)

  /// Gave up after too many discards.
  case gaveUp(discards: Int)
}

// MARK: - Isolated Property Runner

/// Property runner with crash isolation using the `IsolationStrategy` protocol.
///
/// Unlike the standard `PropertyRunner`, this runner can detect and handle
/// crashes (fatalError, preconditionFailure, assertion failures) without
/// killing the test process.
///
/// The isolation mechanism is chosen automatically at runtime based on
/// `IsolationCapability.current`:
/// - `.fullSubprocess` → `PosixSpawnIsolation` (macOS, iOS Simulator)
/// - `.threadBased` → `ThreadIsolation` (iOS physical device)
/// - `.none` → `PassthroughIsolation` (no crash detection)
///
/// **Usage:**
/// ```swift
/// let runner = IsolatedPropertyRunner()
/// let result = await runner.runProperty(property)
///
/// switch result {
/// case .success:
// swiftlint:disable:next no_print
///   print("All iterations passed")
/// case .crashed(let report, _):
// swiftlint:disable:next no_print
///   print(report.formatted())
/// }
/// ```
///
/// **Performance:**
/// Subprocess isolation adds ~1-5ms overhead per iteration.
/// Use `PropertyRunner` for non-crashing code paths.
public actor IsolatedPropertyRunner {

  // MARK: Properties

  /// The underlying isolation strategy selected for this runner instance.
  private let strategy: any IsolationStrategy

  // MARK: Initializer

  /// Creates a new `IsolatedPropertyRunner`, auto-detecting the best isolation strategy.
  ///
  /// Pass a custom `strategy` to override auto-detection (useful in tests).
  ///
  /// - Parameter strategy: The isolation strategy to use. If `nil`, the factory
  ///   selects the best strategy for `IsolationCapability.current`.
  public init(strategy: (any IsolationStrategy)? = nil) {
    self.strategy = strategy ?? IsolationStrategyFactory.strategy(for: IsolationCapability.current)
  }

  // MARK: Public API

  /// The isolation capability provided by the strategy in use.
  ///
  /// Useful for logging or diagnostics.
  public var isolationCapability: IsolationCapability { strategy.capability }

  /// Run a property test with crash isolation.
  ///
  /// Each iteration is executed with crash detection. If a crash occurs,
  /// the counterexample is captured and shrinking continues to find the
  /// minimal crashing input.
  ///
  /// - Parameters:
  ///   - property: The property to test.
  ///   - config: Configuration for the test run.
  ///
  /// - Returns: An `IsolatedPropertyResult` indicating success, failure, or crash.
  public func runProperty<T: Sendable>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) async -> IsolatedPropertyResult<T> {

    var currentSeed = config.seed ?? Seed.random
    var discards = 0
    let maxDiscards = config.maxDiscarded

    for iteration in 0..<config.iterations {
      // Generate test value.
      var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: currentSeed)
      let size = Size(value: min(iteration + 1, 100))
      let value = property.generator.generate(&rng, size)

      // Execute with crash detection.
      let testResult = await executeWithCrashDetection(property: property, value: value)

      switch testResult {
      case .success:
        currentSeed = currentSeed.next().next
        continue

      case .failure(let reason):
        let shrunk = await shrinkWithIsolation(
          property: property,
          counterexample: value,
          config: config
        )
        return .failure(
          counterexample: value,
          seed: currentSeed,
          shrunk: shrunk ?? value,
          iterations: iteration + 1,
          reason: reason
        )

      case .crashed(let signal, let stderr, let backtrace, let isSymbolicated):
        // Attempt to shrink the crashing input.
        let shrunkValue = await shrinkCrashingInput(
          property: property,
          counterexample: value,
          config: config
        )
        let mechanism: CrashReport<T>.IsolationMechanism =
          strategy.capability == .fullSubprocess
          ? .posixSpawnSubprocess
          : .threadSignalHandler
        let report = CrashReport<T>(
          signal: signal,
          counterexample: value,
          shrunkCounterexample: shrunkValue ?? value,
          stderr: stderr,
          backtrace: backtrace,
          isSymbolicated: isSymbolicated,
          isolationMechanism: mechanism
        )
        return .crashed(report: report, iterations: iteration + 1)

      case .discarded:
        discards += 1
        if discards >= maxDiscards {
          return .gaveUp(discards: discards)
        }
        currentSeed = currentSeed.next().next
        continue
      }
    }

    return .success(iterations: config.iterations)
  }

  // MARK: - Private Helpers

  /// Internal outcome of a single test iteration.
  private enum TestOutcome {
    case success
    case failure(reason: String)
    case crashed(signal: Int32, stderr: String, backtrace: [String], isSymbolicated: Bool)
    case discarded
  }

  /// Execute a single test iteration by delegating to the isolation strategy.
  ///
  /// Dispatches to `executeViaSubprocess` for `PosixSpawnIsolation`; uses
  /// `strategy.execute(body:)` for all other strategies.
  private func executeWithCrashDetection<T: Sendable>(
    property: Property<T>,
    value: T
  ) async -> TestOutcome {
    let result: IsolationResult

    // Subprocess path: delegate IPC to PosixSpawnIsolation directly.
    // The cast is safe because IsolationStrategyFactory guarantees that
    // the only strategy with .fullSubprocess capability is PosixSpawnIsolation.
    if strategy.capability == .fullSubprocess,
      let posixStrategy = strategy as? PosixSpawnIsolation
    {
      let request = PropertyEvaluationRequest(
        testId: UUID(),
        seed: 0,
        size: 0,
        testInput: Data(),
        generatorType: String(describing: T.self)
      )
      result = await posixStrategy.executeViaSubprocess(request: request)
    } else {
      // Thread-based or passthrough: execute body in-process.
      result = await strategy.execute(body: { property.predicate(value) })
    }

    return mapToTestOutcome(result)
  }

  /// Maps an `IsolationResult` to the internal `TestOutcome`.
  private func mapToTestOutcome(_ result: IsolationResult) -> TestOutcome {
    switch result {
    case .success:
      return .success

    case .failure(let reason):
      return .failure(reason: reason)

    case .crashed(let signal, let stderr, let backtrace, let isSymbolicated):
      return .crashed(
        signal: signal,
        stderr: stderr,
        backtrace: backtrace,
        isSymbolicated: isSymbolicated
      )

    case .timeout:
      return .failure(reason: "Timed out")
    }
  }

  /// Shrink a failing (non-crash) input with isolation.
  private func shrinkWithIsolation<T: Sendable>(
    property: Property<T>,
    counterexample: T,
    config: PropertyConfig
  ) async -> T? {
    let shrinkCandidates = property.generator.shrink.shrink(counterexample)

    for candidate in shrinkCandidates.prefix(config.maxShrinks) {
      let result = await executeWithCrashDetection(property: property, value: candidate)

      if case .failure = result {
        if let smaller = await shrinkWithIsolation(
          property: property,
          counterexample: candidate,
          config: config
        ) {
          return smaller
        }
        return candidate
      }
    }

    return nil
  }

  /// Shrink a crashing input with isolation.
  private func shrinkCrashingInput<T: Sendable>(
    property: Property<T>,
    counterexample: T,
    config: PropertyConfig
  ) async -> T? {
    let shrinkCandidates = property.generator.shrink.shrink(counterexample)

    for candidate in shrinkCandidates.prefix(config.maxShrinks) {
      let result = await executeWithCrashDetection(property: property, value: candidate)

      if case .crashed = result {
        if let smaller = await shrinkCrashingInput(
          property: property,
          counterexample: candidate,
          config: config
        ) {
          return smaller
        }
        return candidate
      }
    }

    return nil
  }
}

// MARK: - PropertyConfig Extension

extension PropertyConfig {

  /// Create a configuration for isolated (crash-resistant) testing.
  ///
  /// Use this when testing code that might crash (fatalError, precondition, etc.)
  ///
  /// - Parameters:
  ///   - iterations: Number of test iterations.
  ///   - maxShrinks: Maximum shrink attempts per failure.
  ///   - timeout: Timeout per iteration in seconds (reserved for future use).
  ///
  /// - Returns: A `PropertyConfig` suitable for isolated testing.
  public static func isolated(
    iterations: Int = 100,
    maxShrinks: Int = 50,
    timeout: TimeInterval = 5.0
  ) -> PropertyConfig {
    PropertyConfig(
      iterations: iterations,
      maxShrinks: maxShrinks
    )
  }
}
