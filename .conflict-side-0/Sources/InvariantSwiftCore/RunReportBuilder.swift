import Foundation

/// Builder for constructing RunReport instances.
///
/// Reduces parameter count in buildReport by encapsulating
/// report construction logic with a fluent API.
struct RunReportBuilder<T: Sendable> {
  private let result: PropertyResult<T>
  private let propertyName: String?
  private let durationMs: Int
  private let config: PropertyConfig
  private let shrinkTrace: [RunReport.ShrinkStep]?

  /// Encapsulates failure context to reduce parameter count.
  private struct FailureContext {
    let counterexample: T
    let shrunk: T
    let iterations: Int
    let reason: FailureReason
    let seed: Seed
  }

  init(
    result: PropertyResult<T>,
    propertyName: String?,
    durationMs: Int,
    config: PropertyConfig,
    shrinkTrace: [RunReport.ShrinkStep]?
  ) {
    self.result = result
    self.propertyName = propertyName
    self.durationMs = durationMs
    self.config = config
    self.shrinkTrace = shrinkTrace
  }

  func build() -> RunReport {
    switch result {
    case .success(let iterations):
      return buildSuccessReport(iterations: iterations)

    case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
      let context = FailureContext(
        counterexample: counterexample,
        shrunk: shrunk,
        iterations: iterations,
        reason: reason,
        seed: seed
      )
      return buildFailureReport(context: context)

    case .gaveUp(let discarded, let iterations):
      return buildGaveUpReport(discarded: discarded, iterations: iterations)
    }
  }

  private func buildSuccessReport(iterations: Int) -> RunReport {
    RunReport(
      propertyName: propertyName,
      outcome: .success,
      statistics: RunReport.RunStatistics(
        totalIterations: iterations,
        successfulIterations: iterations,
        failedIterations: 0,
        discardedCases: 0,
        durationMs: durationMs,
        shrinkSteps: nil
      ),
      failure: nil,
      classification: nil
    )
  }

  private func buildFailureReport(context: FailureContext) -> RunReport {
    let failureDetails = buildFailureDetails(context: context)

    return RunReport(
      propertyName: propertyName,
      outcome: .failed,
      statistics: RunReport.RunStatistics(
        totalIterations: context.iterations,
        successfulIterations: context.iterations - 1,
        failedIterations: 1,
        discardedCases: 0,
        durationMs: durationMs,
        shrinkSteps: shrinkTrace?.count
      ),
      failure: failureDetails,
      classification: nil
    )
  }

  private func buildFailureDetails(context: FailureContext) -> RunReport.FailureDetails {
    let token = ReplayToken(seed: context.seed, config: config)
    return RunReport.FailureDetails(
      failedAtIteration: context.iterations,
      reason: context.reason.description,
      originalCounterexample: String(describing: context.counterexample),
      minimalCounterexample: String(describing: context.shrunk),
      replayToken: token,
      shrinkTrace: shrinkTrace
    )
  }

  private func buildGaveUpReport(
    discarded: Int,
    iterations: Int
  ) -> RunReport {
    let token = ReplayToken(
      seed: config.seed?.rawValue ?? 0,
      iterations: config.iterations,
      maxDiscarded: config.maxDiscarded
    )
    let failureDetails = RunReport.FailureDetails(
      failedAtIteration: iterations,
      reason: "Too many discarded cases",
      originalCounterexample: "N/A",
      minimalCounterexample: "N/A",
      replayToken: token,
      shrinkTrace: nil
    )

    return RunReport(
      propertyName: propertyName,
      outcome: .gaveUp,
      statistics: RunReport.RunStatistics(
        totalIterations: iterations,
        successfulIterations: 0,
        failedIterations: 0,
        discardedCases: discarded,
        durationMs: durationMs,
        shrinkSteps: nil
      ),
      failure: failureDetails,
      classification: nil
    )
  }
}
