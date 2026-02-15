// FailureReporting.swift
// InvariantSwift
//
// Enhanced failure diagnostics for property test failures.
// Implements Task 2.3 from the roadmap.

import Foundation
import Testing
import InvariantSwiftCore
import InvariantSwift
// MARK: - Failure Report

/// Detailed failure report for a property test.
///
/// Contains all information needed to understand and reproduce a failure,
/// including the original value, shrunken counterexample, seed, and
/// reproduction instructions.
public struct FailureReport: Sendable {
  /// Name of the failing test.
  public let testName: String

  /// Seed used for random generation.
  public let seed: Seed

  /// Original failing value (before shrinking).
  public let originalValue: String

  /// Minimal counterexample (after shrinking).
  public let shrunkValue: String

  /// Number of test iterations before failure.
  public let iterationsBeforeFailure: Int

  /// Number of shrink attempts performed.
  public let shrinkAttempts: Int

  /// Number of successful shrinks.
  public let successfulShrinks: Int

  /// Optional failure reason or error message.
  public let failureReason: FailureReason

  /// Total time spent (generation + shrinking).
  public let totalTime: TimeInterval

  /// Optional classification report for classifying property tests.
  public let classificationReport: String?

  /// Optional shrinking metrics for detailed shrinking analysis.
  public let shrinkMetrics: ShrinkMetrics?

  /// Creates a new failure report.
  public init(
    testName: String,
    seed: Seed,
    originalValue: String,
    shrunkValue: String,
    iterationsBeforeFailure: Int,
    shrinkAttempts: Int,
    successfulShrinks: Int,
    failureReason: FailureReason,
    totalTime: TimeInterval,
    classificationReport: String? = nil,
    shrinkMetrics: ShrinkMetrics? = nil
  ) {
    self.testName = testName
    self.seed = seed
    self.originalValue = originalValue
    self.shrunkValue = shrunkValue
    self.iterationsBeforeFailure = iterationsBeforeFailure
    self.shrinkAttempts = shrinkAttempts
    self.successfulShrinks = successfulShrinks
    self.failureReason = failureReason
    self.totalTime = totalTime
    self.classificationReport = classificationReport
    self.shrinkMetrics = shrinkMetrics
  }

  /// Command to reproduce this failure.
  public var reproductionCommand: String {
    "swift test --filter \(testName) --env INVARIANT_SWIFT_SEED=\(seed.rawValue)"
  }

  /// Environment variable for reproduction.
  public var reproductionEnvVar: String {
    "INVARIANT_SWIFT_SEED=\(seed.rawValue)"
  }

  /// Shrinking metrics derived from individual fields.
  ///
  /// If `shrinkMetrics` was explicitly provided during initialization,
  /// returns that value. Otherwise, constructs metrics from the
  /// `shrinkAttempts`, `successfulShrinks`, and `totalTime` fields.
  public var computedShrinkMetrics: ShrinkMetrics {
    shrinkMetrics
      ?? ShrinkMetrics(
        attempts: shrinkAttempts,
        successful: successfulShrinks,
        duration: totalTime,
        reductionPercentage: 0.0,  // Cannot compute without original/shrunk sizes
        strategy: "BFS tree search"
      )
  }
}

// MARK: - Failure Reporter

/// Generates and records failure reports for property tests.
///
/// Integrates with Swift Testing's issue recording system to provide
/// detailed, actionable failure messages.
///
/// ## Example Usage
///
/// ```swift
/// let reporter = FailureReporter()
///
/// // Create a failure report
/// let report = FailureReport(
///     testName: "testSorting",
///     seed: Seed(value: 12345),
///     originalValue: "[3, 1, 2, 5, 4]",
///     shrunkValue: "[2, 1]",
///     iterationsBeforeFailure: 42,
///     shrinkAttempts: 15,
///     successfulShrinks: 8,
///     failureReason: .predicateFailed,
///     totalTime: 0.5
/// )
///
/// // Record with Swift Testing
/// reporter.recordFailure(report)
///
/// // Or save for later analysis
/// try reporter.persistFailure(report)
/// ```
public struct FailureReporter: Sendable {

  /// Persistence manager for saving failures.
  private let persistence: FailurePersistenceManager?

  /// Whether to include verbose details in reports.
  public let verbose: Bool

  /// Creates a new failure reporter.
  ///
  /// - Parameters:
  ///   - persistence: Optional persistence manager for saving failures.
  ///   - verbose: Whether to include verbose details (default: false).
  public init(persistence: FailurePersistenceManager? = nil, verbose: Bool = false) {
    self.persistence = persistence
    self.verbose = verbose
  }

  // MARK: - Recording

  /// Records a failure with Swift Testing's issue system.
  ///
  /// - Parameters:
  ///   - report: The failure report to record.
  ///   - file: Source file (auto-captured).
  ///   - line: Source line (auto-captured).
  public func recordFailure(
    _ report: FailureReport,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let message = formatMessage(report)
    Issue.record(Comment(stringLiteral: message))
  }

  /// Records a failure and optionally persists it.
  ///
  /// - Parameters:
  ///   - report: The failure report.
  ///   - persist: Whether to also save to disk.
  public func recordFailure(_ report: FailureReport, persist: Bool) {
    recordFailure(report)

    if persist, let persistence = persistence {
      let persisted = PersistedFailure(
        testName: report.testName,
        seed: report.seed.rawValue,
        originalValue: report.originalValue,
        shrunkValue: report.shrunkValue,
        iterationsBeforeFailure: report.iterationsBeforeFailure,
        shrinkAttempts: report.shrinkAttempts,
        failureReason: report.failureReason.description
      )

      try? persistence.save(persisted)
    }
  }

  // MARK: - Formatting

  /// Formats a failure report as a message string.
  ///
  /// - Parameter report: The failure report.
  /// - Returns: Formatted message string.
  public func formatMessage(_ report: FailureReport) -> String {
    if verbose {
      return formatVerboseMessage(report)
    } else {
      return formatCompactMessage(report)
    }
  }

  /// Formats a compact failure message.
  private func formatCompactMessage(_ report: FailureReport) -> String {
    var message = """
      Property failed after \(report.iterationsBeforeFailure) tests (\(report.failureReason))

      Counterexample: \(report.shrunkValue)

      Seed: \(report.seed.rawValue)
      To reproduce: \(report.reproductionCommand)
      """

    if let classificationReport = report.classificationReport, !classificationReport.isEmpty {
      message += "\n\n" + classificationReport
    }

    return message
  }

  /// Formats a verbose failure message.
  private func formatVerboseMessage(_ report: FailureReport) -> String {
    var message = """
      ╔══════════════════════════════════════════════════════════════════════════════╗
      ║                           PROPERTY TEST FAILURE                              ║
      ╠══════════════════════════════════════════════════════════════════════════════╣
      ║ Test: \(report.testName)
      ║ Failure reason: \(report.failureReason)
      ╠══════════════════════════════════════════════════════════════════════════════╣
      ║ COUNTEREXAMPLE (after shrinking):
      ║   \(report.shrunkValue)
      ║
      ║ Original failing value:
      ║   \(report.originalValue)
      ╠══════════════════════════════════════════════════════════════════════════════╣
      ║ Statistics:
      ║   Iterations before failure: \(report.iterationsBeforeFailure)
      ║   Shrink attempts: \(report.shrinkAttempts)
      ║   Successful shrinks: \(report.successfulShrinks)
      ║   Total time: \(String(format: "%.3f", report.totalTime))s
      """

    // Add shrinking metrics section if metrics are available
    let metrics = report.computedShrinkMetrics
    if metrics.reductionPercentage > 0 || metrics.duration > 0 {
      message += "\n" + metrics.formatAsBoxSection()
    }

    message += "\n╠══════════════════════════════════════════════════════════════════════════════╣"
    message += "\n║ REPRODUCTION:"
    message += "\n║   Seed: \(report.seed.rawValue)"
    message += "\n║   Command: \(report.reproductionCommand)"
    message += "\n║   Environment: \(report.reproductionEnvVar)"

    if let classificationReport = report.classificationReport, !classificationReport.isEmpty {
      message +=
        "\n╠══════════════════════════════════════════════════════════════════════════════╣\n"
      message += "║ CLASSIFICATION:\n"
      // Indent classification report
      let lines = classificationReport.split(separator: "\n")
      for line in lines {
        message += "║   \(line)\n"
      }
    }

    message += "╚══════════════════════════════════════════════════════════════════════════════╝"

    return message
  }
}


// MARK: - Report Builder

/// Builder for creating failure reports with fluent API.
public final class FailureReportBuilder: @unchecked Sendable {
  private var testName: String = "unknown"
  private var seed = Seed.random
  private var originalValue: String = ""
  private var shrunkValue: String = ""
  private var iterations: Int = 0
  private var shrinkAttempts: Int = 0
  private var successfulShrinks: Int = 0
  private var failureReason: FailureReason = .predicateFailed
  private var totalTime: TimeInterval = 0

  public init() {}

  @discardableResult
  public func testName(_ name: String) -> Self {
    self.testName = name
    return self
  }

  @discardableResult
  public func seed(_ seed: Seed) -> Self {
    self.seed = seed
    return self
  }

  @discardableResult
  public func originalValue<T>(_ value: T) -> Self {
    self.originalValue = String(describing: value)
    return self
  }

  @discardableResult
  public func shrunkValue<T>(_ value: T) -> Self {
    self.shrunkValue = String(describing: value)
    return self
  }

  @discardableResult
  public func iterations(_ count: Int) -> Self {
    self.iterations = count
    return self
  }

  @discardableResult
  public func shrinking(attempts: Int, successful: Int) -> Self {
    self.shrinkAttempts = attempts
    self.successfulShrinks = successful
    return self
  }

  @discardableResult
  public func reason(_ reason: FailureReason) -> Self {
    self.failureReason = reason
    return self
  }

  @discardableResult
  public func time(_ time: TimeInterval) -> Self {
    self.totalTime = time
    return self
  }

  private var shrinkMetricsValue: ShrinkMetrics?

  @discardableResult
  public func shrinkMetrics(_ metrics: ShrinkMetrics) -> Self {
    self.shrinkMetricsValue = metrics
    return self
  }

  public func build() -> FailureReport {
    FailureReport(
      testName: testName,
      seed: seed,
      originalValue: originalValue,
      shrunkValue: shrunkValue,
      iterationsBeforeFailure: iterations,
      shrinkAttempts: shrinkAttempts,
      successfulShrinks: successfulShrinks,
      failureReason: failureReason,
      totalTime: totalTime,
      shrinkMetrics: shrinkMetricsValue
    )
  }
}

// MARK: - ClassifyingPropertyResult Integration

extension FailureReport {
  /// Create a failure report from a classifying property result.
  ///
  /// Includes classification data in the failure output when available.
  ///
  /// - Parameters:
  ///   - result: The classifying property result containing failure info
  ///   - config: Property configuration
  /// - Returns: A FailureReport if the result is a failure, nil otherwise
  public static func from<T>(
    _ result: ClassifyingPropertyResult<T>,
    config: PropertyConfig
  ) -> FailureReport? {
    guard
      case .failure(let counterexample, let iterations, let shrunk, let reason, let seed) =
        result.result
    else {
      return nil
    }

    return FailureReport(
      testName: "ClassifyingProperty",
      seed: seed,
      originalValue: String(describing: counterexample),
      shrunkValue: String(describing: shrunk),
      iterationsBeforeFailure: iterations,
      shrinkAttempts: 0,
      successfulShrinks: 0,
      failureReason: reason,
      totalTime: 0,
      classificationReport: result.classification.formatForFailure(),
      shrinkMetrics: nil
    )
  }
}
