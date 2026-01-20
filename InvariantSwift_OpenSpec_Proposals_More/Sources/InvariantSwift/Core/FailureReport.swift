import Foundation

// MARK: - FailureReport (S032)

/// Standardized failure output for property test failures.
///
/// `FailureReport` provides a consistent, actionable format for communicating
/// property test failures. It includes all information needed to understand
/// and reproduce the failure.
///
/// - Example:
///   ```swift
///   let report = FailureReport(
///     propertyName: "reverseTwice",
///     outcome: .failed,
///     iterations: 42,
///     discarded: 5,
///     counterexample: "[1, 2, 3]",
///     shrunkCounterexample: "[1]",
///     reason: .predicateFailed,
///     replayToken: token
///   )
///   print(report.format())
///   ```
///
/// - See Also: ``ReplayToken``, ``PropertyResult``
public struct FailureReport: Sendable {
  /// Name or label of the property that failed.
  public let propertyName: String?

  /// The outcome of the property test.
  public let outcome: Outcome

  /// Number of successful iterations before failure.
  public let iterations: Int

  /// Number of discarded test cases.
  public let discarded: Int

  /// The original failing counterexample (before shrinking).
  public let counterexample: String

  /// The minimal counterexample after shrinking.
  public let shrunkCounterexample: String

  /// Classification of why the property failed.
  public let reason: FailureReason

  /// Token for reproducing this failure.
  public let replayToken: ReplayToken

  /// Possible outcomes for a property test.
  public enum Outcome: String, Sendable {
    case failed = "FAILED"
    case gaveUp = "GAVEP_UP"
  }

  /// Creates a failure report from all components.
  public init(
    propertyName: String? = nil,
    outcome: Outcome,
    iterations: Int,
    discarded: Int,
    counterexample: String,
    shrunkCounterexample: String,
    reason: FailureReason,
    replayToken: ReplayToken
  ) {
    self.propertyName = propertyName
    self.outcome = outcome
    self.iterations = iterations
    self.discarded = discarded
    self.counterexample = counterexample
    self.shrunkCounterexample = shrunkCounterexample
    self.reason = reason
    self.replayToken = replayToken
  }

  // MARK: - Formatting

  /// Formats the report for console output.
  ///
  /// Produces a multi-line report with all relevant information
  /// and a copy-paste replay snippet.
  ///
  /// - Returns: Formatted failure report string
  public func format() -> String {
    var lines: [String] = []

    // Header
    let name = propertyName ?? "Property"
    lines.append("━━━ \(name) \(outcome.rawValue) ━━━")
    lines.append("")

    // Statistics
    lines.append("Iterations: \(iterations)")
    if discarded > 0 {
      lines.append("Discarded:  \(discarded)")
    }
    lines.append("Reason:     \(reason.description)")
    lines.append("")

    // Counterexample
    lines.append("Minimal counterexample:")
    lines.append("  \(shrunkCounterexample)")
    if counterexample != shrunkCounterexample {
      lines.append("")
      lines.append("Original counterexample:")
      lines.append("  \(counterexample)")
    }
    lines.append("")

    // Replay
    lines.append("Replay token: \(replayToken.encode())")
    lines.append("")
    lines.append(replayToken.replaySnippet)
    lines.append("")
    lines.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    return lines.joined(separator: "\n")
  }

  /// Returns a compact single-line summary.
  public var summary: String {
    let name = propertyName ?? "Property"
    return
      "\(name) \(outcome.rawValue): \(reason.description) | counterexample: \(shrunkCounterexample)"
  }
}

// MARK: - Factory Methods

extension FailureReport {
  /// Creates a failure report from a PropertyResult.
  ///
  /// - Parameters:
  ///   - result: The failing property result
  ///   - propertyName: Optional name for the property
  ///   - config: The configuration that was used
  /// - Returns: FailureReport, or nil if not a failure
  public static func from<T>(
    _ result: PropertyResult<T>,
    propertyName: String? = nil,
    config: PropertyConfig
  ) -> FailureReport? {
    switch result {
    case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
      let token = ReplayToken(seed: seed, config: config)
      return FailureReport(
        propertyName: propertyName,
        outcome: .failed,
        iterations: iterations,
        discarded: 0,  // Not tracked in failure case
        counterexample: String(describing: counterexample),
        shrunkCounterexample: String(describing: shrunk),
        reason: reason,
        replayToken: token
      )

    case .gaveUp(let discarded, let iterations):
      // Create a synthetic report for gave up
      let token = ReplayToken(
        seed: config.seed?.rawValue ?? 0,
        iterations: config.iterations,
        maxDiscarded: config.maxDiscarded
      )
      return FailureReport(
        propertyName: propertyName,
        outcome: .gaveUp,
        iterations: iterations,
        discarded: discarded,
        counterexample: "N/A",
        shrunkCounterexample: "N/A",
        reason: .predicateFailed,  // Placeholder
        replayToken: token
      )

    case .success:
      return nil
    }
  }
}
