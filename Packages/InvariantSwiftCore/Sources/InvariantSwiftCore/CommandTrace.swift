import Foundation

// MARK: - CommandTrace

/// **Ordered record of all steps executed during a model-based test run**
///
/// `CommandTrace` collects every ``CommandStep`` produced during a single run of
/// ``ModelTestRunner``. It provides both detailed step-by-step diagnostics and
/// backward-compatible convenience accessors that mirror the old flat-array API.
///
/// **Passed trace** — `failingStepIndex` is `nil`; every step has `passed == true`.
///
/// **Failed trace** — `failingStepIndex` points to the first step that failed;
/// `failingStep` is a shortcut to that step.
///
/// - See Also: ``CommandStep``, ``CommandFailureKind``, ``ModelTestRunner``
public struct CommandTrace<C: Command>: Sendable {
  /// All steps executed during the run, in order.
  public let steps: [CommandStep<C>]

  /// Zero-based index of the first failing step, or `nil` if the trace passed.
  public let failingStepIndex: Int?

  /// The failing step, or `nil` if the trace passed.
  public var failingStep: CommandStep<C>? {
    failingStepIndex.map { steps[$0] }
  }

  // MARK: - Backward-compatible accessors

  /// All commands executed, in order.
  public var commands: [C] { steps.map(\.command) }

  /// The command that caused the failure, or `nil` if the trace passed.
  public var failedCommand: C? { failingStep?.command }

  /// The model state after the last successfully applied command,
  /// or `nil` if no command was applied.
  public var finalModelState: C.State? {
    // Walk backward to find last step with a non-nil stateAfter.
    steps.reversed().first(where: { $0.stateAfter != nil })?.stateAfter
  }

  // MARK: - Memberwise init

  /// Creates a trace from a list of steps and an optional failing index.
  public init(steps: [CommandStep<C>], failingStepIndex: Int?) {
    self.steps = steps
    self.failingStepIndex = failingStepIndex
  }
}
