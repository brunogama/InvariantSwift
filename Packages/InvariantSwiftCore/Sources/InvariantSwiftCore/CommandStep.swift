import Foundation

// MARK: - CommandFailureKind

/// **Category of failure for a command step in model-based testing**
///
/// `CommandFailureKind` classifies why a command step failed during trace execution.
/// Each case carries enough information to diagnose the failure in the context of the
/// surrounding `CommandStep` and `CommandTrace`.
///
/// - See Also: ``CommandStep``, ``CommandTrace``
public enum CommandFailureKind: Sendable, CustomStringConvertible {
  /// The command's `precondition(state:)` returned `false` — the command was invalid
  /// in the current model state and should not have been generated or executed.
  case preconditionViolated

  /// The command's `postcondition(state:result:)` returned `false` — the real system
  /// returned a result that diverges from the model's expectation.
  case postconditionFailed

  /// The model's `invariant(state:)` returned `false`. `when` is either `"before"`
  /// (invariant violated before applying the command) or `"after"` (violated after apply).
  case invariantViolated(when: String)

  /// The command's `execute()` threw an error. The error description is captured here;
  /// the original `Error` is in ``CommandStep/error``.
  case executionError(String)

  /// A ``FailureInjector`` explicitly injected this failure.
  case injectedFailure(String)

  public var description: String {
    switch self {
    case .preconditionViolated:
      return "precondition violated"

    case .postconditionFailed:
      return "postcondition failed"

    case .invariantViolated(let when):
      return "invariant violated (\(when) command)"

    case .executionError(let msg):
      return "execution error: \(msg)"

    case .injectedFailure(let msg):
      return "injected failure: \(msg)"
    }
  }
}

// MARK: - CommandStep

/// **Record of a single command's execution within a model-based test trace**
///
/// `CommandStep` captures everything that happened when one command was executed:
/// the model state before and after, the result from the real system, any error thrown,
/// and the category of failure if the step failed.
///
/// Steps are collected into an ``CommandTrace`` by the ``ModelTestRunner``.
///
/// **Passed step** — `failureKind` is `nil`, `stateAfter` and `result` are non-nil.
///
/// **Failed step** — `failureKind` describes the failure; `stateAfter` and/or `result`
/// may be `nil` depending on which check failed.
///
/// **Usage**:
/// ```swift
/// case .failure(let trace, _, _):
///     if let step = trace.failingStep {
///         // step.index, step.command, step.stateBefore, step.failureKind
///         // are all available for diagnostics
///         _ = step.index
///     }
/// ```
///
/// - See Also: ``CommandTrace``, ``CommandFailureKind``, ``ModelTestRunner``
public struct CommandStep<C: Command>: Sendable {
  /// Zero-based index of this step within the enclosing ``CommandTrace``.
  public let index: Int

  /// The command that was (or was attempted to be) executed.
  public let command: C

  /// Model state immediately before this command was considered.
  public let stateBefore: C.State

  /// Model state after `command.apply(state:)` was called.
  /// `nil` if the command failed before `apply` was reached (e.g., precondition or
  /// execution error).
  public let stateAfter: C.State?

  /// Result returned by `command.execute()`.
  /// `nil` if `execute()` threw or the step failed before execution.
  public let result: C.Result?

  /// Error thrown by `command.execute()`, or an injected error.
  /// `nil` for passed steps or non-execution failures.
  public let error: (any Error)?

  /// Classification of the failure. `nil` for passed steps.
  public let failureKind: CommandFailureKind?

  /// `true` if this step passed all checks (precondition, execution, postcondition, invariants).
  public var passed: Bool { failureKind == nil }

  /// Memberwise initializer.
  public init(
    index: Int,
    command: C,
    stateBefore: C.State,
    stateAfter: C.State?,
    result: C.Result?,
    error: (any Error)?,
    failureKind: CommandFailureKind?
  ) {
    self.index = index
    self.command = command
    self.stateBefore = stateBefore
    self.stateAfter = stateAfter
    self.result = result
    self.error = error
    self.failureKind = failureKind
  }
}
