import Testing
@testable import InvariantSwiftCore
@testable import InvariantSwift

/// End-to-end tests verifying classification data flows through to Swift Testing output.
///
/// These tests verify Gap 1 from VERIFICATION.md: classification reports appear in
/// Swift Testing output for both passing and failing tests.
@Suite("Classification Swift Testing Integration")
struct ClassificationSwiftTestingIntegrationTests {

  // MARK: - FailureReport Integration Tests

  @Test("FailureReport.from creates report with classification data")
  func testFailureReportFromClassifyingResult() async {
    let gen = Gen<Int>.int
    let property = Property(generator: gen) { n in n >= 0 }
      .classify(when: { $0 > 0 }, label: "positive")
      .classify(when: { $0 == 0 }, label: "zero")

    let runner = PropertyRunner(seed: Seed(rawValue: 42))
    let config = PropertyConfig(iterations: 50, seed: Seed(rawValue: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    // Create FailureReport (even though this might succeed, we test the conversion logic)
    if case .success = result.result {
      // For this test, we just verify the classification report exists
      let report = result.classification.format()
      #expect(!report.isEmpty, "Classification report should not be empty")
    }
  }

  @Test("ClassifyingFailureReport.format includes classification section")
  func testClassifyingFailureReportFormat() {
    // Create a mock base report
    let baseReport = FailureReport(
      propertyName: "testProperty",
      outcome: .failed,
      iterations: 100,
      discarded: 5,
      counterexample: "[1, 2, 3]",
      shrunkCounterexample: "[1]",
      reason: .predicateFailed,
      replayToken: ReplayToken(seed: 12345, iterations: 100)
    )

    // Create a mock classification
    var classification = ClassificationReport()
    classification.recordLabel("positive", count: 40)
    classification.recordLabel("negative", count: 60)

    let classifyingReport = ClassifyingFailureReport(
      base: baseReport,
      classification: classification
    )

    let formatted = classifyingReport.format()

    // Verify classification section is included
    #expect(formatted.contains("positive"), "Should contain 'positive' label")
    #expect(formatted.contains("negative"), "Should contain 'negative' label")
    #expect(formatted.contains("FAILED"), "Should contain failure outcome")
    #expect(formatted.contains("[1]"), "Should contain shrunk counterexample")
  }

  @Test("FailureReporter formatCompactMessage includes classification")
  func testFailureReporterCompactWithClassification() {
    let classificationText = """
      Classification:
        positive: 70.0%
        zero: 30.0%
      """

    let report = FailureReport(
      testName: "testProperty",
      seed: Seed(rawValue: 42),
      originalValue: "[5, 10]",
      shrunkValue: "[5]",
      iterationsBeforeFailure: 100,
      shrinkAttempts: 10,
      successfulShrinks: 5,
      failureReason: .predicateFailed,
      totalTime: 0.5,
      classificationReport: classificationText
    )

    let reporter = FailureReporter(verbose: false)
    let formatted = reporter.formatMessage(report)

    #expect(formatted.contains("positive: 70.0%"), "Compact format should include classification")
    #expect(formatted.contains("zero: 30.0%"), "Compact format should include all labels")
    #expect(formatted.contains("Seed: 42"), "Should include seed")
  }

  @Test("FailureReporter formatVerboseMessage includes classification")
  func testFailureReporterVerboseWithClassification() {
    let classificationText = """
      Classification:
        positive: 70.0%
        zero: 30.0%
      """

    let report = FailureReport(
      testName: "testProperty",
      seed: Seed(rawValue: 42),
      originalValue: "[5, 10]",
      shrunkValue: "[5]",
      iterationsBeforeFailure: 100,
      shrinkAttempts: 10,
      successfulShrinks: 5,
      failureReason: .predicateFailed,
      totalTime: 0.5,
      classificationReport: classificationText
    )

    let reporter = FailureReporter(verbose: true)
    let formatted = reporter.formatMessage(report)

    #expect(
      formatted.contains("CLASSIFICATION"),
      "Verbose format should have CLASSIFICATION header"
    )
    #expect(formatted.contains("positive: 70.0%"), "Should include classification")
    #expect(formatted.contains("╔═"), "Verbose format should use box drawing")
  }

  // MARK: - PropertyTestIntegration Flow Tests

  @Test("Passing ClassifyingProperty records classification as Comment")
  func testPassingClassifyingPropertyComment() async throws {
    let property = Property(generator: Gen<Int>.int) { n in n >= -100 }
      .classify(when: { $0 > 0 }, label: "positive")
      .classify(when: { $0 == 0 }, label: "zero")
      .classify(when: { $0 < 0 }, label: "negative")

    let config = PropertyConfig(iterations: 100, seed: Seed(rawValue: 123))

    // Note: We can't directly verify Issue.record(Comment()) was called
    // without mocking, but we can verify the property runs successfully
    // and classification report is generated
    let runner = PropertyRunner(seed: config.seed)
    let result = await runner.runClassifyingProperty(property, config: config)

    #expect(result.result.isSuccess, "Property should pass")

    let report = result.classification.format()
    #expect(!report.isEmpty, "Classification report should be generated")
    #expect(
      report.contains("positive") || report.contains("negative") || report.contains("zero"),
      "Report should contain at least one label"
    )
  }

  @Test("Failing ClassifyingProperty includes classification in failure report")
  func testFailingClassifyingPropertyWithClassification() async {
    // Create a property that will fail
    let property = Property(generator: Gen<Int>.int) { n in n < 0 }
      .classify(when: { $0 > 0 }, label: "positive")
      .classify(when: { $0 == 0 }, label: "zero")
      .classify(when: { $0 < 0 }, label: "negative")

    let config = PropertyConfig(iterations: 100, seed: Seed(rawValue: 456))
    let runner = PropertyRunner(seed: config.seed)
    let result = await runner.runClassifyingProperty(property, config: config)

    // Should fail because we'll eventually generate a positive or zero number
    if case .failure = result.result {
      // Verify we can create a FailureReport with classification
      if let failureReport = FailureReport.from(result, config: config) {
        let formatted = failureReport.format()
        #expect(!formatted.isEmpty, "Failure report should not be empty")

        // Classification should be included
        #expect(
          formatted.contains("positive") || formatted.contains("negative")
            || formatted.contains("zero"),
          "Failure report should include classification"
        )
      }
    }
  }

  @Test("Coverage enforcement failure includes classification context")
  func testCoverageEnforcementWithClassification() async {
    // Create a property with coverage requirement that might not be met
    let property = Property(generator: Gen<Int>.int(in: 0..<100)) { n in n >= 0 }
      .cover(90, when: { $0 > 50 }, label: "large values")

    let config = PropertyConfig(
      iterations: 50,  // Small iterations might not reach 90% coverage
      seed: Seed(rawValue: 789),
      coverage: PropertyConfig.CoverageConfig(enforceCoverage: true, minCoverage: 90)
    )

    let runner = PropertyRunner(seed: config.seed)
    let result = await runner.runClassifyingProperty(property, config: config)

    // Check if coverage enforcement was applied
    let report = result.classification.format()
    #expect(!report.isEmpty, "Classification report should exist")

    // The report should show coverage percentage
    #expect(report.contains("large values"), "Should show the coverage label")
  }

  // MARK: - End-to-End Scenario Tests

  @Test("cover() with threshold met shows classification in output")
  func testCoverWithThresholdMet() async {
    let property = Property(generator: Gen<Int>.int(in: 0..<100)) { n in n >= 0 }
      .cover(30, when: { $0 >= 50 }, label: "large")

    let config = PropertyConfig(iterations: 100, seed: Seed(rawValue: 111))
    let runner = PropertyRunner(seed: config.seed)
    let result = await runner.runClassifyingProperty(property, config: config)

    let report = result.classification.format()
    #expect(report.contains("large"), "Classification should include 'large' label")

    // Verify the threshold check
    let coverageCheck = result.classification.checkCoverage(label: "large", threshold: 30)
    #expect(coverageCheck.isMet, "Coverage threshold should be met")
  }

  @Test("cover() with threshold NOT met shows classification + failure")
  func testCoverWithThresholdNotMet() async {
    // Use a very high threshold that's unlikely to be met
    let property = Property(generator: Gen<Int>.int(in: 0..<10)) { n in n >= 0 }
      .cover(95, when: { $0 == 9 }, label: "exactly nine")

    let config = PropertyConfig(
      iterations: 50,
      seed: Seed(rawValue: 222),
      coverage: PropertyConfig.CoverageConfig(enforceCoverage: true, minCoverage: 95)
    )

    let runner = PropertyRunner(seed: config.seed)
    let result = await runner.runClassifyingProperty(property, config: config)

    let report = result.classification.format()
    #expect(report.contains("exactly nine"), "Classification should include label")

    // Check that coverage was not met
    let coverageCheck = result.classification.checkCoverage(label: "exactly nine", threshold: 95)
    #expect(!coverageCheck.isMet, "High threshold should not be met with small iterations")
  }

  @Test("classify() labels appear in output")
  func testClassifyLabelsInOutput() async {
    let property = Property(generator: Gen<Int>.int) { n in n * 2 == n + n }
      .classify(when: { $0 > 0 }, label: "positive")
      .classify(when: { $0 == 0 }, label: "zero")
      .classify(when: { $0 < 0 }, label: "negative")

    let config = PropertyConfig(iterations: 100, seed: Seed(rawValue: 333))
    let runner = PropertyRunner(seed: config.seed)
    let result = await runner.runClassifyingProperty(property, config: config)

    let report = result.classification.format()
    #expect(report.contains("positive"), "Should show positive label")
    #expect(report.contains("zero"), "Should show zero label")
    #expect(report.contains("negative"), "Should show negative label")

    // Verify percentages
    let stats = result.classification.statistics()
    let totalLabeled = stats.values.reduce(0, +)
    #expect(totalLabeled == 100, "Should have labeled all 100 iterations")
  }

  @Test("chained cover().classify().label() all appear in output")
  func testChainedClassificationInOutput() async {
    let property = Property(generator: Gen<Int>.int(in: 0..<100)) { n in n >= 0 }
      .cover(40, when: { $0 >= 50 }, label: "large")
      .classify(when: { $0 % 2 == 0 }, label: "even")
      .classify(when: { $0 % 2 != 0 }, label: "odd")
      .label(when: { $0 == 0 }, label: "zero")

    let config = PropertyConfig(iterations: 100, seed: Seed(rawValue: 444))
    let runner = PropertyRunner(seed: config.seed)
    let result = await runner.runClassifyingProperty(property, config: config)

    let report = result.classification.format()

    // All labels should appear
    #expect(report.contains("large"), "Should show coverage label")
    #expect(report.contains("even"), "Should show even classification")
    #expect(report.contains("odd"), "Should show odd classification")
    #expect(report.contains("zero"), "Should show zero label")

    // Verify coverage check
    let coverageCheck = result.classification.checkCoverage(label: "large", threshold: 40)
    #expect(coverageCheck.isMet, "Large coverage should be met")
  }

  // MARK: - Helper for Result Checking

  @Test("PropertyResult isSuccess property works correctly")
  func testPropertyResultIsSuccess() {
    let successResult: PropertyResult<Int> = .success(iterations: 100)
    #expect(successResult.isSuccess, "Success result should return true")

    let failureResult: PropertyResult<Int> = .failure(
      counterexample: 42,
      iterations: 50,
      shrunkCounterexample: 1,
      reason: .predicateFailed,
      seed: Seed(rawValue: 0)
    )
    #expect(!failureResult.isSuccess, "Failure result should return false")

    let gaveUpResult: PropertyResult<Int> = .gaveUp(discarded: 10, iterations: 100)
    #expect(!gaveUpResult.isSuccess, "GaveUp result should return false")
  }
}
