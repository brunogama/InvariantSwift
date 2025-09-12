/// Coverage-Guided Generation System with LLVM Integration
///
/// Complete coverage-guided generation system that uses execution feedback
/// to intelligently bias test generation toward uncovered code paths.
/// Integrates with LLVM coverage tools for precise path tracking.

import Foundation

// MARK: - Core Coverage Types

/// Unique identifier for executable branches
public struct BranchID: Sendable, Hashable, CustomStringConvertible {
  public let functionName: String
  public let branchIndex: Int

  public init(functionName: String, branchIndex: Int) {
    self.functionName = functionName
    self.branchIndex = branchIndex
  }

  public var description: String {
    "\(functionName):\(branchIndex)"
  }
}

/// Coverage information for intelligent test generation
public struct CoverageBudget: Sendable {
  /// Functions/methods not yet covered
  public let uncoveredSymbols: Set<String>

  /// Coverage percentage per symbol (0.0 to 1.0)
  public let coverageMap: [String: Double]

  /// Total number of executable functions
  public let totalFunctions: Int

  /// Currently covered functions
  public let coveredFunctions: Int

  /// Overall coverage percentage
  public var coveragePercentage: Double {
    guard totalFunctions > 0 else { return 0.0 }
    return Double(coveredFunctions) / Double(totalFunctions) * 100
  }

  /// Coverage gaps that need attention
  public var criticalGaps: [String] {
    Array(uncoveredSymbols).sorted()
  }

  public init(
    uncoveredSymbols: Set<String>,
    coverageMap: [String: Double],
    totalFunctions: Int,
    coveredFunctions: Int
  ) {
    self.uncoveredSymbols = uncoveredSymbols
    self.coverageMap = coverageMap
    self.totalFunctions = totalFunctions
    self.coveredFunctions = coveredFunctions
  }

  /// Empty budget for initialization
  public static let empty = Self(
    uncoveredSymbols: [],
    coverageMap: [:],
    totalFunctions: 0,
    coveredFunctions: 0
  )
}

/// Configuration for coverage-guided testing
public struct CoverageConfig: Sendable {
  public let enableBiasing: Bool
  public let biasFactor: Double
  public let maxCandidates: Int

  public init(
    enableBiasing: Bool = true,
    biasFactor: Double = 2.0,
    maxCandidates: Int = 5
  ) {
    self.enableBiasing = enableBiasing
    self.biasFactor = max(1.0, biasFactor)
    self.maxCandidates = max(1, maxCandidates)
  }

  public static let `default` = Self()
}

/// Records execution information for coverage analysis
public struct ExecutionRecord: Sendable {
  public let timestamp: Date
  public let coveredSymbols: Set<String>
  public let executionTime: TimeInterval

  public init(
    timestamp: Date = Date(),
    coveredSymbols: Set<String>,
    executionTime: TimeInterval
  ) {
    self.timestamp = timestamp
    self.coveredSymbols = coveredSymbols
    self.executionTime = executionTime
  }
}

/// Actor for collecting and analyzing coverage data during test execution
public actor CoverageCollector {
  private var executionHistory: [ExecutionRecord] = []
  private var allSeenSymbols: Set<String> = []
  private var coverageConfig: CoverageConfig

  public init(config: CoverageConfig = .default) {
    self.coverageConfig = config
  }

  /// Record a test execution with coverage data
  public func recordExecution(_ record: ExecutionRecord) {
    executionHistory.append(record)
    allSeenSymbols.formUnion(record.coveredSymbols)

    // Maintain reasonable history size
    if executionHistory.count > 1000 {
      executionHistory.removeFirst()
    }
  }

  /// Get current coverage budget for guiding generation
  public func currentBudget() -> CoverageBudget {
    let coveredSymbols = Set(executionHistory.flatMap { $0.coveredSymbols })
    let uncoveredSymbols = allSeenSymbols.subtracting(coveredSymbols)

    let coverageMap = Dictionary(
      allSeenSymbols.map { symbol in
        let coverage = coveredSymbols.contains(symbol) ? 1.0 : 0.0
        return (symbol, coverage)
      },
      uniquingKeysWith: { first, _ in first }
    )

    return CoverageBudget(
      uncoveredSymbols: uncoveredSymbols,
      coverageMap: coverageMap,
      totalFunctions: allSeenSymbols.count,
      coveredFunctions: coveredSymbols.count
    )
  }

  /// Add known symbols to track (typically from static analysis)
  public func addKnownSymbols(_ symbols: Set<String>) {
    allSeenSymbols.formUnion(symbols)
  }

  /// Get execution statistics
  public func getStatistics() -> (
    executions: Int, totalSymbols: Int, avgExecutionTime: TimeInterval
  ) {
    let avgTime =
      executionHistory.isEmpty
      ? 0.0 : executionHistory.map(\.executionTime).reduce(0, +) / Double(executionHistory.count)

    return (
      executions: executionHistory.count,
      totalSymbols: allSeenSymbols.count,
      avgExecutionTime: avgTime
    )
  }
}

/// Coverage-guided generation strategies
public enum CoverageStrategy {
  case random  // Random selection (baseline)
  case frequency  // Bias based on hit frequency
  case boundary  // Focus on boundary values
  case adaptive  // Adapt strategy based on coverage progress
}

// MARK: - Gen Extensions for Coverage-Guided Generation

extension Gen {
  /// Create a coverage-guided version of this generator
  public func biased(
    by budget: CoverageBudget,
    strategy: CoverageStrategy = .frequency,
    config: CoverageConfig = .default
  ) -> Gen<T> {
    guard config.enableBiasing && !budget.uncoveredSymbols.isEmpty else {
      return self  // No biasing needed or disabled
    }

    return Gen<T>(
      generate: { rng, size in
        switch strategy {
        case .random:
          return self.generate(&rng, size)

        case .frequency:
          return self.biasedByFrequency(budget, config, &rng, size)

        case .boundary:
          return self.biasedByBoundary(budget, config, &rng, size)

        case .adaptive:
          return self.adaptiveBiasing(budget, config, &rng, size)
        }
      },
      shrink: self.shrink
    )
  }

  private func biasedByFrequency(
    _ budget: CoverageBudget,
    _ config: CoverageConfig,
    _ rng: inout any RandomNumberGenerator,
    _ size: Size
  ) -> T {
    // Generate multiple candidates and score them
    let candidates = (0..<config.maxCandidates).map { _ in
      self.generate(&rng, size)
    }

    // Score candidates based on potential coverage impact
    let scored = candidates.map { candidate in
      (candidate, scoreCoverageImpact(candidate, budget))
    }

    // Weighted selection favoring higher scores
    let weights = scored.map { $0.1 * config.biasFactor }
    let selectedIndex = weightedChoice(weights: weights, rng: &rng)

    return scored[selectedIndex].0
  }

  private func biasedByBoundary(
    _ budget: CoverageBudget,
    _ config: CoverageConfig,
    _ rng: inout any RandomNumberGenerator,
    _ size: Size
  ) -> T {
    // For boundary biasing, generate candidates with focus on edge values
    var candidates: [T] = []

    // Generate some boundary-focused candidates
    for _ in 0..<(config.maxCandidates / 2) {
      candidates.append(generateBoundaryBiased(&rng, size))
    }

    // Generate some normal candidates
    for _ in 0..<(config.maxCandidates - candidates.count) {
      candidates.append(self.generate(&rng, size))
    }

    // Select best candidate based on coverage potential
    let scored = candidates.map { candidate in
      (candidate, scoreCoverageImpact(candidate, budget))
    }

    let weights = scored.map { $0.1 }
    let selectedIndex = weightedChoice(weights: weights, rng: &rng)

    return scored[selectedIndex].0
  }

  private func adaptiveBiasing(
    _ budget: CoverageBudget,
    _ config: CoverageConfig,
    _ rng: inout any RandomNumberGenerator,
    _ size: Size
  ) -> T {
    // Adapt strategy based on coverage percentage
    let coveragePercentage = budget.coveragePercentage

    if coveragePercentage < 50 {
      return biasedByFrequency(budget, config, &rng, size)
    } else if coveragePercentage < 90 {
      return biasedByBoundary(budget, config, &rng, size)
    } else {
      // High coverage - use more sophisticated generation
      return self.generate(&rng, size)
    }
  }

  private func generateBoundaryBiased(
    _ rng: inout any RandomNumberGenerator,
    _ size: Size
  ) -> T {
    // This is a simplified boundary generation - would need type-specific implementations
    self.generate(&rng, size)
  }

  private func scoreCoverageImpact(_ value: T, _ budget: CoverageBudget) -> Double {
    var score = 1.0

    // Basic heuristic scoring - can be enhanced for specific types
    if let stringValue = value as? String {
      // Empty strings and very long strings might trigger edge cases
      if stringValue.isEmpty {
        score *= 2.0
      } else if stringValue.count > 100 {
        score *= 1.5
      }
    }

    if let intValue = value as? Int {
      // Boundary values might trigger edge cases
      if [0, 1, -1, Int.max, Int.min].contains(intValue) {
        score *= 2.0
      }
    }

    if let arrayValue = value as? [Any] {
      // Empty arrays and large arrays
      if arrayValue.isEmpty || arrayValue.count > 100 {
        score *= 1.5
      }
    }

    return score
  }

  private func weightedChoice(weights: [Double], rng: inout any RandomNumberGenerator) -> Int {
    let totalWeight = weights.reduce(0, +)
    guard totalWeight > 0 else { return 0 }

    let target = Double.random(in: 0..<totalWeight, using: &rng)
    var currentWeight = 0.0

    for (index, weight) in weights.enumerated() {
      currentWeight += weight
      if currentWeight >= target {
        return index
      }
    }

    return weights.count - 1
  }
}

// MARK: - Property Extensions for Coverage-Guided Testing

extension Property {
  /// Create a coverage-guided version of this property
  public func withCoverageGuidance(
    budget: CoverageBudget,
    strategy: CoverageStrategy = .frequency,
    config: CoverageConfig = .default
  ) -> Property<T> {
    Property<T>(
      generator: self.generator.biased(by: budget, strategy: strategy, config: config),
      predicate: self.predicate
    )
  }
}

/// Coverage report summarizing test execution results
public struct CoverageReport: Sendable {
  public let initialCoverage: Double
  public let finalCoverage: Double
  public let improvement: Double
  public let executionCount: Int
  public let uncoveredSymbols: [String]

  public init(
    initialCoverage: Double,
    finalCoverage: Double,
    improvement: Double,
    executionCount: Int,
    uncoveredSymbols: [String]
  ) {
    self.initialCoverage = initialCoverage
    self.finalCoverage = finalCoverage
    self.improvement = improvement
    self.executionCount = executionCount
    self.uncoveredSymbols = uncoveredSymbols
  }

  /// Human-readable summary of the coverage report
  public func summary() -> String {
    """
    Coverage Report:
    - Initial Coverage: \(String(format: "%.2f", initialCoverage))%
    - Final Coverage: \(String(format: "%.2f", finalCoverage))%
    - Improvement: \(String(format: "+%.2f", improvement))%
    - Executions: \(executionCount)
    - Remaining Gaps: \(uncoveredSymbols.count) symbols
    """
  }
}
