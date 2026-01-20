import Foundation

// MARK: - PropertyResult Extensions for Counterexample Access

extension PropertyResult {

  /// Extract the counterexample if this is a failure.
  ///
  /// - Returns: The original failing value, or nil if not a failure
  public var counterexample: T? {
    guard case .failure(let value, _, _, _, _) = self else { return nil }
    return value
  }

  /// Extract the shrunk (minimal) value if this is a failure.
  ///
  /// - Returns: The minimal failing value after shrinking, or nil if not a failure
  public var shrunkValue: T? {
    guard case .failure(_, _, let shrunk, _, _) = self else { return nil }
    return shrunk
  }

  /// Extract the seed if this is a failure.
  ///
  /// - Returns: The seed that generated the failure, or nil if not a failure
  public var failureSeed: Seed? {
    guard case .failure(_, _, _, _, let seed) = self else { return nil }
    return seed
  }

  /// Extract the failure reason if this is a failure.
  ///
  /// - Returns: The reason for failure, or nil if not a failure
  public var failureReason: FailureReason? {
    guard case .failure(_, _, _, let reason, _) = self else { return nil }
    return reason
  }

  /// Alias for `iterationCount` for API consistency.
  ///
  /// - Returns: Number of iterations executed
  public var iterations: Int {
    iterationCount
  }
}
