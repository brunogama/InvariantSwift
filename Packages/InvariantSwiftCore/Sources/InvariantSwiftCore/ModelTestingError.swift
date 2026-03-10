import Foundation

// MARK: - Model Testing Error Types

/// **Error types for model-based testing operations**
///
/// `ModelTestError` encapsulates all error conditions that can arise during model-based
/// testing. These errors are thrown from `Command.execute()` to signal command-level failures,
/// or by the test runner infrastructure to signal protocol violations.
///
/// **Error Categories**:
/// - **commandFailed**: The real system command returned an unexpected result
/// - **preconditionViolated**: A command was executed in an invalid state
/// - **postconditionViolated**: The real system result didn't match the model's expectation
/// - **invariantViolated**: A state invariant was broken after a command
///
/// **Usage in Commands**:
/// ```swift
/// struct MyCommand: Command {
///   func execute() async throws -> Bool {
///     guard isValid else {
///       throw ModelTestError.commandFailed("Invalid input: \(value)")
///     }
///     return true
///   }
/// }
/// ```
///
/// **Framework Behavior**:
/// When the test runner catches a `ModelTestError`, it treats the current command sequence
/// as failed and begins shrinking to find the minimal failing sequence.
///
/// - See Also: ``Command``, ``ModelTestRunner``
public enum ModelTestError: Error, Sendable {
  /// **Command execution produced an unexpected or invalid result**
  ///
  /// Thrown when the real system command fails to execute correctly.
  /// Include a descriptive message to aid debugging.
  ///
  /// - Parameter message: Human-readable description of the failure
  case commandFailed(String)

  /// **A command was executed in a state that violates its precondition**
  ///
  /// Indicates the test runner attempted to execute a command when its
  /// `precondition(state:)` would return `false`. This typically signals
  /// a bug in the state machine's `generateCommand` implementation.
  ///
  /// - Parameter message: Description of which precondition was violated
  case preconditionViolated(String)

  /// **The real system result doesn't match the model's expected result**
  ///
  /// Thrown when `postcondition(state:result:)` returns `false`, indicating
  /// divergence between the model's expectation and the real system's behavior.
  ///
  /// - Parameter message: Description of the postcondition that was violated
  case postconditionViolated(String)

  /// **A state invariant was violated after executing a command**
  ///
  /// Thrown when `StateMachine.invariant(state:)` returns `false` after
  /// applying a command. This indicates the system entered an invalid state.
  ///
  /// - Parameter message: Description of the invariant that was violated
  case invariantViolated(String)

  /// **A ``FailureInjector`` explicitly injected this error**
  ///
  /// Produced when a `FailureInjector` triggers during command execution.
  ///
  /// - Parameter message: Human-readable description of the injected failure
  case injectedFailure(String)
}
