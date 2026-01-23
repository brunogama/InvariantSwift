import Testing
@testable import InvariantSwiftCore
@testable import InvariantSwift

/// Comprehensive tests for classification reporting functionality
struct ClassificationTests {

  // MARK: - ClassificationContext Tests

  @Test("ClassificationContext records labels correctly")
  func classifyRecordsLabels() {
    let context = ClassificationContext()

    context.classify("sign", "positive")
    context.classify("sign", "positive")
    context.classify("sign", "negative")
    context.classify("size", "large")

    let report = context.report()

    // Check sign category
    #expect(report.labelDistribution["sign"]?["positive"]?.count == 2)
    #expect(report.labelDistribution["sign"]?["negative"]?.count == 1)

    // Check size category
    #expect(report.labelDistribution["size"]?["large"]?.count == 1)
  }

  @Test("ClassificationContext calculates percentages correctly")
  func classifyCalculatesPercentages() {
    let context = ClassificationContext()

    // Create a known distribution: 60% positive, 40% negative
    for _ in 0..<6 { context.classify("sign", "positive") }
    for _ in 0..<4 { context.classify("sign", "negative") }

    let report = context.report()

    let positivePercentage = report.labelDistribution["sign"]?["positive"]?.percentage ?? 0
    let negativePercentage = report.labelDistribution["sign"]?["negative"]?.percentage ?? 0

    #expect(abs(positivePercentage - 60.0) < 0.1)
    #expect(abs(negativePercentage - 40.0) < 0.1)
  }

  @Test("ClassificationContext cover tracks hits and misses")
  func coverTracksHitsAndMisses() {
    let context = ClassificationContext()

    // 3 hits out of 5 checks = 60%
    _ = context.cover("extremes", percentage: 50.0) { true }
    _ = context.cover("extremes", percentage: 50.0) { true }
    _ = context.cover("extremes", percentage: 50.0) { true }
    _ = context.cover("extremes", percentage: 50.0) { false }
    _ = context.cover("extremes", percentage: 50.0) { false }

    let report = context.report()
    let extremes = report.coverageResults["extremes"]

    #expect(extremes?.hits == 3)
    #expect(extremes?.checks == 5)
    #expect(abs((extremes?.percentage ?? 0) - 60.0) < 0.1)
    #expect(extremes?.met == true)  // 60% >= 50% threshold
  }

  @Test("ClassificationContext cover returns condition result")
  func coverReturnsConditionResult() {
    let context = ClassificationContext()

    let trueResult = context.cover("test", percentage: 0) { true }
    let falseResult = context.cover("test", percentage: 0) { false }

    #expect(trueResult == true)
    #expect(falseResult == false)
  }

  @Test("ClassificationContext cover detects unmet thresholds")
  func coverDetectsUnmetThresholds() {
    let context = ClassificationContext()

    // Only 20% coverage when 50% required
    _ = context.cover("required", percentage: 50.0) { true }
    _ = context.cover("required", percentage: 50.0) { false }
    _ = context.cover("required", percentage: 50.0) { false }
    _ = context.cover("required", percentage: 50.0) { false }
    _ = context.cover("required", percentage: 50.0) { false }

    let report = context.report()

    #expect(report.coverageResults["required"]?.met == false)
    #expect(report.allCoverageThresholdsMet == false)
    #expect(report.unmetCoverageChecks == ["required"])
  }

  @Test("ClassificationContext merge combines contexts")
  func mergeContexts() {
    let context1 = ClassificationContext()
    let context2 = ClassificationContext()

    context1.classify("sign", "positive")
    context1.classify("sign", "positive")
    context2.classify("sign", "negative")
    context2.classify("sign", "negative")

    _ = context1.cover("boundary", percentage: 10.0) { true }
    _ = context2.cover("boundary", percentage: 10.0) { false }

    context1.recordIteration()
    context2.recordIteration()
    context2.recordIteration()

    context1.merge(context2)
    let report = context1.report()

    // Labels should be merged
    #expect(report.labelDistribution["sign"]?["positive"]?.count == 2)
    #expect(report.labelDistribution["sign"]?["negative"]?.count == 2)

    // Coverage should be merged
    #expect(report.coverageResults["boundary"]?.hits == 1)
    #expect(report.coverageResults["boundary"]?.checks == 2)

    // Iterations should be merged
    #expect(report.totalIterations == 3)
  }

  // MARK: - ClassificationReport Tests

  @Test("ClassificationReport empty report")
  func emptyReport() {
    let report = ClassificationReport.empty

    #expect(report.labelDistribution.isEmpty)
    #expect(report.coverageResults.isEmpty)
    #expect(report.totalIterations == 0)
    #expect(report.allCoverageThresholdsMet == true)
    #expect(report.unmetCoverageChecks.isEmpty)
  }

  @Test("ClassificationReport format produces readable output")
  func reportFormat() {
    let context = ClassificationContext()

    context.classify("sign", "positive")
    context.classify("sign", "negative")
    _ = context.cover("boundary", percentage: 10.0) { true }
    context.recordIteration()

    let report = context.report()
    let formatted = report.format()

    #expect(formatted.contains("Classification Report"))
    #expect(formatted.contains("Labels:"))
    #expect(formatted.contains("sign:"))
    #expect(formatted.contains("positive"))
    #expect(formatted.contains("negative"))
    #expect(formatted.contains("Coverage:"))
    #expect(formatted.contains("boundary"))
  }

  @Test("ClassificationReport summary is concise")
  func reportSummary() {
    let context = ClassificationContext()

    context.classify("sign", "positive")
    _ = context.cover("boundary", percentage: 10.0) { true }

    let report = context.report()
    let summary = report.summary

    #expect(summary.contains("labels"))
    #expect(summary.contains("coverage checks"))
  }

  // MARK: - ClassifyingProperty Integration Tests

  @Test("ClassifyingProperty basic execution")
  func classifyingPropertyBasicExecution() async {
    let property = ClassifyingProperty(generator: Gen<Int>.int(in: -100...100)) { n, ctx in
      ctx.classify("sign", n < 0 ? "negative" : n >= 0 ? "non-negative" : "")
      return n + 0 == n  // Identity property
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    // Property should pass
    if case .success(let iterations) = result.result {
      #expect(iterations == 50)
    } else {
      Issue.record("Expected success")
    }

    // Classification should have been recorded
    #expect(!result.classification.labelDistribution.isEmpty)
    #expect(result.classification.labelDistribution["sign"] != nil)
  }

  @Test("ClassifyingProperty with coverage tracking")
  func classifyingPropertyWithCoverage() async {
    let property = ClassifyingProperty(generator: Gen<Int>.int(in: -100...100)) { n, ctx in
      // Track extremes coverage
      ctx.cover("extremes", percentage: 1.0) { abs(n) > 90 }
      return true
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    // Should have coverage data
    #expect(result.classification.coverageResults["extremes"] != nil)
    let coverage = result.classification.coverageResults["extremes"]
    #expect(coverage?.checks == 100)
  }

  @Test("ClassifyingProperty enforces coverage thresholds")
  func classifyingPropertyEnforcesCoverageThresholds() async {
    // Property that checks for impossible coverage (100% extremes when range is wide)
    let property = ClassifyingProperty(generator: Gen<Int>.int(in: -1000...1000)) { n, ctx in
      // Require 100% extreme values - impossible with uniform distribution
      ctx.cover("impossible", percentage: 100.0) { abs(n) > 999 }
      return true
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 50),
      enforceCoverageThresholds: true
    )

    // Should fail due to unmet threshold
    if case .failure(_, _, _, let reason, _) = result.result {
      #expect(reason.description.contains("Coverage thresholds unmet"))
    } else {
      Issue.record("Expected failure due to unmet coverage threshold")
    }
  }

  @Test("ClassifyingProperty with assumption")
  func classifyingPropertyWithAssumption() async {
    let property = ClassifyingProperty(
      generator: Gen<Int>.int(in: -100...100),
      assumption: { $0 != 0 },  // Skip zero
      predicate: { n, ctx in
        ctx.classify("sign", n > 0 ? "positive" : "negative")
        return true
      }
    )

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    // Should not have "zero" classification (filtered by assumption)
    let signLabels = result.classification.labelDistribution["sign"]
    #expect(signLabels?["zero"] == nil)
  }

  // MARK: - ClassifyingFailureReport Tests

  @Test("ClassifyingFailureReport format includes classification")
  func classifyingFailureReportFormat() async {
    let property = ClassifyingProperty(generator: Gen<Int>.int(in: 1...10)) { n, ctx in
      ctx.classify("size", n > 5 ? "large" : "small")
      return n < 5  // Will fail on values >= 5
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    if let report = FailureReport.from(result, config: .default) {
      let formatted = report.format()
      #expect(formatted.contains("Classification Report"))
      #expect(formatted.contains("size:"))
    }
  }

  // MARK: - Thread Safety Tests

  @Test("ClassificationContext is thread-safe")
  func classificationContextThreadSafety() async {
    let context = ClassificationContext()
    let iterations = 1000

    // Run concurrent classifications
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          context.classify("category", "label\(i % 10)")
          _ = context.cover("check", percentage: 50.0) { i % 2 == 0 }
          context.recordIteration()
        }
      }
    }

    let report = context.report()

    // Should have recorded all iterations without crashes
    #expect(report.totalIterations == iterations)

    // Coverage checks should be present
    #expect(report.coverageResults["check"]?.checks == iterations)
  }
}
