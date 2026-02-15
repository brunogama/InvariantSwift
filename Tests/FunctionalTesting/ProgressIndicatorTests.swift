import Foundation
import Testing
@testable import InvariantSwift

// MARK: - ProgressIndicatorTests

/// Tests for progress indicator functionality.
@Suite("Progress Indicator Tests")
struct ProgressIndicatorTests {

  @Test("PropertyConfig can enable progress")
  func propertyConfigCanEnableProgress() async throws {
    let config = PropertyConfig(
      iterations: 100,
      showProgress: true,
      progressInterval: 1.0
    )

    #expect(config.showProgress == true)
    #expect(config.progressInterval == 1.0)
  }

  @Test("PropertyConfig can disable progress")
  func propertyConfigCanDisableProgress() async throws {
    let config = PropertyConfig(
      iterations: 100,
      showProgress: false
    )

    #expect(config.showProgress == false)
  }

  @Test("Default progress interval is reasonable")
  func defaultProgressInterval() async throws {
    let config = PropertyConfig.default()

    // Should have some default (exact value depends on implementation)
    #expect(config.progressInterval >= 0)
  }

  @Test("Progress configuration is stored correctly")
  func progressConfigurationStorage() async throws {
    let config = PropertyConfig(
      iterations: 500,
      showProgress: true,
      progressInterval: 2.5
    )

    // Verify all values are stored
    #expect(config.iterations == 500)
    #expect(config.showProgress == true)
    #expect(config.progressInterval == 2.5)
  }
}

// MARK: - Statistics Tests

extension ProgressIndicatorTests {

  @Test("TestStatistics can track iterations")
  func testStatisticsTracksIterations() async throws {
    var stats = TestStatistics()

    // Simulate iterations
    for i in 1...10 {
      stats.recordIteration(success: true)
      #expect(stats.iterations == i)
    }

    #expect(stats.iterations == 10)
    #expect(stats.successfulIterations == 10)
  }

  @Test("TestStatistics can track failures")
  func testStatisticsTracksFailures() async throws {
    var stats = TestStatistics()

    stats.recordIteration(success: true)
    stats.recordIteration(success: false)
    stats.recordIteration(success: true)

    #expect(stats.iterations == 3)
    #expect(stats.successfulIterations == 2)
    #expect(stats.failedIterations == 1)
  }

  @Test("TestStatistics duration is non-negative")
  func testStatisticsDurationNonNegative() async throws {
    let stats = TestStatistics()

    // Duration should be 0 or positive
    #expect(stats.totalDuration >= 0)
  }
}

// MARK: - TestStatistics Helper

/// Simple statistics tracker for testing.
private struct TestStatistics {
  private(set) var iterations: Int = 0
  private(set) var successfulIterations: Int = 0
  private(set) var failedIterations: Int = 0
  private let startTime: Date

  init() {
    self.startTime = Date()
  }

  mutating func recordIteration(success: Bool) {
    iterations += 1
    if success {
      successfulIterations += 1
    } else {
      failedIterations += 1
    }
  }

  var totalDuration: TimeInterval {
    Date().timeIntervalSince(startTime)
  }
}
