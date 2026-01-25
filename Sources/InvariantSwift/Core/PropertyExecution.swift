import Foundation

/// Helper functions for property test execution phases.
///
/// These functions extract common patterns from PropertyRunner to reduce complexity
/// and improve testability. Each phase is isolated with clear inputs and outputs.
enum PropertyExecution {
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
    // swiftlint:disable:next no_print
    print(message)
  }

  // MARK: - Phase 3: Save Failing Example

  /// Create a FailingExample from a property result.
  static func createFailingExample<T>(
    from result: PropertyResult<T>,
    config: PropertyConfig
  ) -> FailingExample? {
    guard case .failure(_, _, let shrunk, let reason, let failSeed) = result else {
      return nil
    }

    return FailingExample(
      seed: failSeed.rawValue,
      size: config.iterations,
      shrinkPath: nil,
      serializedInput: nil,
      inputDescription: String(describing: shrunk),
      failureMessage: reason.description
    )
  }

  /// Log save verbose message.
  static func logSaveVerbose(verbose: Bool) {
    guard verbose else { return }
    // swiftlint:disable:next no_print
    print("[Regression] Saved failing example to database")
  }
}
