import Foundation

/// Records whether a generated throwing property test has reported its original error.
///
/// Macro-generated predicates can run more than once while shrinking a counterexample.
/// This recorder lets those predicates report the original error exactly once per generated test.
// NSLock serializes access to the only mutable state, making this reference safe to share
// with the concurrently-executing predicate closure.
public final class ThrowingPropertyErrorRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var hasRecordedError = false

  /// Creates a recorder for one generated property test or replay.
  public init() {}

  /// Returns `true` exactly once, then returns `false` for all later calls.
  public func shouldRecord() -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard !hasRecordedError else { return false }
    hasRecordedError = true
    return true
  }
}
