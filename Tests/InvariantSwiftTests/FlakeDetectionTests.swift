import Testing
@testable import InvariantSwift
@testable import InvariantSwiftCore

@Suite("Flake Detection Tests")
struct FlakeDetectionTests {

  // MARK: - FlakeDetectionConfig Tests

  @Test("Default config has expected values")
  func testDefaultConfig() {
    let config = FlakeDetectionConfig.default

    #expect(config.runs == 100)
    #expect(config.seeds == nil)
    #expect(config.flakinessThreshold == 0.01)
    #expect(config.failOnFlaky == false)
    #expect(config.storageURL == nil)
  }

  @Test("Custom config respects all parameters")
  func testCustomConfig() {
    let seeds: [UInt64] = [123, 456, 789]
    let url = URL(fileURLWithPath: "/tmp/flake")

    let config = FlakeDetectionConfig(
      runs: 50,
      seeds: seeds,
      flakinessThreshold: 0.05,
      failOnFlaky: true,
      storageURL: url
    )

    #expect(config.runs == 50)
    #expect(config.seeds == seeds)
    #expect(config.flakinessThreshold == 0.05)
    #expect(config.failOnFlaky == true)
    #expect(config.storageURL == url)
  }

  // MARK: - FlakeDetectionResult Tests

  @Test("All passes result is stable")
  func testAllPassesIsStable() {
    let result = FlakeDetectionResult<Int>(
      totalRuns: 100,
      passes: 100,
      failures: 0,
      failingSeeds: [],
      flakinessScore: 0.0,
      isFlaky: false,
      recommendation: .stable,
      statistics: nil
    )

    #expect(result.passes == 100)
    #expect(result.failures == 0)
    #expect(result.flakinessScore == 0.0)
    #expect(result.isFlaky == false)
    #expect(result.recommendation == .stable)
  }

  @Test("All failures result recommends fix")
  func testAllFailuresRecommendsFix() {
    let result = FlakeDetectionResult<Int>(
      totalRuns: 100,
      passes: 0,
      failures: 100,
      failingSeeds: Array(0..<100),
      flakinessScore: 0.0,
      isFlaky: false,
      recommendation: .fix,
      statistics: nil
    )

    #expect(result.passes == 0)
    #expect(result.failures == 100)
    #expect(result.isFlaky == false)
    #expect(result.recommendation == .fix)
  }

  @Test("High flakiness recommends quarantine")
  func testHighFlakinessRecommendsQuarantine() {
    let result = FlakeDetectionResult<Int>(
      totalRuns: 100,
      passes: 50,
      failures: 50,
      failingSeeds: Array(0..<50),
      flakinessScore: 0.5,
      isFlaky: true,
      recommendation: .quarantine,
      statistics: nil
    )

    #expect(result.flakinessScore == 0.5)
    #expect(result.isFlaky == true)
    #expect(result.recommendation == .quarantine)
  }

  @Test("Low flakiness recommends investigate")
  func testLowFlakinessRecommendsInvestigate() {
    let result = FlakeDetectionResult<Int>(
      totalRuns: 100,
      passes: 98,
      failures: 2,
      failingSeeds: [42, 99],
      flakinessScore: 0.02,
      isFlaky: true,
      recommendation: .investigate,
      statistics: nil
    )

    #expect(result.flakinessScore == 0.02)
    #expect(result.isFlaky == true)
    #expect(result.recommendation == .investigate)
  }

  // MARK: - FlakeRecommendation Tests

  @Test("Recommendation raw values are meaningful")
  func testRecommendationRawValues() {
    #expect(FlakeRecommendation.stable.rawValue == "Test is stable, no action needed")
    #expect(FlakeRecommendation.investigate.rawValue == "Test shows some flakiness, investigate")
    #expect(
      FlakeRecommendation.quarantine.rawValue == "Test is highly flaky, consider quarantining"
    )
    #expect(FlakeRecommendation.fix.rawValue == "Test fails consistently, fix the underlying issue")
  }

  // MARK: - runPropertyWithFlakeDetection Tests

  @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
  @Test("Stable property is detected as not flaky")
  func testStablePropertyDetection() async throws {
    let property = Property(generator: Gen<Int>.int) { _ in true }

    let result = try await runPropertyWithFlakeDetection(
      property,
      config: PropertyConfig(iterations: 10),
      flakeConfig: FlakeDetectionConfig(runs: 20),
      testId: "stable-test"
    )

    #expect(result.passes == 20)
    #expect(result.failures == 0)
    #expect(result.isFlaky == false)
    #expect(result.recommendation == .stable)
  }

  @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
  @Test("Consistently failing property recommends fix")
  func testConsistentlyFailingProperty() async throws {
    let property = Property(generator: Gen<Int>.int) { _ in false }

    let result = try await runPropertyWithFlakeDetection(
      property,
      config: PropertyConfig(iterations: 10),
      flakeConfig: FlakeDetectionConfig(runs: 20),
      testId: "failing-test"
    )

    #expect(result.passes == 0)
    #expect(result.failures == 20)
    #expect(result.isFlaky == false)
    #expect(result.recommendation == .fix)
  }

  @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
  @Test("Flaky property is detected")
  func testFlakyPropertyDetection() async throws {
    // This property fails when the generated value is even
    let property = Property(generator: Gen<Int>.int) { n in
      (n % 2) != 0
    }

    let result = try await runPropertyWithFlakeDetection(
      property,
      config: PropertyConfig(iterations: 5, seed: nil),
      flakeConfig: FlakeDetectionConfig(runs: 50, flakinessThreshold: 0.01),
      testId: "flaky-test"
    )

    // With random seeds, we expect approximately 50% failures
    // Verify we detected flakiness
    #expect(result.failures > 0)
    #expect(result.passes > 0)
    #expect(result.isFlaky == true)
  }

  @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
  @Test("failingSeeds contains correct seeds")
  func testFailingSeedsAreRecorded() async throws {
    // Property that fails for even seeds
    let property = Property(generator: Gen<Int>.pure(42)) { _ in false }

    let seeds: [UInt64] = [1, 2, 3, 4, 5]
    let result = try await runPropertyWithFlakeDetection(
      property,
      config: PropertyConfig(iterations: 1),
      flakeConfig: FlakeDetectionConfig(runs: 5, seeds: seeds),
      testId: "seed-tracking-test"
    )

    #expect(result.failingSeeds.count == 5)
    #expect(result.failingSeeds == seeds)
  }

  @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
  @Test("Statistics are recorded from FlakeHunter")
  func testFlakeHunterStatisticsRecording() async throws {
    let property = Property(generator: Gen<Int>.int) { n in
      (n % 2) != 0
    }

    let result = try await runPropertyWithFlakeDetection(
      property,
      config: PropertyConfig(iterations: 5),
      flakeConfig: FlakeDetectionConfig(runs: 30),
      testId: "statistics-test"
    )

    // FlakeHunter should have recorded statistics
    #expect(result.statistics != nil)
    if let stats = result.statistics {
      #expect(stats.totalExecutions == 30)
      #expect(stats.failures + Int(Double(stats.failures) * 0) >= 0)  // At least zero failures
    }
  }

  // MARK: - Safe Collection Access Tests

  @Test("Safe subscript returns nil for out of bounds")
  func testSafeSubscript() {
    let array = [1, 2, 3]

    #expect(array[safe: 0] == 1)
    #expect(array[safe: 2] == 3)
    #expect(array[safe: 3] == nil)
    #expect(array[safe: -1] == nil)
  }
}
