import Testing
@testable import InvariantSwift
@testable import InvariantSwiftAdvanced

/// Comprehensive tests for coverage-guided generation functionality
struct CoverageGuidedTests {

  // MARK: - CoverageBudget Tests

  @Test("CoverageBudget Initialization and Calculations")
  func coverageBudgetBasics() {
    let budget = CoverageBudget(
      uncoveredSymbols: ["func1", "func2"],
      coverageMap: [
        "func1": 0.0,
        "func2": 0.0,
        "func3": 1.0,
        "func4": 1.0,
      ],
      totalFunctions: 4,
      coveredFunctions: 2
    )

    #expect(budget.coveragePercentage == 50.0)
    #expect(budget.uncoveredSymbols.count == 2)
    #expect(budget.criticalGaps.sorted() == ["func1", "func2"])
  }

  @Test("Empty CoverageBudget")
  func emptyCoverageBudget() {
    let budget = CoverageBudget.empty

    #expect(budget.coveragePercentage == 0.0)
    #expect(budget.uncoveredSymbols.isEmpty)
    #expect(budget.criticalGaps.isEmpty)
    #expect(budget.totalFunctions == 0)
  }

  // MARK: - CoverageCollector Tests

  @Test("CoverageCollector Basic Functionality")
  func coverageCollectorBasics() async {
    let collector = CoverageCollector()

    // Initially empty
    let initialBudget = await collector.currentBudget()
    #expect(initialBudget.coveragePercentage == 0.0)

    // Add some known symbols
    await collector.addKnownSymbols(["func1", "func2", "func3"])

    let budgetAfterAdding = await collector.currentBudget()
    #expect(budgetAfterAdding.totalFunctions == 3)
    #expect(budgetAfterAdding.coveredFunctions == 0)

    // Record an execution
    let execution = ExecutionRecord(
      coveredSymbols: ["func1", "func2"],
      executionTime: 0.1
    )
    await collector.recordExecution(execution)

    let budgetAfterExecution = await collector.currentBudget()
    #expect(budgetAfterExecution.coveredFunctions == 2)
    #expect(abs(budgetAfterExecution.coveragePercentage - (200.0 / 3.0)) < 0.001)  // 2 covered out of 3 total (with floating point tolerance)
  }

  @Test("CoverageCollector Statistics")
  func coverageCollectorStatistics() async {
    let collector = CoverageCollector()
    await collector.addKnownSymbols(["func1", "func2"])

    let execution1 = ExecutionRecord(coveredSymbols: ["func1"], executionTime: 0.1)
    let execution2 = ExecutionRecord(coveredSymbols: ["func2"], executionTime: 0.2)

    await collector.recordExecution(execution1)
    await collector.recordExecution(execution2)

    let stats = await collector.getStatistics()
    #expect(stats.executions == 2)
    #expect(stats.totalSymbols == 2)
    #expect(abs(stats.avgExecutionTime - 0.15) < 0.001)  // Average of 0.1 and 0.2
  }

  // MARK: - Coverage-Guided Generation Tests

  @Test("Gen Biasing with Coverage Budget")
  func generatorBiasing() {
    let originalGen = Gen<Int>.int(in: 1...100)

    let budget = CoverageBudget(
      uncoveredSymbols: ["boundaryTest"],
      coverageMap: ["boundaryTest": 0.0],
      totalFunctions: 1,
      coveredFunctions: 0
    )

    let biasedGen = originalGen.biased(by: budget, strategy: .frequency)

    // Test that biased generator still produces valid values
    let seed = Seed(value: 42)
    let size = Size(value: 10)

    let originalValue = originalGen.sample(size: size, seed: seed)
    let biasedValue = biasedGen.sample(size: size, seed: seed)

    // Both should be within expected range
    #expect(originalValue >= 1 && originalValue <= 100)
    #expect(biasedValue >= 1 && biasedValue <= 100)

    // Values might be different due to biasing
    // (This is probabilistic, so we just ensure they're valid)
  }

  @Test("Gen Biasing with Empty Budget")
  func generatorBiasingEmptyBudget() {
    let originalGen = Gen<Int>.int(in: 1...100)
    let emptyBudget = CoverageBudget.empty

    let biasedGen = originalGen.biased(by: emptyBudget)

    let seed = Seed(value: 42)
    let size = Size(value: 10)

    let originalValue = originalGen.sample(size: size, seed: seed)
    let biasedValue = biasedGen.sample(size: size, seed: seed)

    // With empty budget, biasing should be disabled and values should be identical
    #expect(originalValue == biasedValue)
  }

  @Test("Coverage Strategy Variations")
  func coverageStrategies() {
    let gen = Gen<Int>.int(in: 1...100)
    let budget = CoverageBudget(
      uncoveredSymbols: ["test"],
      coverageMap: ["test": 0.0],
      totalFunctions: 1,
      coveredFunctions: 0
    )

    let seed = Seed(value: 42)
    let size = Size(value: 10)

    // Test different strategies produce valid values
    let strategies: [CoverageStrategy] = [.random, .frequency, .boundary, .adaptive]

    for strategy in strategies {
      let biasedGen = gen.biased(by: budget, strategy: strategy)
      let value = biasedGen.sample(size: size, seed: seed)
      #expect(value >= 1 && value <= 100, "Strategy \(strategy) produced invalid value: \(value)")
    }
  }

  // MARK: - Property Coverage Extension Tests

  @Test("Property Coverage Guidance Extension")
  func propertyWithCoverageGuidance() {
    let property = Property(
      generator: Gen<Int>.int(in: 1...100),
      predicate: { $0 > 0 }
    )

    let budget = CoverageBudget(
      uncoveredSymbols: ["positiveTest"],
      coverageMap: ["positiveTest": 0.0],
      totalFunctions: 1,
      coveredFunctions: 0
    )

    let guidedProperty = property.withCoverageGuidance(budget: budget)

    // Test that guided property maintains the same predicate behavior
    let testValue = 50
    #expect(property.predicate(testValue) == guidedProperty.predicate(testValue))

    // Test that guided property generates valid values
    let seed = Seed(value: 42)
    let size = Size(value: 10)
    let generatedValue = guidedProperty.generator.sample(size: size, seed: seed)
    #expect(generatedValue >= 1 && generatedValue <= 100)
  }

  // MARK: - PropertyRunner Coverage Extensions Tests

  @Test("PropertyRunner Coverage Tracking Integration")
  func propertyRunnerCoverageIntegration() async {
    let runner = PropertyRunner(seed: Seed(value: 42))

    let property = Property(
      generator: Gen<Int>.int(in: 1...10),
      predicate: { $0 > 0 }  // Should always pass
    )

    let knownSymbols: Set<String> = ["positive_check", "range_validation"]

    let (result, report) = await runner.runPropertyWithCoverageTracking(
      property,
      knownSymbols: knownSymbols,
      config: PropertyConfig(iterations: 10)
    )

    // Property should succeed
    #expect(result.isSuccess)

    // Coverage report should have reasonable values
    #expect(report.executionCount == 10)
    #expect(report.improvement >= 0.0)  // Should not decrease coverage
    #expect(report.uncoveredSymbols.count <= knownSymbols.count)
  }

  @Test("PropertyRunner Coverage Guided Execution")
  func propertyRunnerGuidedExecution() async {
    let runner = PropertyRunner(seed: Seed(value: 42))
    let collector = CoverageCollector()

    // Add some known symbols
    await collector.addKnownSymbols(["test_function", "validation_check"])

    let property = Property(
      generator: Gen<Int>.int(in: 1...100),
      predicate: { $0 > 0 }
    )

    let (result, report) = await runner.runPropertyWithCoverageGuidance(
      property,
      collector: collector,
      config: PropertyConfig(iterations: 20),
      coverageStrategy: .frequency
    )

    // Verify results
    #expect(result.isSuccess)
    #expect(report.executionCount == 20)
    #expect(report.initialCoverage >= 0.0)
    #expect(report.finalCoverage >= 0.0)
    #expect(report.improvement >= 0.0)

    // Verify that coverage report provides useful information
    let summary = report.summary()
    #expect(summary.contains("Coverage Report"))
    #expect(summary.contains("Initial Coverage"))
    #expect(summary.contains("Final Coverage"))
  }

  // MARK: - Configuration Tests

  @Test("CoverageConfig Validation")
  func coverageConfigValidation() {
    let config = CoverageConfig(
      enableBiasing: true,
      biasFactor: 3.0,
      maxCandidates: 10
    )

    #expect(config.enableBiasing == true)
    #expect(config.biasFactor == 3.0)
    #expect(config.maxCandidates == 10)

    // Test edge case values
    let edgeConfig = CoverageConfig(
      enableBiasing: false,
      biasFactor: 0.5,  // Should be clamped to 1.0
      maxCandidates: 0  // Should be clamped to 1
    )

    #expect(edgeConfig.biasFactor == 1.0)
    #expect(edgeConfig.maxCandidates == 1)
  }

  @Test("Coverage Report Summary Format")
  func coverageReportSummary() {
    let report = CoverageReport(
      initialCoverage: 75.0,
      finalCoverage: 85.5,
      improvement: 10.5,
      executionCount: 100,
      uncoveredSymbols: ["func1", "func2"]
    )

    let summary = report.summary()

    #expect(summary.contains("Initial Coverage: 75.00%"))
    #expect(summary.contains("Final Coverage: 85.50%"))
    #expect(summary.contains("Improvement: +10.50%"))
    #expect(summary.contains("Executions: 100"))
    #expect(summary.contains("Remaining Gaps: 2 symbols"))
  }

  // MARK: - Error Handling Tests

  @Test("PropertyResult Extension Methods")
  func propertyResultExtensions() {
    let successResult = PropertyResult<Int>.success(iterations: 10)
    let failureResult = PropertyResult<Int>.failure(
      counterexample: 42,
      iterations: 5,
      shrunk: 1,
      reason: .predicateFailed,
      seed: Seed(value: 12345)
    )
    let gaveUpResult = PropertyResult<Int>.gaveUp(discarded: 10, iterations: 5)

    #expect(successResult.isSuccess == true)
    #expect(successResult.isFailure == false)

    #expect(failureResult.isSuccess == false)
    #expect(failureResult.isFailure == true)

    #expect(gaveUpResult.isSuccess == false)
    #expect(gaveUpResult.isFailure == false)
  }

  // MARK: - Integration Tests

  @Test("Full Coverage-Guided Property Testing Workflow")
  func fullCoverageGuidedWorkflow() async {
    let runner = PropertyRunner(seed: Seed(value: 12345))

    // Create a more complex property
    let property = Property(
      generator: Gen<[Int]>.array(Gen<Int>.int(in: -10...10)),
      predicate: { array in
        // Property: sum of array should be within reasonable bounds
        let sum = array.reduce(0, +)
        return abs(sum) <= array.count * 10
      }
    )

    // Define some symbols we want to cover
    let knownSymbols: Set<String> = [
      "array_sum_calculation",
      "boundary_check",
      "empty_array_handling",
      "large_array_processing",
    ]

    // Run with coverage tracking
    let (result, report) = await runner.runPropertyWithCoverageTracking(
      property,
      knownSymbols: knownSymbols,
      config: PropertyConfig(iterations: 50),
      coverageConfig: CoverageConfig(
        enableBiasing: true,
        biasFactor: 2.5,
        maxCandidates: 5
      )
    )

    // Validate the complete workflow
    #expect(result.isSuccess || result.isFailure)  // Should have a definitive result
    #expect(report.executionCount == 50)
    #expect(report.finalCoverage >= report.initialCoverage)  // Coverage should not decrease

    // Print summary for manual verification if needed
    let summary = report.summary()
    #expect(summary.contains("Coverage Report:"))
  }
}

// MARK: - Mock Coverage Tracker for Testing

/// Simple mock for testing coverage integration without external dependencies
struct MockCoverageTracker {
  private(set) var recordedSymbols: Set<String> = []

  mutating func recordSymbol(_ symbol: String) {
    recordedSymbols.insert(symbol)
  }

  func getCoverageBudget() -> CoverageBudget {
    let allSymbols: Set<String> = ["func1", "func2", "func3", "func4"]
    let uncovered = allSymbols.subtracting(recordedSymbols)

    let coverageMap = Dictionary(
      allSymbols.map { symbol in
        let coverage = recordedSymbols.contains(symbol) ? 1.0 : 0.0
        return (symbol, coverage)
      },
      uniquingKeysWith: { first, _ in first }
    )

    return CoverageBudget(
      uncoveredSymbols: uncovered,
      coverageMap: coverageMap,
      totalFunctions: allSymbols.count,
      coveredFunctions: recordedSymbols.count
    )
  }
}
