import Foundation
import Testing
@testable import InvariantSwift

// MARK: - FailureMessageFormattingTests

/// Tests verifying failure message formatting and structure.
@Suite("Failure Message Formatting Tests")
struct FailureMessageFormattingTests {

  @Test("Verbose format includes all sections")
  func verboseFormatIncludesAllSections() async throws {
    let report = FailureReport(
      testName: "testArraySort",
      seed: Seed(value: 12345),
      originalValue: "[3, 2, 1]",
      shrunkValue: "[2, 1]",
      iterationsBeforeFailure: 42,
      shrinkAttempts: 15,
      successfulShrinks: 8,
      failureReason: .predicateFailed,
      totalTime: 0.5
    )

    let reporter = FailureReporter(verbose: true)
    let message = reporter.formatMessage(report)

    // Verify all sections are present
    #expect(message.contains("PROPERTY TEST FAILURE"))
    #expect(message.contains("testArraySort"))
    #expect(message.contains("COUNTEREXAMPLE"))
    #expect(message.contains("[2, 1]"))  // shrunk value
    #expect(message.contains("Original failing value"))
    #expect(message.contains("[3, 2, 1]"))  // original value
    #expect(message.contains("Statistics"))
    #expect(message.contains("Iterations before failure"))
    #expect(message.contains("42"))
    #expect(message.contains("REPRODUCTION"))
    #expect(message.contains("Seed:"))
    #expect(message.contains("12345"))
  }

  @Test("Compact format is concise")
  func compactFormatIsConcise() async throws {
    let report = FailureReport(
      testName: "testSort",
      seed: Seed(value: 42),
      originalValue: "[3, 2, 1]",
      shrunkValue: "[2, 1]",
      iterationsBeforeFailure: 10,
      shrinkAttempts: 5,
      successfulShrinks: 3,
      failureReason: .predicateFailed,
      totalTime: 0.1
    )

    let reporter = FailureReporter(verbose: false)
    let message = reporter.formatMessage(report)

    // Compact format should be shorter
    #expect(message.contains("Property failed after 10 tests"))
    #expect(message.contains("Counterexample:"))
    #expect(message.contains("[2, 1]"))
    #expect(message.contains("Seed: 42"))

    // Should NOT have box-drawing characters
    #expect(!message.contains("╔"))
    #expect(!message.contains("╚"))
  }

  @Test("Box drawing characters align correctly")
  func boxDrawingCharactersAlign() async throws {
    let report = FailureReport(
      testName: "testExample",
      seed: Seed(value: 1),
      originalValue: "original",
      shrunkValue: "shrunk",
      iterationsBeforeFailure: 1,
      shrinkAttempts: 1,
      successfulShrinks: 1,
      failureReason: .predicateFailed,
      totalTime: 0.01
    )

    let reporter = FailureReporter(verbose: true)
    let message = reporter.formatMessage(report)

    // Verify box-drawing characters
    #expect(message.contains("╔"))
    #expect(message.contains("╚"))
    #expect(message.contains("╠"))
    #expect(message.contains("║"))
    #expect(message.contains("═"))
  }

  @Test("ShrinkMetrics format shows correct precision")
  func shrinkMetricsFormatPrecision() async throws {
    let metrics = ShrinkMetrics(
      attempts: 15,
      successful: 8,
      duration: 0.123456,
      reductionPercentage: 80.123,
      strategy: "BFS"
    )

    let formatted = metrics.formatAsBoxSection()

    // Should have 1 decimal place for percentage
    #expect(
      formatted.contains("80.1%") || formatted.contains("80.12%") || formatted.contains("80.123%")
    )

    // Should have 3 decimal places for time
    #expect(formatted.contains("0.123s"))
  }

  @Test("FailureReport reproduction command is formatted correctly")
  func reproductionCommandFormat() async throws {
    let report = FailureReport(
      testName: "testMyFeature",
      seed: Seed(value: 12345),
      originalValue: "original",
      shrunkValue: "shrunk",
      iterationsBeforeFailure: 10,
      shrinkAttempts: 5,
      successfulShrinks: 3,
      failureReason: .predicateFailed,
      totalTime: 0.1
    )

    let command = report.reproductionCommand

    #expect(command.contains("swift test"))
    #expect(command.contains("--filter"))
    #expect(command.contains("testMyFeature"))
  }

  @Test("FailureReport environment variable is formatted correctly")
  func reproductionEnvVarFormat() async throws {
    let report = FailureReport(
      testName: "test",
      seed: Seed(value: 99999),
      originalValue: "original",
      shrunkValue: "shrunk",
      iterationsBeforeFailure: 1,
      shrinkAttempts: 1,
      successfulShrinks: 1,
      failureReason: .predicateFailed,
      totalTime: 0.1
    )

    let envVar = report.reproductionEnvVar

    #expect(envVar.contains("INVARIANT_SWIFT_SEED"))
    #expect(envVar.contains("99999"))
  }

  @Test("FailureReport with shrinkMetrics includes metrics in output")
  func failureReportWithShrinkMetrics() async throws {
    let metrics = ShrinkMetrics(
      attempts: 20,
      successful: 10,
      duration: 0.2,
      reductionPercentage: 75.0
    )

    let report = FailureReport(
      testName: "testMetrics",
      seed: Seed(value: 1),
      originalValue: "original",
      shrunkValue: "shrunk",
      iterationsBeforeFailure: 5,
      shrinkAttempts: 20,
      successfulShrinks: 10,
      failureReason: .predicateFailed,
      totalTime: 0.5,
      shrinkMetrics: metrics
    )

    let reporter = FailureReporter(verbose: true)
    let message = reporter.formatMessage(report)

    // Should include shrinking metrics section
    #expect(message.contains("SHRINKING METRICS") || message.contains("Reduction:"))
  }
}

// MARK: - Different Data Types Formatting

extension FailureMessageFormattingTests {

  @Test("Int values format correctly")
  func intValuesFormat() async throws {
    let report = FailureReport(
      testName: "testInt",
      seed: Seed(value: 1),
      originalValue: String(describing: 42),
      shrunkValue: String(describing: 0),
      iterationsBeforeFailure: 1,
      shrinkAttempts: 1,
      successfulShrinks: 1,
      failureReason: .predicateFailed,
      totalTime: 0.01
    )

    #expect(report.originalValue == "42")
    #expect(report.shrunkValue == "0")
  }

  @Test("String values format correctly")
  func stringValuesFormat() async throws {
    let report = FailureReport(
      testName: "testString",
      seed: Seed(value: 1),
      originalValue: String(describing: "hello world"),
      shrunkValue: String(describing: "h"),
      iterationsBeforeFailure: 1,
      shrinkAttempts: 1,
      successfulShrinks: 1,
      failureReason: .predicateFailed,
      totalTime: 0.01
    )

    #expect(report.originalValue.contains("hello"))
    #expect(report.shrunkValue.contains("h"))
  }

  @Test("Array values format correctly")
  func arrayValuesFormat() async throws {
    let originalArray = [1, 2, 3, 4, 5]
    let shrunkArray = [1]

    let report = FailureReport(
      testName: "testArray",
      seed: Seed(value: 1),
      originalValue: String(describing: originalArray),
      shrunkValue: String(describing: shrunkArray),
      iterationsBeforeFailure: 1,
      shrinkAttempts: 1,
      successfulShrinks: 1,
      failureReason: .predicateFailed,
      totalTime: 0.01
    )

    #expect(report.originalValue.contains("1"))
    #expect(report.originalValue.contains("5"))
    #expect(report.shrunkValue.contains("1"))
  }
}
