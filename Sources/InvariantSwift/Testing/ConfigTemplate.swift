import Foundation
import InvariantSwiftCore

/// Template pattern for PropertyConfig presets
///
/// ConfigTemplate provides predefined configuration templates for common testing
/// scenarios, enabling quick setup without manual field specification.
///
/// **Usage:**
/// ```swift
/// // Development: Fast feedback, minimal iterations
/// let devConfig = ConfigTemplate.development
///
/// // CI: Thorough testing, more iterations
/// let ciConfig = ConfigTemplate.ci
///
/// // Debug: Minimal iterations with fixed seed
/// let debugConfig = ConfigTemplate.debug(seed: 12345)
/// ```
///
/// **Design:**
/// - Static properties for zero-config presets
/// - Returns PropertyConfig directly (no builder needed)
/// - Optimized for common scenarios (dev, CI, debug)
/// - Seed support for reproducible debugging
///
/// - Note: Templates are starting points; use ConfigBuilder for customization.
public struct ConfigTemplate {
  // Private init to prevent instantiation
  private init() {}

  /// Development template: Fast feedback with minimal iterations
  ///
  /// **Configuration:**
  /// - iterations: 25 (quick feedback)
  /// - maxShrinks: 100 (adequate shrinking)
  /// - maxDiscarded: 100 (reasonable filtering)
  /// - seed: nil (random each run)
  ///
  /// **Use case:** Local development, fast iteration cycles
  public static let development = PropertyConfig(
    iterations: 25,
    maxShrinks: 100,
    maxDiscarded: 100,
    seed: nil,
    verbose: false,
    timeout: nil,
    verbosity: .normal,
    regressionBank: nil,
    propertyId: nil,
    failingExampleDatabase: nil,
    testIdentifier: nil,
    replayFirst: true,
    maxReplayExamples: 10,
    unicodeMode: .asciiOnly,
    maxStringShrinkSteps: 500,
    coverage: .default,
    discard: .default,
    showProgress: false,
    progressInterval: .adaptive
  )

  /// CI template: Thorough testing with more iterations
  ///
  /// **Configuration:**
  /// - iterations: 200 (thorough coverage)
  /// - maxShrinks: 500 (aggressive shrinking)
  /// - maxDiscarded: 500 (extensive filtering)
  /// - seed: nil (random each run)
  ///
  /// **Use case:** Continuous integration, comprehensive testing
  public static let ci = PropertyConfig(
    iterations: 200,
    maxShrinks: 500,
    maxDiscarded: 500,
    seed: nil,
    verbose: false,
    timeout: nil,
    verbosity: .normal,
    regressionBank: nil,
    propertyId: nil,
    failingExampleDatabase: nil,
    testIdentifier: nil,
    replayFirst: true,
    maxReplayExamples: 20,
    unicodeMode: .asciiOnly,
    maxStringShrinkSteps: 1000,
    coverage: .default,
    discard: .default,
    showProgress: false,
    progressInterval: .adaptive
  )

  /// Debug template: Minimal iterations with fixed seed
  ///
  /// **Configuration:**
  /// - iterations: 10 (minimal for debugging)
  /// - maxShrinks: 50 (quick shrinking)
  /// - maxDiscarded: 50 (basic filtering)
  /// - seed: provided value (reproducible)
  ///
  /// **Use case:** Debugging specific failures, reproducible test runs
  ///
  /// - Parameter seed: Fixed seed value for reproducibility
  /// - Returns: PropertyConfig with debug settings and specified seed
  public static func debug(seed: UInt64) -> PropertyConfig {
    PropertyConfig(
      iterations: 10,
      maxShrinks: 50,
      maxDiscarded: 50,
      seed: Seed(value: seed),
      verbose: true,
      timeout: nil,
      verbosity: .verbose,
      regressionBank: nil,
      propertyId: nil,
      failingExampleDatabase: nil,
      testIdentifier: nil,
      replayFirst: true,
      maxReplayExamples: 5,
      unicodeMode: .asciiOnly,
      maxStringShrinkSteps: 100,
      coverage: .default,
      discard: .default,
      showProgress: true,
      progressInterval: .iterations(1)
    )
  }
}
