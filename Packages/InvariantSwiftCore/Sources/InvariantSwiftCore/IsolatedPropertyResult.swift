// MARK: - Isolated Property Result

/// Result of a property test run with crash isolation
/// Extends PropertyResult with crash information
public enum IsolatedPropertyResult<T: Sendable>: Sendable {
  /// All iterations passed successfully
  case success(iterations: Int)

  // swiftlint:disable:next orphaned_doc_comment
  /// Property found a failing input
  // swiftlint:disable:next enum_case_associated_values_count
  case failure(
    counterexample: T,
    seed: Seed,
    shrunk: T,
    iterations: Int,
    reason: String
  )

  /// Property execution crashed (fatalError, precondition failure, etc.)
  case crashed(signal: Int32, counterexample: T, shrunk: T, iterations: Int)

  /// Gave up after too many discards
  case gaveUp(discards: Int)
}
