// TestStatisticsTests.swift
// InvariantSwift Tests
//
// Tests for the TestStatistics metrics collection system.

import Testing
import Foundation
@testable import InvariantSwift

@Suite("TestStatistics Tests")
struct TestStatisticsTests {

  // MARK: - Statistics Collector Tests

  @Test("Collector records generations")
  func testRecordGenerations() {
    let collector = StatisticsCollector(testName: "testExample", seed: 42)

    for _ in 0..<100 {
      collector.recordGeneration()
    }

    collector.markComplete(passed: true)
    let stats = collector.finalize()

    #expect(stats.generationCount == 100)
    #expect(stats.passed == true)
    #expect(stats.seed == 42)
  }

  @Test("Collector records shrink attempts")
  func testRecordShrinks() {
    let collector = StatisticsCollector(testName: "testShrinking")

    collector.recordShrinkAttempt(successful: true)
    collector.recordShrinkAttempt(successful: true)
    collector.recordShrinkAttempt(successful: false)
    collector.recordShrinkAttempt(successful: true)
    collector.recordShrinkAttempt(successful: false)

    collector.markComplete(passed: false)
    let stats = collector.finalize()

    #expect(stats.shrinkAttempts == 5)
    #expect(stats.successfulShrinks == 3)
    #expect(stats.shrinkSuccessRate == 60.0)
  }

  @Test("Collector tracks timing")
  func testTimingTracking() async throws {
    let collector = StatisticsCollector(testName: "testTiming")

    collector.startGenerationPhase()
    try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    collector.endGenerationPhase()

    collector.startShrinkingPhase()
    try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    collector.endShrinkingPhase()

    collector.markComplete(passed: true)
    let stats = collector.finalize()

    #expect(stats.generationTime > 0)
    #expect(stats.shrinkingTime > 0)
    #expect(stats.totalTime > 0)
  }

  // MARK: - Test Run Statistics Tests

  @Test("Statistics calculates averages correctly")
  func testAverageCalculations() {
    let stats = TestRunStatistics(
      testName: "testAverages",
      generationCount: 100,
      shrinkAttempts: 20,
      successfulShrinks: 15,
      generationTime: 0.5,  // 500ms for 100 gens = 5ms avg
      shrinkingTime: 0.2,  // 200ms for 20 shrinks = 10ms avg
      totalTime: 0.7,
      passed: true,
      seed: nil,
      startTime: Date()
    )

    #expect(stats.averageGenerationTimeMs == 5.0)
    #expect(stats.averageShrinkTimeMs == 10.0)
    #expect(stats.shrinkSuccessRate == 75.0)
  }

  @Test("Statistics handles zero counts")
  func testZeroCounts() {
    let stats = TestRunStatistics(
      testName: "testEmpty",
      generationCount: 0,
      shrinkAttempts: 0,
      successfulShrinks: 0,
      generationTime: 0,
      shrinkingTime: 0,
      totalTime: 0,
      passed: true,
      seed: nil,
      startTime: Date()
    )

    #expect(stats.averageGenerationTimeMs == 0)
    #expect(stats.averageShrinkTimeMs == 0)
    #expect(stats.shrinkSuccessRate == 0)
  }

  // MARK: - Aggregate Statistics Tests

  @Test("Aggregate statistics combines tests")
  func testAggregation() {
    let test1 = TestRunStatistics(
      testName: "test1",
      generationCount: 100,
      shrinkAttempts: 10,
      successfulShrinks: 5,
      generationTime: 0.5,
      shrinkingTime: 0.1,
      totalTime: 0.6,
      passed: true,
      seed: nil,
      startTime: Date()
    )

    let test2 = TestRunStatistics(
      testName: "test2",
      generationCount: 200,
      shrinkAttempts: 20,
      successfulShrinks: 10,
      generationTime: 1.0,
      shrinkingTime: 0.2,
      totalTime: 1.2,
      passed: false,
      seed: nil,
      startTime: Date()
    )

    let aggregate = AggregateStatistics(tests: [test1, test2])

    #expect(aggregate.totalTests == 2)
    #expect(aggregate.passingTests == 1)
    #expect(aggregate.failingTests == 1)
    #expect(aggregate.totalGenerations == 300)
    #expect(aggregate.totalShrinkAttempts == 30)
    #expect(abs(aggregate.totalTime - 1.8) < 0.001)
    #expect(abs(aggregate.averageTestTime - 0.9) < 0.001)
  }

  // MARK: - Output Formatting Tests

  @Test("Formatted output contains expected elements")
  func testFormattedOutput() {
    let stats = TestRunStatistics(
      testName: "testFormatting",
      generationCount: 100,
      shrinkAttempts: 10,
      successfulShrinks: 5,
      generationTime: 0.5,
      shrinkingTime: 0.1,
      totalTime: 0.6,
      passed: true,
      seed: 12345,
      startTime: Date()
    )

    let output = stats.formatted()

    #expect(output.contains("testFormatting"))
    #expect(output.contains("PASSED"))
    #expect(output.contains("12345"))
    #expect(output.contains("100"))
  }

  @Test("Compact output format")
  func testCompactOutput() {
    let stats = TestRunStatistics(
      testName: "testCompact",
      generationCount: 50,
      shrinkAttempts: 5,
      successfulShrinks: 3,
      generationTime: 0.1,
      shrinkingTime: 0.05,
      totalTime: 0.15,
      passed: true,
      seed: nil,
      startTime: Date()
    )

    let compact = stats.compact()

    #expect(compact.contains("✅"))
    #expect(compact.contains("testCompact"))
    #expect(compact.contains("50 gens"))
    #expect(compact.contains("5 shrinks"))
  }

  @Test("JSON output is valid")
  func testJSONOutput() {
    let stats = TestRunStatistics(
      testName: "testJSON",
      generationCount: 100,
      shrinkAttempts: 10,
      successfulShrinks: 5,
      generationTime: 0.5,
      shrinkingTime: 0.1,
      totalTime: 0.6,
      passed: true,
      seed: nil,
      startTime: Date()
    )

    let json = stats.toJSON()

    #expect(json != nil)
    #expect(json?.contains("\"testName\"") == true)
    #expect(json?.contains("\"generationCount\"") == true)
  }

  @Test("Aggregate formatted output")
  func testAggregateFormattedOutput() {
    let test1 = TestRunStatistics(
      testName: "test1",
      generationCount: 100,
      shrinkAttempts: 10,
      successfulShrinks: 5,
      generationTime: 0.5,
      shrinkingTime: 0.1,
      totalTime: 0.6,
      passed: true,
      seed: nil,
      startTime: Date()
    )

    let aggregate = AggregateStatistics(tests: [test1])
    let output = aggregate.formatted()

    #expect(output.contains("TEST RUN SUMMARY"))
    #expect(output.contains("1 passed"))
  }
}
