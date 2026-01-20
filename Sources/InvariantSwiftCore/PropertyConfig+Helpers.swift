import Foundation

/// Convenience extensions for PropertyConfig
///
/// Provides factory methods and presets for common testing scenarios.
extension PropertyConfig {
  /// Quick testing configuration for fast feedback
  ///
  /// Minimal configuration for rapid iteration during development:
  /// - 20 iterations (faster than default)
  /// - 50 max shrinks (faster shrinking)
  /// - 50 max discarded (fail fast on filtering issues)
  ///
  /// - Parameter base: Base configuration to transform (default: `.default`)
  /// - Returns: Configuration optimized for quick feedback
  ///
  /// - Example:
  ///   ```swift
  ///   let quick = PropertyConfig.quickConfig()
  ///   try await checkProperty(property, config: quick)
  ///   ```
  public static func quickConfig(_ base: PropertyConfig = .default) -> PropertyConfig {
    PropertyConfig(
      iterations: 20,
      maxShrinks: 50,
      maxDiscarded: 50,
      seed: base.seed,
      verbose: base.verbose,
      timeout: base.timeout,
      verbosity: base.verbosity,
      regressionBank: base.regressionBank,
      propertyId: base.propertyId,
      failingExampleDatabase: base.failingExampleDatabase,
      testIdentifier: base.testIdentifier,
      replayFirst: base.replayFirst,
      maxReplayExamples: base.maxReplayExamples,
      unicodeMode: base.unicodeMode,
      maxStringShrinkSteps: base.maxStringShrinkSteps,
      coverage: base.coverage,
      discard: base.discard,
      showProgress: base.showProgress,
      progressInterval: base.progressInterval
    )
  }

  /// Performance testing configuration for thorough validation
  ///
  /// High-iteration configuration for performance benchmarking:
  /// - 10,000 iterations (comprehensive coverage)
  /// - 10 max shrinks (fast feedback, not minimal counterexamples)
  /// - 100 max discarded (tolerates some filtering)
  ///
  /// - Parameter base: Base configuration to transform (default: `.default`)
  /// - Returns: Configuration optimized for performance testing
  ///
  /// - Example:
  ///   ```swift
  ///   let perf = PropertyConfig.performanceConfig()
  ///   try await checkProperty(property, config: perf)
  ///   ```
  public static func performanceConfig(_ base: PropertyConfig = .default) -> PropertyConfig {
    PropertyConfig(
      iterations: 10_000,
      maxShrinks: 10,
      maxDiscarded: 100,
      seed: base.seed,
      verbose: base.verbose,
      timeout: base.timeout,
      verbosity: base.verbosity,
      regressionBank: base.regressionBank,
      propertyId: base.propertyId,
      failingExampleDatabase: base.failingExampleDatabase,
      testIdentifier: base.testIdentifier,
      replayFirst: base.replayFirst,
      maxReplayExamples: base.maxReplayExamples,
      unicodeMode: base.unicodeMode,
      maxStringShrinkSteps: base.maxStringShrinkSteps,
      coverage: base.coverage,
      discard: base.discard,
      showProgress: base.showProgress,
      progressInterval: base.progressInterval
    )
  }

  /// Stress testing configuration for maximum coverage
  ///
  /// Aggressive configuration for stress testing:
  /// - 100,000 iterations (extreme coverage)
  /// - 10,000 max shrinks (thorough minimization)
  /// - 10,000 max discarded (very tolerant of filtering)
  ///
  /// - Parameter base: Base configuration to transform (default: `.default`)
  /// - Returns: Configuration optimized for stress testing
  ///
  /// - Example:
  ///   ```swift
  ///   let stress = PropertyConfig.stressConfig()
  ///   try await checkProperty(property, config: stress)
  ///   ```
  public static func stressConfig(_ base: PropertyConfig = .default) -> PropertyConfig {
    PropertyConfig(
      iterations: 100_000,
      maxShrinks: 10_000,
      maxDiscarded: 10_000,
      seed: base.seed,
      verbose: base.verbose,
      timeout: base.timeout,
      verbosity: base.verbosity,
      regressionBank: base.regressionBank,
      propertyId: base.propertyId,
      failingExampleDatabase: base.failingExampleDatabase,
      testIdentifier: base.testIdentifier,
      replayFirst: base.replayFirst,
      maxReplayExamples: base.maxReplayExamples,
      unicodeMode: base.unicodeMode,
      maxStringShrinkSteps: base.maxStringShrinkSteps,
      coverage: base.coverage,
      discard: base.discard,
      showProgress: true,  // Enable progress for long-running stress tests
      progressInterval: .seconds(5.0)
    )
  }

  /// Development configuration for verbose debugging
  ///
  /// Configuration optimized for development and debugging:
  /// - 100 iterations (standard coverage)
  /// - Verbose output enabled
  /// - Progress tracking enabled
  ///
  /// - Parameter base: Base configuration to transform (default: `.default`)
  /// - Returns: Configuration optimized for development
  ///
  /// - Example:
  ///   ```swift
  ///   let dev = PropertyConfig.devConfig()
  ///   try await checkProperty(property, config: dev)
  ///   ```
  public static func devConfig(_ base: PropertyConfig = .default) -> PropertyConfig {
    PropertyConfig(
      iterations: 100,
      maxShrinks: base.maxShrinks,
      maxDiscarded: base.maxDiscarded,
      seed: base.seed,
      verbose: true,
      timeout: base.timeout,
      verbosity: .verbose,
      regressionBank: base.regressionBank,
      propertyId: base.propertyId,
      failingExampleDatabase: base.failingExampleDatabase,
      testIdentifier: base.testIdentifier,
      replayFirst: base.replayFirst,
      maxReplayExamples: base.maxReplayExamples,
      unicodeMode: base.unicodeMode,
      maxStringShrinkSteps: base.maxStringShrinkSteps,
      coverage: base.coverage,
      discard: base.discard,
      showProgress: true,
      progressInterval: .adaptive
    )
  }
}
