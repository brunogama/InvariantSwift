// TestStatistics.swift
// InvariantSwift
//
// Metrics collection for property test runs.
// Implements Task 2.8 from the roadmap.

import Foundation

// MARK: - Test Run Statistics

/// Statistics for a single property test run.
///
/// Captures metrics about the test execution including generation count,
/// shrinking details, and timing information.
public struct TestRunStatistics: Sendable, Codable {
  /// Name or identifier of the property test.
  public let testName: String

  /// Number of test cases generated.
  public let generationCount: Int

  /// Number of shrink attempts performed.
  public let shrinkAttempts: Int

  /// Number of successful shrinks (found smaller counterexample).
  public let successfulShrinks: Int

  /// Total time spent generating values (seconds).
  public let generationTime: TimeInterval

  /// Total time spent shrinking (seconds).
  public let shrinkingTime: TimeInterval

  /// Total test execution time (seconds).
  public let totalTime: TimeInterval

  /// Whether the property passed all tests.
  public let passed: Bool

  /// Seed used for this run (for reproducibility).
  public let seed: UInt64?

  /// Timestamp when the test started.
  public let startTime: Date

  /// Average time per generation (milliseconds).
  public var averageGenerationTimeMs: Double {
    guard generationCount > 0 else { return 0 }
    return (generationTime / Double(generationCount)) * 1000
  }

  /// Average time per shrink attempt (milliseconds).
  public var averageShrinkTimeMs: Double {
    guard shrinkAttempts > 0 else { return 0 }
    return (shrinkingTime / Double(shrinkAttempts)) * 1000
  }

  /// Shrink success rate (percentage).
  public var shrinkSuccessRate: Double {
    guard shrinkAttempts > 0 else { return 0 }
    return (Double(successfulShrinks) / Double(shrinkAttempts)) * 100
  }

  /// Creates a new test run statistics record.
  public init(
    testName: String,
    generationCount: Int,
    shrinkAttempts: Int,
    successfulShrinks: Int,
    generationTime: TimeInterval,
    shrinkingTime: TimeInterval,
    totalTime: TimeInterval,
    passed: Bool,
    seed: UInt64?,
    startTime: Date
  ) {
    self.testName = testName
    self.generationCount = generationCount
    self.shrinkAttempts = shrinkAttempts
    self.successfulShrinks = successfulShrinks
    self.generationTime = generationTime
    self.shrinkingTime = shrinkingTime
    self.totalTime = totalTime
    self.passed = passed
    self.seed = seed
    self.startTime = startTime
  }
}

// MARK: - Statistics Collector

/// Collects and aggregates statistics during property test execution.
///
/// Use `StatisticsCollector` to track metrics as a property test runs.
/// After the test completes, call `finalize()` to get the final statistics.
///
/// ## Example Usage
///
/// ```swift
/// let collector = StatisticsCollector(testName: "testSortingIdempotent", seed: 42)
///
/// for _ in 0..<100 {
///     collector.recordGeneration()
///     let value = generator.sample()
///     // ... run test ...
/// }
///
/// // If failure found, record shrinking
/// for _ in 0..<20 {
///     collector.recordShrinkAttempt(successful: true)
/// }
///
/// collector.markComplete(passed: false)
/// let stats = collector.finalize()
// swiftlint:disable:next no_print
/// print(stats.formatted())
/// ```
public final class StatisticsCollector: @unchecked Sendable {

  // MARK: - Properties

  private let testName: String
  private let seed: UInt64?
  private let startTime: Date

  private var generationCount: Int = 0
  private var shrinkAttempts: Int = 0
  private var successfulShrinks: Int = 0

  private var generationStartTime: Date?
  private var shrinkingStartTime: Date?

  private var generationTime: TimeInterval = 0
  private var shrinkingTime: TimeInterval = 0

  private var endTime: Date?
  private var passed: Bool?

  private let lock = NSLock()

  // MARK: - Initialization

  /// Creates a new statistics collector.
  ///
  /// - Parameters:
  ///   - testName: Name of the property test.
  ///   - seed: Optional seed used for reproducibility.
  public init(testName: String, seed: UInt64? = nil) {
    self.testName = testName
    self.seed = seed
    self.startTime = Date()
  }

  // MARK: - Recording

  /// Records that a value was generated.
  public func recordGeneration() {
    lock.lock()
    defer { lock.unlock() }
    generationCount += 1
  }

  /// Records the start of generation phase.
  public func startGenerationPhase() {
    lock.lock()
    defer { lock.unlock() }
    generationStartTime = Date()
  }

  /// Records the end of generation phase.
  public func endGenerationPhase() {
    lock.lock()
    defer { lock.unlock() }
    if let start = generationStartTime {
      generationTime += Date().timeIntervalSince(start)
      generationStartTime = nil
    }
  }

  /// Records a shrink attempt.
  ///
  /// - Parameter successful: Whether the shrink found a smaller counterexample.
  public func recordShrinkAttempt(successful: Bool) {
    lock.lock()
    defer { lock.unlock() }
    shrinkAttempts += 1
    if successful {
      successfulShrinks += 1
    }
  }

  /// Records the start of shrinking phase.
  public func startShrinkingPhase() {
    lock.lock()
    defer { lock.unlock() }
    shrinkingStartTime = Date()
  }

  /// Records the end of shrinking phase.
  public func endShrinkingPhase() {
    lock.lock()
    defer { lock.unlock() }
    if let start = shrinkingStartTime {
      shrinkingTime += Date().timeIntervalSince(start)
      shrinkingStartTime = nil
    }
  }

  /// Marks the test as complete.
  ///
  /// - Parameter passed: Whether the property passed all tests.
  public func markComplete(passed: Bool) {
    lock.lock()
    defer { lock.unlock() }
    self.passed = passed
    self.endTime = Date()
  }

  /// Finalizes and returns the collected statistics.
  ///
  /// - Returns: The finalized statistics record.
  public func finalize() -> TestRunStatistics {
    lock.lock()
    defer { lock.unlock() }

    let end = endTime ?? Date()

    return TestRunStatistics(
      testName: testName,
      generationCount: generationCount,
      shrinkAttempts: shrinkAttempts,
      successfulShrinks: successfulShrinks,
      generationTime: generationTime,
      shrinkingTime: shrinkingTime,
      totalTime: end.timeIntervalSince(startTime),
      passed: passed ?? true,
      seed: seed,
      startTime: startTime
    )
  }
}

// MARK: - Aggregate Statistics

/// Aggregated statistics across multiple property test runs.
public struct AggregateStatistics: Sendable, Codable {
  /// Individual test statistics.
  public let tests: [TestRunStatistics]

  /// Total number of tests run.
  public var totalTests: Int { tests.count }

  /// Number of passing tests.
  public var passingTests: Int { tests.filter(\.passed).count }

  /// Number of failing tests.
  public var failingTests: Int { tests.filter { !$0.passed }.count }

  /// Total generations across all tests.
  public var totalGenerations: Int {
    tests.reduce(0) { $0 + $1.generationCount }
  }

  /// Total shrink attempts across all tests.
  public var totalShrinkAttempts: Int {
    tests.reduce(0) { $0 + $1.shrinkAttempts }
  }

  /// Total execution time (seconds).
  public var totalTime: TimeInterval {
    tests.reduce(0) { $0 + $1.totalTime }
  }

  /// Average time per test (seconds).
  public var averageTestTime: TimeInterval {
    guard !tests.isEmpty else { return 0 }
    return totalTime / Double(tests.count)
  }

  /// Creates aggregate statistics from a list of test runs.
  public init(tests: [TestRunStatistics]) {
    self.tests = tests
  }
}

// MARK: - Output Formatting

extension TestRunStatistics {
  /// Formats statistics as a human-readable string.
  public func formatted() -> String {
    let status = passed ? "✅ PASSED" : "❌ FAILED"
    let seedStr = seed.map { "Seed: \($0)" } ?? "Seed: random"

    return """
      ┌─────────────────────────────────────────────────────────────┐
      │ \(testName.padding(toLength: 57, withPad: " ", startingAt: 0)) │
      ├─────────────────────────────────────────────────────────────┤
      │ Status: \(status.padding(toLength: 51, withPad: " ", startingAt: 0)) │
      │ \(seedStr.padding(toLength: 59, withPad: " ", startingAt: 0)) │
      ├─────────────────────────────────────────────────────────────┤
      │ Generations: \(String(generationCount).padding(toLength: 46, withPad: " ", startingAt: 0)) │
      │ Shrink attempts: \(String(shrinkAttempts).padding(toLength: 42, withPad: " ", startingAt: 0)) │
      │ Successful shrinks: \(String(successfulShrinks).padding(toLength: 39, withPad: " ", startingAt: 0)) │
      ├─────────────────────────────────────────────────────────────┤
      │ Generation time: \(String(format: "%.3fs", generationTime).padding(toLength: 42, withPad: " ", startingAt: 0)) │
      │ Shrinking time: \(String(format: "%.3fs", shrinkingTime).padding(toLength: 43, withPad: " ", startingAt: 0)) │
      │ Total time: \(String(format: "%.3fs", totalTime).padding(toLength: 47, withPad: " ", startingAt: 0)) │
      ├─────────────────────────────────────────────────────────────┤
      │ Avg gen time: \(String(format: "%.3fms", averageGenerationTimeMs).padding(toLength: 45, withPad: " ", startingAt: 0)) │
      │ Avg shrink time: \(String(format: "%.3fms", averageShrinkTimeMs).padding(toLength: 42, withPad: " ", startingAt: 0)) │
      └─────────────────────────────────────────────────────────────┘
      """
  }

  /// Formats statistics as a compact one-liner.
  public func compact() -> String {
    let status = passed ? "✅" : "❌"
    return
      "\(status) \(testName): \(generationCount) gens, \(shrinkAttempts) shrinks, \(String(format: "%.2fs", totalTime))"
  }

  /// Converts to JSON string.
  public func toJSON() -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    guard let data = try? encoder.encode(self) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

extension AggregateStatistics {
  /// Formats aggregate statistics as a summary.
  public func formatted() -> String {
    let passRate = totalTests > 0 ? (Double(passingTests) / Double(totalTests)) * 100 : 0

    return """
      ══════════════════════════════════════════════════════════════
                           TEST RUN SUMMARY
      ══════════════════════════════════════════════════════════════
       Tests: \(totalTests) (\(passingTests) passed, \(failingTests) failed)
       Pass rate: \(String(format: "%.1f%%", passRate))
       Total generations: \(totalGenerations)
       Total shrink attempts: \(totalShrinkAttempts)
       Total time: \(String(format: "%.3fs", totalTime))
       Average test time: \(String(format: "%.3fs", averageTestTime))
      ══════════════════════════════════════════════════════════════
      """
  }

  /// Converts to JSON string.
  public func toJSON() -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    guard let data = try? encoder.encode(self) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}
