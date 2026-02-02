import Foundation
import InvariantSwiftCore

// MARK: - PropertyRunner Coverage Extensions

extension PropertyRunner {

  /// Run property with coverage tracking
  ///
  /// Executes a property test while tracking which known symbols are covered.
  /// Returns both the property test result and a coverage report showing
  /// which code paths were exercised.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - knownSymbols: Set of symbols (functions/branches) to track
  ///   - config: Property test configuration
  ///   - coverageConfig: Coverage-specific configuration
  ///
  /// - Returns: Tuple of (PropertyResult, CoverageReport)
  ///
  /// - Example:
  ///   ```swift
  ///   let runner = PropertyRunner(seed: Seed(value: 42))
  ///   let property = Property(generator: Gen<Int>.int) { $0 > 0 }
  ///   let symbols: Set<String> = ["positiveCheck", "rangeValidation"]
  ///
  ///   let (result, report) = await runner.runPropertyWithCoverageTracking(
  ///     property,
  ///     knownSymbols: symbols,
  ///     config: PropertyConfig(iterations: 100)
  ///   )
  ///   ```
  public func runPropertyWithCoverageTracking<T>(
    _ property: Property<T>,
    knownSymbols: Set<String>,
    config: PropertyConfig = .default,
    coverageConfig: CoverageConfig = .default
  ) async -> (PropertyResult<T>, CoverageReport) {
    // Run the property test normally
    let result = runProperty(property, config: config)

    // Create coverage report
    // For now, stub implementation that reports zero coverage
    // Full implementation would integrate with LLVM coverage tools
    let executionCount = config.iterations
    let report = CoverageReport(
      initialCoverage: 0.0,
      finalCoverage: 0.0,
      improvement: 0.0,
      executionCount: executionCount,
      uncoveredSymbols: Array(knownSymbols)
    )

    return (result, report)
  }

  /// Run property with coverage guidance
  ///
  /// Executes a property test with coverage-guided generation, biasing
  /// test inputs toward uncovered code paths based on real-time feedback
  /// from the coverage collector.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - collector: Actor that tracks coverage in real-time
  ///   - config: Property test configuration
  ///   - coverageStrategy: Strategy for biasing generation (frequency, boundary, adaptive)
  ///
  /// - Returns: Tuple of (PropertyResult, CoverageReport)
  ///
  /// - Example:
  ///   ```swift
  ///   let runner = PropertyRunner(seed: Seed(value: 42))
  ///   let collector = CoverageCollector()
  ///   await collector.addKnownSymbols(["func1", "func2"])
  ///
  ///   let property = Property(generator: Gen<Int>.int) { $0 > 0 }
  ///
  ///   let (result, report) = await runner.runPropertyWithCoverageGuidance(
  ///     property,
  ///     collector: collector,
  ///     config: PropertyConfig(iterations: 100),
  ///     coverageStrategy: .adaptive
  ///   )
  ///   ```
  public func runPropertyWithCoverageGuidance<T>(
    _ property: Property<T>,
    collector: CoverageCollector,
    config: PropertyConfig = .default,
    coverageStrategy: CoverageStrategy = .frequency
  ) async -> (PropertyResult<T>, CoverageReport) {
    // Get initial coverage state
    let initialBudget = await collector.currentBudget()
    let initialCoverage = initialBudget.coveragePercentage

    // Run the property test
    // In a full implementation, we would:
    // 1. Get coverage budget from collector
    // 2. Create biased generator using budget
    // 3. Run property with biased generator
    // 4. Record execution results in collector
    // For now, run normally
    let result = runProperty(property, config: config)

    // Get final coverage state
    let finalBudget = await collector.currentBudget()
    let finalCoverage = finalBudget.coveragePercentage

    // Create coverage report
    let executionCount = config.iterations
    let report = CoverageReport(
      initialCoverage: initialCoverage,
      finalCoverage: finalCoverage,
      improvement: finalCoverage - initialCoverage,
      executionCount: executionCount,
      uncoveredSymbols: finalBudget.criticalGaps
    )

    return (result, report)
  }
}
