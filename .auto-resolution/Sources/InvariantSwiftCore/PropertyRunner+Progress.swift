// PropertyRunner+Progress.swift
// InvariantSwift
//
// Progress tracking for long-running property tests.

import Foundation

// MARK: - Progress Interval

/// Configuration for progress reporting intervals.
///
/// Controls when progress updates are emitted during property test execution.
/// Progress can be throttled by iteration count, elapsed time, or adaptively.
public enum ProgressInterval: Sendable, Equatable {
  /// Report progress every N iterations.
  case iterations(Int)

  /// Report progress every N seconds.
  case seconds(TimeInterval)

  /// Adaptive mode: reports every 1000 iterations OR 5 seconds, whichever first.
  case adaptive
}

// MARK: - Progress Reporter

/// Tracks and emits progress updates during property test execution.
///
/// Uses time-based throttling to avoid overwhelming output during long tests.
/// Progress is suppressed for fast tests (< 5 seconds) to reduce noise.
///
/// ## Example
///
/// ```swift
/// var reporter = ProgressReporter(totalIterations: 10000, interval: .adaptive)
///
/// for iteration in 1...10000 {
///   // ... test execution ...
///   reporter.recordIteration(iteration)
/// }
/// ```
public struct ProgressReporter: Sendable {
  /// Total number of iterations expected.
  public let totalIterations: Int

  /// Minimum time interval between progress reports (seconds).
  private let minInterval: TimeInterval

  /// Minimum iteration interval between progress reports.
  private let minIterations: Int

  /// Time of last progress report.
  private var lastReportTime: CFAbsoluteTime

  /// Iteration number of last progress report.
  private var lastReportedIteration: Int

  /// Start time of test execution.
  private let startTime: CFAbsoluteTime

  /// Creates a new progress reporter.
  ///
  /// - Parameters:
  ///   - totalIterations: Total number of iterations expected
  ///   - interval: Reporting interval configuration
  public init(totalIterations: Int, interval: ProgressInterval) {
    self.totalIterations = totalIterations
    self.startTime = CFAbsoluteTimeGetCurrent()
    self.lastReportTime = self.startTime
    self.lastReportedIteration = 0

    switch interval {
    case .iterations(let n):
      self.minIterations = n
      self.minInterval = 0  // No time-based throttling

    case .seconds(let t):
      self.minIterations = 0  // No iteration-based throttling
      self.minInterval = t

    case .adaptive:
      self.minIterations = 1000
      self.minInterval = 5.0
    }
  }

  /// Records an iteration and potentially emits progress.
  ///
  /// Progress is emitted if sufficient time or iterations have elapsed since
  /// the last report, based on the configured interval.
  ///
  /// - Parameter current: Current iteration number (1-indexed)
  public mutating func recordIteration(_ current: Int) {
    let now = CFAbsoluteTimeGetCurrent()
    let timeSinceLastReport = now - lastReportTime
    let iterationsSinceLastReport = current - lastReportedIteration

    let shouldReport: Bool
    if minInterval > 0 && minIterations > 0 {
      // Adaptive: report if either threshold met
      shouldReport =
        timeSinceLastReport >= minInterval || iterationsSinceLastReport >= minIterations
    } else if minInterval > 0 {
      // Time-based only
      shouldReport = timeSinceLastReport >= minInterval
    } else if minIterations > 0 {
      // Iteration-based only
      shouldReport = iterationsSinceLastReport >= minIterations
    } else {
      // No throttling (shouldn't happen, but safe default)
      shouldReport = false
    }

    if shouldReport {
      emit(current: current, elapsed: now - startTime)
      lastReportTime = now
      lastReportedIteration = current
    }
  }

  /// Emits a progress update to stdout.
  ///
  /// Format: "Progress: {current}/{total} ({percent}%) - {rate} tests/sec"
  ///
  /// - Parameters:
  ///   - current: Current iteration number
  ///   - elapsed: Elapsed time since test start (seconds)
  private func emit(current: Int, elapsed: TimeInterval) {
    let percent = Double(current) / Double(totalIterations) * 100.0
    let rate = elapsed > 0 ? Double(current) / elapsed : 0.0

    // swiftlint:disable:next no_print
    print(
      String(
        format: "Progress: %d/%d (%.1f%%) - %.0f tests/sec",
        current,
        totalIterations,
        percent,
        rate
      )
    )
  }

  /// Determines if progress should be suppressed for a fast test.
  ///
  /// Tests completing in under 5 seconds don't show progress to avoid noise.
  ///
  /// - Parameter testDuration: Total test duration in seconds
  /// - Returns: True if progress should be suppressed
  public func shouldSuppressProgress(testDuration: TimeInterval) -> Bool {
    testDuration < 5.0
  }
}
