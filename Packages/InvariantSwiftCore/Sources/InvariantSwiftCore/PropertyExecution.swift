import OSLog

/// Helper functions for property test execution phases.
///
/// These functions extract common patterns from PropertyRunner to reduce complexity
/// and improve testability. Each phase is isolated with clear inputs and outputs.
enum PropertyExecution {
  private static let logger = Logger(
    subsystem: "InvariantSwift",
    category: "PropertyExecution"
  )

  // MARK: - Result Types

  /// Result of replaying saved failing examples.
  struct ReplayResult<T: Sendable> {
    let foundFailure: Bool
    let failure: PropertyResult<T>?
  }

  // MARK: - Phase 1: Replay Context

  /// Context for replaying saved failing examples.
  struct ReplayContext<T: Sendable> {
    let savedExamples: [FailingExample]
    let maxExamples: Int?
    let config: PropertyConfig
    let property: Property<T>
  }

  /// Determine which examples to replay based on max limit.
  static func selectExamplesToReplay(
    _ savedExamples: [FailingExample],
    maxExamples: Int?
  ) -> [FailingExample] {
    if let max = maxExamples {
      return Array(savedExamples.prefix(max))
    } else {
      return savedExamples
    }
  }

  /// Create replay configuration for a specific example.
  static func createReplayConfig(
    for example: FailingExample,
    baseConfig: PropertyConfig
  ) -> PropertyConfig {
    PropertyConfig(
      iterations: 1,
      maxShrinks: baseConfig.maxShrinks,
      seed: Seed(value: example.seed),
      verbose: baseConfig.verbose
    )
  }

  /// Log replay verbose message.
  static func logReplayVerbose(_ message: String, verbose: Bool) {
    guard verbose else { return }
    logger.info("\(message, privacy: .public)")
  }

  // MARK: - Phase 3: Save Failing Example

  /// Create a FailingExample from a property result.
  static func createFailingExample<T>(
    from result: PropertyResult<T>,
    config: PropertyConfig
  ) -> FailingExample? {
    guard
      case .failure(_, _, let shrunk, let reason, let failSeed) = result
    else {
      return nil
    }

    let failure = FailingExampleFailure(
      seed: failSeed.rawValue,
      size: config.iterations,
      message: reason.description
    )
    let context = FailingExampleContext(
      inputDescription: String(describing: shrunk)
    )
    return FailingExample(failure: failure, context: context)
  }

  /// Log save verbose message.
  static func logSaveVerbose(verbose: Bool) {
    guard verbose else { return }
    logger.info("[Regression] Saved failing example to database")
  }

  // MARK: - Discard Ratio Logging

  /// Log discard ratio warning message if needed.
  static func logDiscardWarning(_ message: String, config: PropertyConfig) {
    guard config.verbose || config.verbosity == .verbose else { return }
    logger.warning("\(message, privacy: .public)")
  }
}
