import Testing
@testable import InvariantSwiftCore
@testable import InvariantSwift

/// Tests for coverage threshold enforcement
@Suite("Coverage Enforcement Tests")
struct CoverageEnforcementTests {

  // MARK: - Enforcement Tests

  @Test("Coverage enforcement fails on unmet threshold")
  func enforcementFailsOnUnmetThreshold() async {
    let property = Property(generator: Gen<Int>.int(in: 0...1000)) { _ in
      true
    }
    .cover(100, when: { $0 > 999 }, label: "impossible")

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .failure(_, _, _, let reason, _) = result.result {
      #expect(reason.description.contains("Coverage"))
    } else {
      Issue.record("Expected coverage enforcement failure")
    }
  }

  @Test("Coverage enforcement passes when threshold met")
  func enforcementPassesWhenMet() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(40, when: { $0 > 50 }, label: "large")  // ~50% should be > 50

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .success = result.result {
      // Pass
    } else {
      Issue.record("Expected success with met coverage")
    }
  }

  @Test("Lenient mode warns but doesn't fail")
  func lenientModeWarnsButPasses() async {
    let property = Property(generator: Gen<Int>.int(in: 0...1000)) { _ in
      true
    }
    .cover(100, when: { $0 > 999 }, label: "impossible")

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = false  // Lenient mode

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    // Should pass even with unmet coverage
    if case .success = result.result {
      #expect(!result.classification.allCoverageThresholdsMet)
    } else {
      Issue.record("Expected lenient mode to pass")
    }
  }

  // MARK: - Multiple Thresholds Tests

  @Test("Multiple coverage thresholds all checked")
  func multipleThresholdsAllChecked() async {
    let property = Property(generator: Gen<Int>.int(in: -100...100)) { _ in
      true
    }
    .cover(30, when: { $0 > 0 }, label: "positive")
    .cover(30, when: { $0 < 0 }, label: "negative")
    .cover(1, when: { $0 == 0 }, label: "zero")

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    // All three should be tracked
    #expect(result.classification.coverageResults.count == 3)
  }

  @Test("First unmet threshold causes failure")
  func firstUnmetThresholdCausesFailure() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(100, when: { $0 > 200 }, label: "impossible1")
    .cover(50, when: { $0 > 50 }, label: "possible")
    .cover(100, when: { $0 < -10 }, label: "impossible2")

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .failure = result.result {
      // Should list all unmet thresholds
      let unmet = result.classification.unmetCoverageChecks
      #expect(unmet.contains("impossible1") || unmet.contains("impossible2"))
    } else {
      Issue.record("Expected failure with unmet thresholds")
    }
  }

  // MARK: - Error Message Tests

  @Test("Coverage failure message is clear")
  func coverageFailureMessageIsClear() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(90, when: { $0 > 95 }, label: "rare")

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .failure(_, _, _, let reason, _) = result.result {
      let message = reason.description
      // Should mention coverage and the label
      #expect(message.contains("Coverage") || message.contains("rare"))
    } else {
      Issue.record("Expected failure with clear message")
    }
  }

  @Test("Coverage report shows actual vs required percentages")
  func coverageReportShowsPercentages() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(80, when: { $0 > 50 }, label: "large")

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = false

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    let coverage = result.classification.coverageResults["large"]
    #expect(coverage?.threshold == 80.0)
    #expect(coverage?.percentage >= 0 && coverage?.percentage <= 100)
  }

  // MARK: - Edge Cases

  @Test("Zero threshold always met")
  func zeroThresholdAlwaysMet() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(0, when: { _ in false }, label: "never")

    var config = PropertyConfig(iterations: 50)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .success = result.result {
      #expect(result.classification.allCoverageThresholdsMet)
    } else {
      Issue.record("Expected success with 0% threshold")
    }
  }

  @Test("100% threshold requires all iterations")
  func fullThresholdRequiresAll() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(100, when: { _ in true }, label: "all")

    var config = PropertyConfig(iterations: 50)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .success = result.result {
      let coverage = result.classification.coverageResults["all"]
      #expect(coverage?.percentage == 100.0)
      #expect(coverage?.met == true)
    } else {
      Issue.record("Expected success when all iterations meet condition")
    }
  }
}
