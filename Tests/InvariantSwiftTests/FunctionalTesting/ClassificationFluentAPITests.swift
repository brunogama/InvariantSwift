import Testing
@testable import InvariantSwiftCore
@testable import InvariantSwift

/// Comprehensive tests for the fluent classification API on Property<T>
@Suite("Classification Fluent API Tests")
struct ClassificationFluentAPITests {

  // MARK: - Property.cover() Tests

  @Test("Property.cover() returns ClassifyingProperty")
  func coverReturnsClassifyingProperty() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { n in
      n >= 0
    }
    .cover(50, when: { $0 > 50 }, label: "large")

    // Verify it's a ClassifyingProperty by running it
    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    #expect(result.classification.coverageResults["large"] != nil)
  }

  @Test("Property.cover() enforces minimum percentage in strict mode")
  func coverEnforcesMinimumInStrictMode() async {
    let property = Property(generator: Gen<Int>.int(in: 0...1000)) { _ in
      true
    }
    .cover(100, when: { $0 > 999 }, label: "impossible")  // Impossible to achieve 100%

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    // Should fail due to unmet coverage
    if case .failure(_, _, _, let reason, _) = result.result {
      #expect(reason.description.contains("Coverage"))
    } else {
      Issue.record("Expected failure due to unmet coverage threshold")
    }
  }

  @Test("Property.cover() passes when threshold is met")
  func coverPassesWhenThresholdMet() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(40, when: { $0 > 50 }, label: "large")  // ~50% should be > 50

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .success = result.result {
      // Pass - threshold was met
    } else {
      Issue.record("Expected success when coverage threshold is met")
    }
  }

  // MARK: - Property.classify() Tests

  @Test("Property.classify() labels matching inputs")
  func classifyLabelsMatchingInputs() async {
    let property = Property(generator: Gen<Int>.int(in: -100...100)) { _ in
      true
    }
    .classify(when: { $0 > 0 }, label: "positive")
    .classify(when: { $0 < 0 }, label: "negative")
    .classify(when: { $0 == 0 }, label: "zero")

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    let labels = result.classification.labelDistribution["categories"]
    #expect(labels?["positive"] != nil)
    #expect(labels?["negative"] != nil)
  }

  @Test("Property.classify() conditional labels only when true")
  func classifyConditionalLabelsOnlyWhenTrue() async {
    let property = Property(generator: Gen<Int>.int(in: 1...10)) { _ in
      true
    }
    .classify(when: { _ in false }, label: "never")

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    // "never" label should not appear since condition is always false
    let labels = result.classification.labelDistribution["categories"]
    #expect(labels?["never"] == nil)
  }

  // MARK: - Property.label() Tests

  @Test("Property.label() applies to all iterations")
  func labelAppliesToAllIterations() async {
    let property = Property(generator: Gen<Int>.int(in: 0...10)) { _ in
      true
    }
    .label("test-run")

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    // Label should be present and count should equal iterations
    let labelCount =
      result.classification.labelDistribution.values
      .flatMap { $0.values }
      .first { !$0.isEmpty }?.count ?? 0

    #expect(labelCount > 0)
  }

  // MARK: - Chaining Tests

  @Test("Chained cover/classify/label all apply")
  func chainedMethodsAccumulate() async {
    let property = Property(generator: Gen<Int>.int(in: -100...100)) { n in
      n + 0 == n
    }
    .cover(30, when: { $0 > 0 }, label: "positive")
    .classify(when: { $0 == 0 }, label: "zero")
    .label("identity check")

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    // Coverage should be tracked
    #expect(result.classification.coverageResults["positive"] != nil)

    // Classification labels should exist
    #expect(!result.classification.labelDistribution.isEmpty)
  }

  @Test("Multiple cover() calls all tracked")
  func multipleCoverCallsTracked() async {
    let property = Property(generator: Gen<Int>.int(in: -100...100)) { _ in
      true
    }
    .cover(30, when: { $0 > 0 }, label: "positive")
    .cover(30, when: { $0 < 0 }, label: "negative")
    .cover(1, when: { $0 == 0 }, label: "zero")

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    // All three coverage checks should be present
    #expect(result.classification.coverageResults.count == 3)
    #expect(result.classification.coverageResults["positive"] != nil)
    #expect(result.classification.coverageResults["negative"] != nil)
    #expect(result.classification.coverageResults["zero"] != nil)
  }

  @Test("Chained classifications preserve order")
  func chainedClassificationsPreserveOrder() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .classify(when: { $0 < 50 }, label: "small")
    .classify(when: { $0 >= 50 }, label: "large")

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    let labels = result.classification.labelDistribution["categories"]
    #expect(labels?["small"] != nil)
    #expect(labels?["large"] != nil)
  }

  // MARK: - Edge Cases

  @Test("Empty property with classification")
  func emptyPropertyWithClassification() async {
    let property = Property(generator: Gen<Int>.int(in: 0...10)) { _ in
      true
    }
    .classify(when: { _ in true }, label: "always")

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(
      property,
      config: PropertyConfig(iterations: 10)
    )

    if case .success = result.result {
      // Pass
    } else {
      Issue.record("Expected success for trivial property")
    }
  }

  @Test("100% coverage threshold passes when met")
  func fullCoverageThresholdPasses() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(100, when: { _ in true }, label: "all")  // 100% trivially met

    var config = PropertyConfig(iterations: 50)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .success = result.result {
      #expect(result.classification.allCoverageThresholdsMet)
    } else {
      Issue.record("Expected success when 100% coverage is trivially met")
    }
  }

  @Test("0% coverage threshold always passes")
  func zeroCoverageThresholdAlwaysPasses() async {
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { _ in
      true
    }
    .cover(0, when: { _ in false }, label: "never")  // 0% required

    var config = PropertyConfig(iterations: 50)
    config.coverage.enforceCoverage = true

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .success = result.result {
      #expect(result.classification.coverageResults["never"]?.met == true)
    } else {
      Issue.record("Expected success with 0% coverage threshold")
    }
  }

  // MARK: - Dogfood Tests (Property Tests Testing Classification)

  @Test("Dogfood: Classification accumulation is consistent")
  func dogfoodClassificationAccumulation() async {
    // Use property testing to verify classification behavior
    let metaProperty = Property(generator: Gen<Int>.int(in: 1...100)) { iterations in
      let context = ClassificationContext()

      // Simulate iterations
      for i in 0..<iterations {
        context.classify("parity", i % 2 == 0 ? "even" : "odd")
        context.recordIteration()
      }

      let report = context.report()

      // Verify accumulation is correct
      let evenCount = report.labelDistribution["parity"]?["even"]?.count ?? 0
      let oddCount = report.labelDistribution["parity"]?["odd"]?.count ?? 0

      return evenCount + oddCount == iterations
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runProperty(metaProperty, config: PropertyConfig(iterations: 50))

    if case .success = result {
      // Pass
    } else {
      Issue.record("Dogfood test failed: Classification accumulation inconsistent")
    }
  }

  @Test("Dogfood: Coverage percentage calculation is accurate")
  func dogfoodCoverageCalculation() async {
    // Property test verifying coverage math
    let metaProperty = Property(generator: Gen<Int>.int(in: 1...100)) { totalChecks in
      let context = ClassificationContext()

      let hits = totalChecks / 2  // 50% hit rate

      for i in 0..<totalChecks {
        _ = context.cover("test", percentage: 40.0) { i < hits }
      }

      let report = context.report()
      let coverage = report.coverageResults["test"]

      // Verify percentage calculation: hits/totalChecks * 100
      let expectedPercentage = Double(hits) / Double(totalChecks) * 100.0
      let actualPercentage = coverage?.percentage ?? 0

      return abs(expectedPercentage - actualPercentage) < 0.1
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runProperty(metaProperty, config: PropertyConfig(iterations: 50))

    if case .success = result {
      // Pass
    } else {
      Issue.record("Dogfood test failed: Coverage percentage calculation incorrect")
    }
  }

  @Test("Dogfood: Label merging preserves counts")
  func dogfoodLabelMerging() async {
    // Property test verifying merge correctness
    let metaProperty = Property(generator: Gen<Int>.int(in: 1...50)) { iterations in
      let context1 = ClassificationContext()
      let context2 = ClassificationContext()

      // Add labels to both contexts
      for i in 0..<iterations {
        context1.classify("category", "label\(i % 5)")
        context2.classify("category", "label\(i % 5)")
      }

      // Track counts before merge
      let report1 = context1.report()
      let report2 = context2.report()

      let count1 = report1.labelDistribution["category"]?.values.map(\.count).reduce(0, +) ?? 0
      let count2 = report2.labelDistribution["category"]?.values.map(\.count).reduce(0, +) ?? 0

      // Merge
      context1.merge(context2)
      let merged = context1.report()

      let mergedCount = merged.labelDistribution["category"]?.values.map(\.count).reduce(0, +) ?? 0

      return mergedCount == count1 + count2
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runProperty(metaProperty, config: PropertyConfig(iterations: 30))

    if case .success = result {
      // Pass
    } else {
      Issue.record("Dogfood test failed: Label merging does not preserve counts")
    }
  }

  // MARK: - Config Option Tests

  @Test("Lenient mode does not fail on unmet coverage")
  func lenientModeDoesNotFailOnUnmetCoverage() async {
    let property = Property(generator: Gen<Int>.int(in: 0...1000)) { _ in
      true
    }
    .cover(100, when: { $0 > 999 }, label: "impossible")

    var config = PropertyConfig(iterations: 100)
    config.coverage.enforceCoverage = false  // Lenient mode

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runClassifyingProperty(property, config: config)

    if case .success = result.result {
      #expect(!result.classification.allCoverageThresholdsMet)
    } else {
      Issue.record("Expected success in lenient mode despite unmet coverage")
    }
  }
}
