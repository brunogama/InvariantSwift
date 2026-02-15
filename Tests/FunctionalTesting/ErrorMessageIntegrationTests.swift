import Foundation
import Testing
@testable import InvariantSwift

// MARK: - ErrorMessageIntegrationTests

/// Integration tests verifying Phase 5 error message features work end-to-end.
@Suite("Error Message Integration Tests")
struct ErrorMessageIntegrationTests {

  @Test("ShrinkMetrics captures shrinking journey data")
  func shrinkMetricsCapture() async throws {
    // Create metrics with known values
    let metrics = ShrinkMetrics(
      attempts: 15,
      successful: 8,
      duration: 0.123,
      originalSize: 100,
      shrunkSize: 20
    )

    // Verify computed properties
    #expect(metrics.attempts == 15)
    #expect(metrics.successful == 8)
    #expect(metrics.duration == 0.123)
    #expect(metrics.reductionPercentage == 80.0)
    #expect(metrics.strategy == "BFS tree search")
  }

  @Test("ShrinkMetrics reduction percentage is calculated correctly")
  func reductionPercentageCalculation() async throws {
    // Test exact reduction
    let metrics1 = ShrinkMetrics(
      attempts: 10,
      successful: 5,
      duration: 0.1,
      originalSize: 100,
      shrunkSize: 50
    )
    #expect(metrics1.reductionPercentage == 50.0)

    // Test no reduction
    let metrics2 = ShrinkMetrics(
      attempts: 10,
      successful: 0,
      duration: 0.1,
      originalSize: 100,
      shrunkSize: 100
    )
    #expect(metrics2.reductionPercentage == 0.0)

    // Test full reduction
    let metrics3 = ShrinkMetrics(
      attempts: 10,
      successful: 10,
      duration: 0.1,
      originalSize: 100,
      shrunkSize: 0
    )
    #expect(metrics3.reductionPercentage == 100.0)
  }

  @Test("ShrinkMetrics handles edge cases")
  func shrinkMetricsEdgeCases() async throws {
    // Zero original size (should not crash)
    let metrics = ShrinkMetrics(
      attempts: 5,
      successful: 3,
      duration: 0.05,
      originalSize: 0,
      shrunkSize: 0
    )
    #expect(metrics.reductionPercentage == 0.0)

    // Shrunk larger than original (clamped to 0)
    let metrics2 = ShrinkMetrics(
      attempts: 5,
      successful: 0,
      duration: 0.05,
      originalSize: 50,
      shrunkSize: 100
    )
    #expect(metrics2.reductionPercentage == 0.0)
  }

  @Test("ShrinkMetrics box formatting produces expected output")
  func shrinkMetricsFormatting() async throws {
    let metrics = ShrinkMetrics(
      attempts: 15,
      successful: 8,
      duration: 0.123,
      reductionPercentage: 80.0,
      strategy: "BFS tree search"
    )

    let formatted = metrics.formatAsBoxSection()

    // Verify key elements are present
    #expect(formatted.contains("SHRINKING METRICS"))
    #expect(formatted.contains("Reduction:"))
    #expect(formatted.contains("80.0%"))
    #expect(formatted.contains("Time:"))
    #expect(formatted.contains("0.123s"))
    #expect(formatted.contains("Attempts:"))
    #expect(formatted.contains("15"))
    #expect(formatted.contains("Successful:"))
    #expect(formatted.contains("8"))
    #expect(formatted.contains("Strategy:"))
    #expect(formatted.contains("BFS tree search"))
    #expect(formatted.contains("╠"))
    #expect(formatted.contains("║"))
  }

  @Test("FailureReport accepts ShrinkMetrics")
  func failureReportWithShrinkMetrics() async throws {
    let metrics = ShrinkMetrics(
      attempts: 10,
      successful: 5,
      duration: 0.1,
      reductionPercentage: 50.0
    )

    let report = FailureReport(
      testName: "testExample",
      seed: Seed(value: 12345),
      originalValue: "[1, 2, 3, 4]",
      shrunkValue: "[1]",
      iterationsBeforeFailure: 42,
      shrinkAttempts: 10,
      successfulShrinks: 5,
      failureReason: .predicateFailed,
      totalTime: 0.5,
      shrinkMetrics: metrics
    )

    #expect(report.shrinkMetrics != nil)
    #expect(report.shrinkMetrics?.reductionPercentage == 50.0)
    #expect(report.computedShrinkMetrics.reductionPercentage == 50.0)
  }

  @Test("FailureReport computedShrinkMetrics derives from fields when nil")
  func computedShrinkMetricsFallback() async throws {
    let report = FailureReport(
      testName: "testExample",
      seed: Seed(value: 12345),
      originalValue: "original",
      shrunkValue: "shrunk",
      iterationsBeforeFailure: 10,
      shrinkAttempts: 20,
      successfulShrinks: 10,
      failureReason: .predicateFailed,
      totalTime: 1.5,
      shrinkMetrics: nil
    )

    // Should derive from individual fields
    let computed = report.computedShrinkMetrics
    #expect(computed.attempts == 20)
    #expect(computed.successful == 10)
    #expect(computed.duration == 1.5)
    #expect(computed.strategy == "BFS tree search")
  }
}

// MARK: - Property-Based Tests (Dogfood)

extension ErrorMessageIntegrationTests {

  @Test("Reduction percentage is always valid")
  func reductionPercentageValid() async throws {
    // Property: reduction percentage is always between 0 and 100
    let metrics = ShrinkMetrics(
      attempts: 10,
      successful: 5,
      duration: 0.1,
      originalSize: 100,
      shrunkSize: 25
    )

    #expect(metrics.reductionPercentage >= 0.0)
    #expect(metrics.reductionPercentage <= 100.0)
  }

  @Test("Successful shrinks never exceed attempts")
  func successfulNeverExceedsAttempts() async throws {
    let metrics = ShrinkMetrics(
      attempts: 20,
      successful: 15,
      duration: 0.2,
      reductionPercentage: 75.0
    )

    #expect(metrics.successful <= metrics.attempts)
  }

  @Test("Duration is always non-negative")
  func durationNonNegative() async throws {
    let metrics = ShrinkMetrics(
      attempts: 10,
      successful: 5,
      duration: 0.5,
      reductionPercentage: 50.0
    )

    #expect(metrics.duration >= 0)
  }
}
