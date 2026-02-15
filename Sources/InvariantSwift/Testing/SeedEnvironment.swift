import Foundation
import os.log
import InvariantSwiftCore

private let logger = Logger(subsystem: "InvariantSwift", category: "Seed")

// MARK: - Seed Environment Support

extension Seed {
  /// Creates a seed from the INVARIANT_SEED environment variable or generates a random one.
  ///
  /// This method checks the `INVARIANT_SEED` environment variable:
  /// - If not set, returns a random seed
  /// - If set to a valid UInt64, returns a seed with that value
  /// - If set but invalid, prints a warning and returns a random seed
  ///
  /// Use this for reproducible test failures across CI/CD and local environments:
  /// ```bash
  /// # Reproduce a CI failure locally
  /// INVARIANT_SEED=12345 swift test --filter testArraySort
  ///
  /// # Or export for multiple runs
  /// export INVARIANT_SEED=12345
  /// swift test --filter testArraySort
  /// ```
  ///
  /// - Returns: A Seed from environment variable or random
  /// - See Also: ``ReplayToken``, ``PropertyConfig``
  public static func fromEnvironmentOrRandom() -> Seed {
    guard let seedValue = ProcessInfo.processInfo.environment["INVARIANT_SEED"] else {
      return .random
    }

    // Try to parse as UInt64
    if let value = UInt64(seedValue) {
      return Seed(value: value)
    }

    // Invalid format - log warning and fall back to random
    logger.warning("INVARIANT_SEED=\(seedValue) is not a valid UInt64, using random seed")
    return .random
  }

  /// Checks if the INVARIANT_SEED environment variable is set.
  ///
  /// - Returns: true if INVARIANT_SEED is set to any value
  public static var isEnvironmentSeedSet: Bool {
    ProcessInfo.processInfo.environment["INVARIANT_SEED"] != nil
  }

  /// Returns the raw value of the INVARIANT_SEED environment variable.
  ///
  /// - Returns: The string value, or nil if not set
  public static var environmentSeedValue: String? {
    ProcessInfo.processInfo.environment["INVARIANT_SEED"]
  }
}

// MARK: - PropertyConfig Integration

extension PropertyConfig {
  /// Creates a default configuration using the environment seed if available.
  ///
  /// This is a convenience factory method that creates a PropertyConfig
  /// with Seed.fromEnvironmentOrRandom() as the seed.
  ///
  /// - Returns: PropertyConfig with environment-aware seed
  public static func `default`() -> PropertyConfig {
    PropertyConfig(
      iterations: 100,
      maxShrinks: 1000,
      maxDiscarded: 500,
      seed: Seed.fromEnvironmentOrRandom()
    )
  }
}
