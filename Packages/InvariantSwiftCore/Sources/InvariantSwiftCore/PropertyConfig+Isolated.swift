import Foundation

// MARK: - PropertyConfig Extension

extension PropertyConfig {
  /// Create a configuration for isolated (crash-resistant) testing
  ///
  /// Use this when testing code that might crash (fatalError, precondition,
  /// etc.)
  ///
  /// - Parameters:
  ///   - iterations: Number of test iterations
  ///   - maxShrinks: Maximum shrink attempts per failure
  ///   - timeout: Timeout per iteration in seconds
  ///
  /// - Returns: A PropertyConfig suitable for isolated testing
  public static func isolated(
    iterations: Int = 100,
    maxShrinks: Int = 50,
    timeout: TimeInterval = 5.0
  ) -> PropertyConfig {
    PropertyConfig(
      iterations: iterations,
      maxShrinks: maxShrinks,
      timeout: timeout
    )
  }
}
