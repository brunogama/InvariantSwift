import Foundation
import InvariantSwiftCore

/// Lens extensions for PropertyConfig type
///
/// Provides functional lens-based access to PropertyConfig properties, enabling
/// immutable updates and composition with other lenses.
///
/// - Note: Lens properties are named with `Lens` suffix (e.g., `iterationsLens`)
///   to avoid Swift's limitation with static/instance property name collision.
extension PropertyConfig {
  /// Lens for accessing and modifying the iterations count
  ///
  /// **Get:** Extracts the iterations value from the PropertyConfig
  /// **Set:** Creates a new PropertyConfig with the specified iterations count
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig.default
  ///   let iters = PropertyConfig.iterationsLens.get(config)     // 100
  ///   let updated = PropertyConfig.iterationsLens.set(200, config)  // iterations: 200
  ///   ```
  public static var iterationsLens: Lens<PropertyConfig, Int> {
    Lens(
      get: \.iterations,
      set: { newValue, config in
        PropertyConfig(
          iterations: newValue,
          maxShrinks: config.maxShrinks,
          maxDiscarded: config.maxDiscarded,
          seed: config.seed,
          verbose: config.verbose,
          timeout: config.timeout,
          verbosity: config.verbosity,
          regressionBank: config.regressionBank,
          propertyId: config.propertyId,
          failingExampleDatabase: config.failingExampleDatabase,
          testIdentifier: config.testIdentifier,
          replayFirst: config.replayFirst,
          maxReplayExamples: config.maxReplayExamples,
          unicodeMode: config.unicodeMode,
          maxStringShrinkSteps: config.maxStringShrinkSteps,
          coverage: config.coverage,
          discard: config.discard,
          showProgress: config.showProgress,
          progressInterval: config.progressInterval
        )
      }
    )
  }

  /// Lens for accessing and modifying the maxShrinks count
  ///
  /// **Get:** Extracts the maxShrinks value from the PropertyConfig
  /// **Set:** Creates a new PropertyConfig with the specified maxShrinks count
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig.default
  ///   let shrinks = PropertyConfig.maxShrinksLens.get(config)     // 1000
  ///   let updated = PropertyConfig.maxShrinksLens.set(500, config)  // maxShrinks: 500
  ///   ```
  public static var maxShrinksLens: Lens<PropertyConfig, Int> {
    Lens(
      get: \.maxShrinks,
      set: { newValue, config in
        PropertyConfig(
          iterations: config.iterations,
          maxShrinks: newValue,
          maxDiscarded: config.maxDiscarded,
          seed: config.seed,
          verbose: config.verbose,
          timeout: config.timeout,
          verbosity: config.verbosity,
          regressionBank: config.regressionBank,
          propertyId: config.propertyId,
          failingExampleDatabase: config.failingExampleDatabase,
          testIdentifier: config.testIdentifier,
          replayFirst: config.replayFirst,
          maxReplayExamples: config.maxReplayExamples,
          unicodeMode: config.unicodeMode,
          maxStringShrinkSteps: config.maxStringShrinkSteps,
          coverage: config.coverage,
          discard: config.discard,
          showProgress: config.showProgress,
          progressInterval: config.progressInterval
        )
      }
    )
  }

  /// Lens for accessing and modifying the maxDiscarded count
  ///
  /// **Get:** Extracts the maxDiscarded value from the PropertyConfig
  /// **Set:** Creates a new PropertyConfig with the specified maxDiscarded count
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig.default
  ///   let discarded = PropertyConfig.maxDiscardedLens.get(config)     // 1000
  ///   let updated = PropertyConfig.maxDiscardedLens.set(500, config)  // maxDiscarded: 500
  ///   ```
  public static var maxDiscardedLens: Lens<PropertyConfig, Int> {
    Lens(
      get: \.maxDiscarded,
      set: { newValue, config in
        PropertyConfig(
          iterations: config.iterations,
          maxShrinks: config.maxShrinks,
          maxDiscarded: newValue,
          seed: config.seed,
          verbose: config.verbose,
          timeout: config.timeout,
          verbosity: config.verbosity,
          regressionBank: config.regressionBank,
          propertyId: config.propertyId,
          failingExampleDatabase: config.failingExampleDatabase,
          testIdentifier: config.testIdentifier,
          replayFirst: config.replayFirst,
          maxReplayExamples: config.maxReplayExamples,
          unicodeMode: config.unicodeMode,
          maxStringShrinkSteps: config.maxStringShrinkSteps,
          coverage: config.coverage,
          discard: config.discard,
          showProgress: config.showProgress,
          progressInterval: config.progressInterval
        )
      }
    )
  }

  /// Lens for accessing and modifying the seed
  ///
  /// **Get:** Extracts the optional seed value from the PropertyConfig
  /// **Set:** Creates a new PropertyConfig with the specified seed
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig.default
  ///   let s = PropertyConfig.seedLens.get(config)     // nil
  ///   let updated = PropertyConfig.seedLens.set(Seed(value: 42), config)  // seed: 42
  ///   ```
  public static var seedLens: Lens<PropertyConfig, Seed?> {
    Lens(
      get: \.seed,
      set: { newValue, config in
        PropertyConfig(
          iterations: config.iterations,
          maxShrinks: config.maxShrinks,
          maxDiscarded: config.maxDiscarded,
          seed: newValue,
          verbose: config.verbose,
          timeout: config.timeout,
          verbosity: config.verbosity,
          regressionBank: config.regressionBank,
          propertyId: config.propertyId,
          failingExampleDatabase: config.failingExampleDatabase,
          testIdentifier: config.testIdentifier,
          replayFirst: config.replayFirst,
          maxReplayExamples: config.maxReplayExamples,
          unicodeMode: config.unicodeMode,
          maxStringShrinkSteps: config.maxStringShrinkSteps,
          coverage: config.coverage,
          discard: config.discard,
          showProgress: config.showProgress,
          progressInterval: config.progressInterval
        )
      }
    )
  }
}
