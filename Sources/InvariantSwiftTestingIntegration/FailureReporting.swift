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
    classificationReport: String? = nil
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
  }

  /// Command to reproduce this failure.
  ///
  /// Provides the seed value to reproduce via `@PropertyTest(seed:)`.
  public var reproductionCommand: String {
    "swift test --filter \(testName)  # seed: \(seed.rawValue)"
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
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    recordFailure(report, labels: [], file: file, line: line)
  }

  /// Records a failure with additional property metadata for attachment-backed diagnostics.
  public func recordFailure(
    _ report: FailureReport,
    labels: [String],
    replayFailureID: UUID? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    recordPropertyFailureIssue(
      report,
      context: PropertyIssueContext(
        labels: labels,
        file: file,
        line: line,
        replayFailureID: replayFailureID
      )
    )
  }

  /// Records a failure and optionally persists it.
  ///
  /// - Parameters:
  ///   - report: The failure report.
  ///   - persist: Whether to also save to disk.
  public func recordFailure(_ report: FailureReport, persist: Bool) {
    recordFailure(report)

    if persist, let persistence = persistence {
      try? persistence.save(PersistedFailure(report: report))
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
      ╠══════════════════════════════════════════════════════════════════════════════╣
      ║ REPRODUCTION:
      ║   Seed: \(report.seed.rawValue)
      ║   Command: \(report.reproductionCommand)
      """

    let separator =
      "╠══════════════════════════════════════════════════════════════════════════════╣"
    let footer =
      "╚══════════════════════════════════════════════════════════════════════════════╝"

    if let classificationReport = report.classificationReport, !classificationReport.isEmpty {
      message += "\n\(separator)\n"
      message += "║ CLASSIFICATION:\n"
      let lines = classificationReport.split(separator: "\n")
      for line in lines {
        message += "║   \(line)\n"
      }
    }

    message += footer

    return message
  }
}


// MARK: - Report Builder

/// Builder for creating failure reports with fluent API.
public struct FailureReportBuilder: Sendable {
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
  public func testName(_ name: String) -> FailureReportBuilder {
    var copy = self
    copy.testName = name
    return copy
  }

  @discardableResult
  public func seed(_ seed: Seed) -> FailureReportBuilder {
    var copy = self
    copy.seed = seed
    return copy
  }

  @discardableResult
  public func originalValue<T>(_ value: T) -> FailureReportBuilder {
    var copy = self
    copy.originalValue = String(describing: value)
    return copy
  }

  @discardableResult
  public func shrunkValue<T>(_ value: T) -> FailureReportBuilder {
    var copy = self
    copy.shrunkValue = String(describing: value)
    return copy
  }

  @discardableResult
  public func iterations(_ count: Int) -> FailureReportBuilder {
    var copy = self
    copy.iterations = count
    return copy
  }

  @discardableResult
  public func shrinking(attempts: Int, successful: Int) -> FailureReportBuilder {
    var copy = self
    copy.shrinkAttempts = attempts
    copy.successfulShrinks = successful
    return copy
  }

  @discardableResult
  public func reason(_ reason: FailureReason) -> FailureReportBuilder {
    var copy = self
    copy.failureReason = reason
    return copy
  }

  @discardableResult
  public func time(_ time: TimeInterval) -> FailureReportBuilder {
    var copy = self
    copy.totalTime = time
    return copy
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
      totalTime: totalTime
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
      shrinkAttempts: 0,  // Not available in ClassifyingPropertyResult
      successfulShrinks: 0,  // Not available in ClassifyingPropertyResult
      failureReason: reason,
      totalTime: 0,  // Not available in ClassifyingPropertyResult
      classificationReport: result.classification.formatForFailure()
    )
  }
}
