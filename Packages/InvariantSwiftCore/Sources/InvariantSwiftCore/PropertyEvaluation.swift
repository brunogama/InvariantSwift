import Foundation

/// Classifies how a property test failed.
///
/// `FailureReason` distinguishes between different failure modes, enabling better
/// diagnostics and targeted fixes:
/// - `.predicateFailed`: The property's predicate returned `false`
/// - `.threwError`: The predicate threw an error during evaluation
/// - `.timedOut`: The test exceeded the configured timeout
///
/// This classification is essential for debugging: a predicate failure suggests
/// a logic bug, while a thrown error may indicate a precondition violation or
/// unexpected edge case.
///
/// - See Also: ``PropertyResult``, ``PropertyConfig``
public enum FailureReason: Sendable, Equatable, CustomStringConvertible {
  /// The property's predicate returned `false`.
  case predicateFailed

  /// The predicate threw an error during evaluation.
  ///
  /// - Parameter error: String description of the thrown error
  case threwError(String)

  /// The test exceeded the configured timeout.
  ///
  /// - Parameter seconds: The timeout duration that was exceeded
  case timedOut(seconds: Double)

  public var description: String {
    switch self {
    case .predicateFailed:
      return "predicate returned false"

    case .threwError(let error):
      return "threw error: \(error)"

    case .timedOut(let seconds):
      return "timed out after \(seconds)s"
    }
  }
}

// MARK: - Property Evaluation (S012)

/// Outcome of evaluating a single property test case.
///
/// `PropertyEvaluation` enables explicit assumptions inside property bodies,
/// providing proper discard tracking without relying on generator filtering.
///
/// - Cases:
///   - `.pass`: The property holds for this input
///   - `.fail(reason:)`: The property failed with optional explanation
///   - `.discard(reason:)`: The input should be discarded (assumption violated)
///
/// - Example:
///   ```swift
///   let property = Property(generator: Gen.int) { n -> PropertyEvaluation in
///       guard n > 0 else { return .discard(reason: "need positive") }
///       guard n.isMultiple(of: 2) else { return .discard(reason: "need even") }
///       return n * 2 > n ? .pass : .fail(reason: "doubling should increase")
///   }
///   ```
///
/// - See Also: ``assume(_:reason:)``, ``Property``
public enum PropertyEvaluation: Sendable, Equatable {
  /// The property holds for this input.
  case pass

  /// The property failed for this input.
  ///
  /// - Parameter reason: Optional explanation of why it failed
  case fail(reason: String?)

  /// The input should be discarded (assumption violated).
  ///
  /// Discarded inputs are not counted as failures. The runner tracks discards
  /// and returns `.gaveUp` if too many inputs are discarded.
  ///
  /// - Parameter reason: Optional explanation of why it was discarded
  case discard(reason: String?)
}

/// Express an assumption inside a property body.
///
/// If the condition is false, the current test case is discarded (not failed).
/// This enables filtering at the property level with proper discard tracking,
/// avoiding the problems with generator-level filtering (`Gen.suchThat`).
///
/// - Parameters:
///   - condition: If false, the test case is discarded
///   - reason: Optional explanation for debug output
///
/// - Returns: `.pass` if condition is true, `.discard` if false
///
/// - Example:
///   ```swift
///   let property = Property(generator: Gen.int) { n -> PropertyEvaluation in
///       try assume(n > 0, reason: "need positive number")
///       try assume(n < 100, reason: "need small number")
///       return n * 2 > n ? .pass : .fail(reason: nil)
///   }
///   ```
///
/// - See Also: ``PropertyEvaluation``
public func assume(_ condition: Bool, reason: String? = nil) -> PropertyEvaluation {
  condition ? .pass : .discard(reason: reason)
}

/// Express a requirement that must hold or the property fails.
///
/// Unlike `assume()`, if the condition is false, the property *fails* (not discards).
/// Use this for postconditions and invariants that should always hold.
///
/// - Parameters:
///   - condition: If false, the property fails
///   - reason: Optional explanation for debug output
///
/// - Returns: `.pass` if condition is true, `.fail` if false
public func require(_ condition: Bool, reason: String? = nil) -> PropertyEvaluation {
  condition ? .pass : .fail(reason: reason)
}
