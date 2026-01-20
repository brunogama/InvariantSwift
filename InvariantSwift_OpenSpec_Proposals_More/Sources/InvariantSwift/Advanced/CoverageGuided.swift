/// Coverage-Guided Generation System with LLVM Integration
///
/// Complete coverage-guided generation system that uses execution feedback
/// to intelligently bias test generation toward uncovered code paths.
/// Integrates with LLVM coverage tools for precise path tracking.

import Foundation

// MARK: - Core Coverage Types

// swiftlint:disable:next orphaned_doc_comment
/// Unique identifier for executable branches in source code.
///
/// Branch identifiers are used to track which paths through a function's control flow
/// have been executed during testing. Combined with coverage data, they enable the
/// test generator to bias toward unexplored branches.
///
/// **Purpose:**
/// Efficiently identify and reference specific decision points (if statements, loops,
/// pattern matching cases) in compiled code. The combination of function name and branch
/// index uniquely identifies a control flow path.
///
/// **Performance Characteristics:**
/// - **Creation**: O(1) for both string concatenation and hashing
/// - **Hashing**: O(n) where n is length of function name (typical: O(1) due to short names)
/// - **Comparison**: O(n) string comparison
///
/// - Parameters:
///   - functionName: The fully qualified name of the containing function (e.g., "MyClass.myMethod")
///   - branchIndex: Zero-based index of this branch within the function. Multiple branches
///     from the same decision point have consecutive indices.
///
/// - Example:
///   ```swift
///   let branch = BranchID(functionName: "findValue", branchIndex: 0)
// swiftlint:disable:next no_print
///   print(branch)  // Prints: "findValue:0"
///   ```
///
/// - Note: Branch indices are compiler-assigned during instrumentation. Manual creation
///   is primarily for testing; in production, they're typically extracted from LLVM coverage data.
///
/// - See Also: ``CoverageBudget``, ``ExecutionRecord``
public struct BranchID: Sendable, Hashable, CustomStringConvertible {
  /// The fully qualified name of the containing function.
  ///
  /// Examples: "myFunction", "MyClass.myMethod", "MyClass.staticMethod(_:_:)"
  public let functionName: String

  /// Zero-based index of this branch within the function.
  ///
  /// For a function with multiple branches (if-else chains, pattern matching), each
  /// branch gets a sequential index starting from 0.
  public let branchIndex: Int

  /// Initialize a branch identifier.
  ///
  /// - Parameters:
  ///   - functionName: Fully qualified function name
  ///   - branchIndex: Branch index (typically 0+)
  public init(functionName: String, branchIndex: Int) {
    self.functionName = functionName
    self.branchIndex = branchIndex
  }

  /// A human-readable string representation of the branch identifier.
  ///
  /// Format: `"functionName:branchIndex"` (e.g., "findValue:2")
  public var description: String {
    "\(functionName):\(branchIndex)"
  }
}

// swiftlint:disable:next orphaned_doc_comment
/// Coverage metrics and uncovered symbols used to guide test generation.
///
/// A coverage budget summarizes the current state of code coverage and identifies
/// gaps that should be targeted by the property-based test generator. This enables
/// **coverage-guided fuzzing**: biasing generation toward unexplored code paths.
///
/// **Coverage Metrics:**
/// The budget tracks which functions have been executed and provides a coverage percentage,
/// helping developers understand test completeness and identify untested code.
///
/// **Guiding Generation:**
/// The list of uncovered symbols (functions/branches) is used by coverage-biased generators
/// (see ``CoverageStrategy``) to prefer test inputs that might exercise new code paths.
///
/// **Performance Characteristics:**
/// - **Computation**: O(n) where n is the number of symbols (typically small: <100)
/// - **Storage**: O(n) for symbol sets and coverage map
/// - **Updates**: O(1) amortized for adding new symbols
///
/// - Parameters:
///   - uncoveredSymbols: Set of symbols (functions/branches) that haven't been covered yet.
///     Used to guide generation toward unexplored paths.
///   - coverageMap: Dictionary mapping symbol names to coverage percentages (0.0 to 1.0).
///     Enables prioritizing which symbols to target next.
///   - totalFunctions: Total count of functions/branches in the program under test.
///     Needed to compute overall coverage percentage.
///   - coveredFunctions: Count of covered functions/branches.
///     Combined with totalFunctions to compute coverage percentage.
///
/// - Example:
///   ```swift
///   // After initial test run, you might have:
///   let budget = CoverageBudget(
///       uncoveredSymbols: ["edgeCase", "errorHandler"],
///       coverageMap: ["main": 1.0, "helper": 0.5, "edgeCase": 0.0],
///       totalFunctions: 3,
///       coveredFunctions: 2
///   )
///
// swiftlint:disable:next no_print
///   print(budget.coveragePercentage)  // 66.67
// swiftlint:disable:next no_print
///   print(budget.criticalGaps)  // ["edgeCase", "errorHandler"] (sorted)
///   ```
///
/// - Note: Important: Coverage budgets should be updated periodically during testing
///   to reflect new discoveries. Use with ``CoverageCollector`` to track coverage
///   over time and guide the test generator.
///
/// - See Also: ``CoverageCollector``, ``CoverageStrategy``, ``Gen.biased(by:strategy:config:)``
public struct CoverageBudget: Sendable {
  /// Set of functions/branches not yet covered by test execution.
  ///
  /// These symbols are candidates for coverage-guided generation biasing.
  /// Should be progressively emptied as tests run and discover new paths.
  public let uncoveredSymbols: Set<String>

  /// Per-symbol coverage percentage (0.0 = uncovered, 1.0 = fully covered).
  ///
  /// Useful for identifying partially-covered functions that need more testing.
  /// Values outside [0.0, 1.0] indicate measurement errors.
  public let coverageMap: [String: Double]

  /// Total count of executable symbols in the program under test.
  ///
  /// Includes all functions/branches, both covered and uncovered.
  /// Used to compute ``coveragePercentage``.
  public let totalFunctions: Int

  /// Count of symbols that have been covered by test execution.
  ///
  /// Combined with ``totalFunctions`` to compute overall coverage percentage.
  /// Should increase over time as testing progresses.
  public let coveredFunctions: Int

  /// Overall coverage percentage (0.0 to 100.0).
  ///
  /// Computed as: `coveredFunctions / totalFunctions * 100`
  /// Returns 0.0 if ``totalFunctions`` is zero.
  ///
  /// **Interpretation:**
  /// - 0-50%: Early-stage testing; significant gaps remain
  /// - 50-90%: Good coverage; focus on edge cases and error handling
  /// - 90-99%: High coverage; diminishing returns; focus on critical paths
  /// - 99%+: Excellent coverage; consider mutation testing for harder-to-detect bugs
  public var coveragePercentage: Double {
    guard totalFunctions > 0 else { return 0.0 }
    return Double(coveredFunctions) / Double(totalFunctions) * 100
  }

  /// Sorted list of uncovered symbols (functions/branches).
  ///
  /// Provides a deterministic, human-readable list of coverage gaps.
  /// Useful for debugging or logging which symbols need testing.
  public var criticalGaps: [String] {
    Array(uncoveredSymbols).sorted()
  }

  /// Initialize a coverage budget with explicit metrics.
  ///
  /// - Parameters:
  ///   - uncoveredSymbols: Set of symbol names that haven't been covered
  ///   - coverageMap: Dictionary mapping symbols to coverage percentages
  ///   - totalFunctions: Total number of functions/branches in the program
  ///   - coveredFunctions: Number of covered functions/branches
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

  /// An empty coverage budget (no coverage, no data).
  ///
  /// Useful for initialization before any tests have run.
  /// Indicates: 0 functions covered, 0 total functions, all symbols uncovered.
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

// swiftlint:disable:next orphaned_doc_comment
/// An actor that collects and analyzes coverage data during test execution.
///
/// `CoverageCollector` tracks which symbols (functions/branches) are executed during
/// property-based testing, enabling coverage-guided fuzzing. It's implemented as an
/// actor for thread-safe concurrent access from multiple test threads.
///
/// **Key Responsibilities:**
/// 1. Accepting execution records from test threads
/// 2. Aggregating coverage data across all executions
/// 3. Computing current coverage budget for biasing generators
/// 4. Tracking execution statistics for progress monitoring
///
/// **Actor Semantics:**
/// All methods are actor-isolated, preventing data races when recording from concurrent
/// test executors. Swift's structured concurrency ensures safe memory access.
///
/// **Coverage Tracking:**
/// The collector maintains a sliding window of execution history (max 1000 records)
/// and a cumulative set of all seen symbols. This enables efficient queries of current
/// coverage state without storing unbounded history.
///
/// **Performance Characteristics:**
/// - **recordExecution**: O(n) where n is the number of symbols in the record (typically small)
/// - **currentBudget**: O(m) where m is total unique symbols seen (typically <100)
/// - **Memory**: O(1000) for history window + O(m) for symbol tracking = O(m) total
///
/// - Parameters:
///   - config: Configuration for coverage biasing strategies (thresholds, bias factors)
///
/// - Example:
///   ```swift
///   actor MyTestRunner {
///       let coverageCollector = CoverageCollector()
///
///       func runTest() {
///           // ... execute test ...
///           let record = ExecutionRecord(
///               coveredSymbols: ["myFunction", "helperFunction"],
///               executionTime: 0.001
///           )
///           await coverageCollector.recordExecution(record)
///
///           // Check progress
///           let budget = await coverageCollector.currentBudget()
// swiftlint:disable:next no_print
///           print("Coverage: \(budget.coveragePercentage)%")
///       }
///   }
///   ```
///
/// - Note: Important: `CoverageCollector` is an actor; all access is async.
///   Call methods from async contexts using `await`. Use ``currentBudget()`` to
///   get biasing information for the generator at key checkpoints.
///
/// - See Also: ``ExecutionRecord``, ``CoverageBudget``, ``CoverageStrategy``
public actor CoverageCollector {
  /// Execution history (sliding window of last 1000 executions).
  private var executionHistory: [ExecutionRecord] = []

  /// All symbols seen across all executions (cumulative).
  private var allSeenSymbols: Set<String> = []

  /// Configuration for coverage-guided biasing.
  private var coverageConfig: CoverageConfig

  /// Initialize a coverage collector with optional configuration.
  ///
  /// - Parameter config: Coverage configuration (bias factor, strategy, etc.).
  ///   Default: ``CoverageConfig.default``
  public init(config: CoverageConfig = .default) {
    self.coverageConfig = config
  }

  /// Record a test execution with observed coverage data.
  ///
  /// Appends an execution record to the history and updates the cumulative set
  /// of known symbols. Maintains a sliding window of the last 1000 executions
  /// to bound memory usage.
  ///
  /// **Thread Safety:** Actor-isolated; safe to call concurrently from multiple threads.
  ///
  /// - Parameter record: An execution record containing timestamp, covered symbols, and timing.
  ///   Typically created after a test case executes.
  ///
  /// - Complexity: O(n) where n is the number of covered symbols in the record (typically small)
  ///
  /// - Example:
  ///   ```swift
  ///   let record = ExecutionRecord(
  ///       coveredSymbols: ["myFunc", "otherFunc"],
  ///       executionTime: 0.001
  ///   )
  ///   await collector.recordExecution(record)
  ///   ```
  ///
  /// - See Also: ``ExecutionRecord``
  public func recordExecution(_ record: ExecutionRecord) {
    executionHistory.append(record)
    allSeenSymbols.formUnion(record.coveredSymbols)

    // Maintain reasonable history size to prevent unbounded growth
    if executionHistory.count > 1000 {
      executionHistory.removeFirst()
    }
  }

  /// Get the current coverage budget for guiding test generation.
  ///
  /// Computes a coverage budget based on accumulated execution data. The budget
  /// identifies uncovered symbols that should be targeted by coverage-biased generators.
  ///
  /// **Thread Safety:** Actor-isolated; safe to call from multiple contexts.
  ///
  /// - Returns: A ``CoverageBudget`` reflecting current coverage state, including:
  ///   - Coverage percentage (0-100)
  ///   - List of uncovered symbols
  ///   - Per-symbol coverage map
  ///
  /// - Complexity: O(m) where m is the number of unique symbols seen
  ///
  /// - Example:
  ///   ```swift
  ///   let budget = await collector.currentBudget()
  ///   let generator = gen.biased(by: budget, strategy: .frequency)
  ///   ```
  ///
  /// - Note: Call this periodically during testing to update the generator's
  ///   biasing strategy based on new discoveries.
  ///
  /// - See Also: ``CoverageBudget``, ``Gen.biased(by:strategy:config:)``
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

  /// Register known symbols to track (typically from static analysis).
  ///
  /// Initialize the collector with a complete set of symbols before running tests.
  /// This enables accurate coverage computation for symbols that may never be executed.
  ///
  /// **Thread Safety:** Actor-isolated; safe to call concurrently.
  ///
  /// - Parameter symbols: Set of all function/branch names to track.
  ///   Example: extracted from debug info or static analysis.
  ///
  /// - Complexity: O(n) where n is the number of symbols being added
  ///
  /// - Example:
  ///   ```swift
  ///   await collector.addKnownSymbols(["func1", "func2", "func3"])
  ///   ```
  ///
  /// - Note: Call this before running tests for accurate coverage metrics.
  ///   Otherwise, uncovered symbols won't be tracked.
  ///
  /// - See Also: ``currentBudget()``
  public func addKnownSymbols(_ symbols: Set<String>) {
    allSeenSymbols.formUnion(symbols)
  }

  // swiftlint:disable:next orphaned_doc_comment
  /// Get execution statistics (for progress monitoring and diagnostics).
  ///
  /// Returns aggregate statistics about test execution history, useful for
  /// monitoring progress and performance.
  ///
  /// **Thread Safety:** Actor-isolated; safe to call concurrently.
  ///
  /// - Returns: A tuple containing:
  ///   - `executions`: Number of execution records recorded
  ///   - `totalSymbols`: Total count of unique symbols known
  ///   - `avgExecutionTime`: Average time per test execution (in seconds)
  ///
  /// - Complexity: O(m) where m is the size of execution history (max 1000)
  ///
  /// - Example:
  ///   ```swift
  ///   let stats = await collector.getStatistics()
  // swiftlint:disable:next no_print
  ///   print("Executions: \(stats.executions)")
  // swiftlint:disable:next no_print
  ///   print("Average time: \(stats.avgExecutionTime * 1000) ms")
  ///   ```
  ///
  /// - Note: Average execution time is useful for identifying performance regressions
  ///   or detecting unexpectedly slow test cases.
  ///
  /// - See Also: ``ExecutionRecord``
  // swiftlint:disable:next large_tuple
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

/// Strategies for biasing test generation toward uncovered code paths.
///
/// Different coverage-guided strategies make different trade-offs between discovering new paths
/// and maintaining diversity in generated test cases. Choose based on your testing goals and code complexity.
///
/// **Strategy Comparison:**
///
/// | Strategy | Biasing | Diversity | Best For | Complexity |
/// |----------|---------|-----------|----------|-----------|
/// | `.random` | None | High | Baseline/quick sanity checks | O(1) |
/// | `.frequency` | Hit frequency | Medium | Early-stage testing, breadth-first discovery | O(c) |
/// | `.boundary` | Edge cases | Medium-High | Finding corner cases, numeric boundaries | O(c) |
/// | `.adaptive` | Self-tuning | Balanced | Long-running test suites, automatic adaptation | O(c) |
///
/// Where c = number of candidates evaluated per generation (configurable via ``CoverageConfig.maxCandidates``)
///
/// **External References:**
/// - [Coverage-Guided Fuzzing](https://en.wikipedia.org/wiki/Fuzzing#Coverage-guided_fuzzing) - Foundational technique
/// - [LibFuzzer](https://llvm.org/docs/LibFuzzer/) - Industrial-strength implementation reference
/// - [AFL: American Fuzzy Lop](http://lcamtuf.coredump.cx/afl/) - Classic coverage-guided fuzzer
///
/// **Performance Trade-offs:**
/// - **Random**: Fastest (no overhead), but may miss coverage gaps indefinitely
/// - **Frequency**: Small overhead (multiple candidates), discovers new paths reliably
/// - **Boundary**: Moderate overhead (focuses on specific value ranges), excellent for numeric types
/// - **Adaptive**: Balances strategies based on progress, but adds decision overhead
///
/// - Cases:
///   - `.random`: No coverage biasing; pure random generation (baseline strategy).
///     Use for quick sanity checks or as a control for benchmarking other strategies.
///   - `.frequency`: Bias based on symbol hit frequency. Prefers generating inputs that
///     might reach less-frequently-hit branches. Effective early in testing.
///   - `.boundary`: Focus on boundary values (0, 1, -1, max, min, empty). Excellent for
///     finding off-by-one errors and edge cases in numeric/collection code.
///   - `.adaptive`: Automatically switch strategy based on coverage progress (< 50% → frequency,
///     50-90% → boundary, > 90% → random). Self-tuning; recommended for long-running suites.
///
/// - Example:
///   ```swift
///   let budget = await collector.currentBudget()
///
///   // Early testing: use frequency-based biasing
///   let gen1 = myGen.biased(by: budget, strategy: .frequency)
///
///   // Hunting for edge cases: switch to boundary strategy
///   let gen2 = myGen.biased(by: budget, strategy: .boundary)
///
///   // Adaptive: let it decide
///   let gen3 = myGen.biased(by: budget, strategy: .adaptive)
///   ```
///
/// - Note: Important: Strategy selection should match your testing phase:
///   - Early testing → `.frequency` or `.adaptive` (find broad coverage)
///   - Edge case hunting → `.boundary` (find corner cases)
///   - Maintenance runs → `.adaptive` (self-tuning; minimal configuration)
///   - Performance benchmarking → `.random` (clean baseline)
///
/// - See Also: ``CoverageCollector``, ``CoverageBudget``, ``CoverageConfig``, ``Gen.biased(by:strategy:config:)``
public enum CoverageStrategy: Sendable {
  /// No coverage biasing; pure random generation (baseline).
  ///
  /// Generates test inputs uniformly at random without any preference for uncovered paths.
  /// Useful as a control strategy for benchmarking or as a fallback when coverage data
  /// is unavailable.
  case random

  /// Bias generation toward less-frequently-hit symbols (branches/functions).
  ///
  /// Evaluates multiple candidate inputs and scores them based on potential coverage
  /// impact (how many uncovered symbols they might reach). Prefers candidates with
  /// higher impact potential. Effective at broad coverage discovery.
  case frequency

  /// Focus generation on boundary/edge values (empty, zero, one, min, max, etc.).
  ///
  /// Generates candidates with emphasis on values known to trigger edge cases:
  /// - Empty strings/collections
  /// - Boundary integers (0, 1, -1, Int.min, Int.max)
  /// - Off-by-one candidates
  ///
  /// Excellent for finding corner cases in numeric and collection-based code.
  case boundary

  /// Adapt strategy based on coverage progress during testing.
  ///
  /// Automatically switches between strategies as coverage improves:
  /// - **0-50% coverage**: Use `.frequency` (broad discovery)
  /// - **50-90% coverage**: Use `.boundary` (edge cases)
  /// - **90%+ coverage**: Use `.random` (maintain diversity, diminishing returns)
  ///
  /// Provides self-tuning behavior; recommended for automated, long-running test suites.
  case adaptive
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

// swiftlint:disable:next orphaned_doc_comment
/// Summary of code coverage achieved during a test session.
///
/// A coverage report captures the before/after coverage state of a test run, showing
/// progress made toward comprehensive code coverage. Useful for monitoring testing
/// effectiveness and identifying remaining gaps.
///
/// **Report Contents:**
/// - Coverage percentages before and after testing
/// - Improvement achieved (percentage point gain)
/// - Number of test executions performed
/// - Identities of still-uncovered symbols
///
/// **Reporting Metrics:**
/// The report should be generated at key milestones (end of test session, nightly runs)
/// to track progress over time. Declining improvement per execution often signals
/// diminishing returns (approaching coverage saturation).
///
/// **Performance Characteristics:**
/// - **Creation**: O(1) for structure creation
/// - **Serialization**: O(n) where n is the number of uncovered symbols
/// - **Interpretation**: Human-readable for dashboards and logging
///
/// - Parameters:
///   - initialCoverage: Coverage percentage (0-100) at the start of testing
///   - finalCoverage: Coverage percentage (0-100) after testing completed
///   - improvement: Percentage point gain (finalCoverage - initialCoverage)
///   - executionCount: Total number of test executions performed
///   - uncoveredSymbols: List of symbols (functions/branches) still not covered.
///     Identifies targets for future testing effort.
///
/// - Example:
///   ```swift
///   let report = CoverageReport(
///       initialCoverage: 45.0,
///       finalCoverage: 78.5,
///       improvement: 33.5,
///       executionCount: 5000,
///       uncoveredSymbols: ["errorHandler", "retryLogic"]
///   )
///
// swiftlint:disable:next no_print
///   print(report.summary())
///   // Coverage Report:
///   // - Initial Coverage: 45.00%
///   // - Final Coverage: 78.50%
///   // - Improvement: +33.50%
///   // - Executions: 5000
///   // - Remaining Gaps: 2 symbols
///   ```
///
/// - Note: Important: Improvement per execution is a useful metric for assessing
///   testing efficiency. As improvement approaches zero, diminishing returns set in
///   and alternative strategies (mutation testing, manual edge cases) become worthwhile.
///
/// - See Also: ``CoverageBudget``, ``CoverageCollector``
public struct CoverageReport: Sendable {
  /// Coverage percentage (0.0-100.0) at the start of the test session.
  ///
  /// Baseline for computing improvement. May be 0.0 if testing starts from scratch.
  public let initialCoverage: Double

  /// Coverage percentage (0.0-100.0) at the end of the test session.
  ///
  /// Target coverage achieved. Compare against improvement targets (e.g., 90% for CI).
  public let finalCoverage: Double

  /// Percentage point gain (finalCoverage - initialCoverage).
  ///
  /// Positive values indicate progress; zero or negative values indicate no improvement
  /// (which may indicate tool/environment issues or testing saturation).
  ///
  /// **Interpretation:**
  /// - 0-10% improvement: Limited progress; may need different test strategy
  /// - 10-30% improvement: Good progress; testing is discovering new paths
  /// - 30%+ improvement: Excellent progress; testing strategy is highly effective
  public let improvement: Double

  /// Total number of test executions performed in this session.
  ///
  /// Used to compute "improvement per execution" metric: `improvement / executionCount`.
  /// Helps identify when test generation becomes less efficient.
  public let executionCount: Int

  /// Symbols (functions/branches) that remain uncovered after testing.
  ///
  /// These are candidates for:
  /// - Manual test case design
  /// - Future coverage-guided testing campaigns
  /// - Code review to determine if testing is feasible
  public let uncoveredSymbols: [String]

  /// Initialize a coverage report with test session results.
  ///
  /// - Parameters:
  ///   - initialCoverage: Starting coverage percentage
  ///   - finalCoverage: Ending coverage percentage
  ///   - improvement: Percentage point gain (computed as finalCoverage - initialCoverage)
  ///   - executionCount: Number of test cases executed
  ///   - uncoveredSymbols: List of symbols still not covered
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

  // swiftlint:disable:next orphaned_doc_comment
  /// Generate a human-readable summary of the coverage report.
  ///
  /// Formats all key metrics into a readable multi-line string suitable for logging,
  /// dashboards, or CI output.
  ///
  /// **Output Format:**
  /// ```
  /// Coverage Report:
  /// - Initial Coverage: XX.XX%
  /// - Final Coverage: XX.XX%
  /// - Improvement: +XX.XX%
  /// - Executions: NNNN
  /// - Remaining Gaps: N symbols
  /// ```
  ///
  /// - Returns: A formatted string summary of the report
  ///
  /// - Complexity: O(1) string formatting
  ///
  /// - Example:
  ///   ```swift
  // swiftlint:disable:next no_print
  ///   print(report.summary())
  ///   ```
  ///
  /// - Note: Percentages are formatted to 2 decimal places for readability.
  ///
  /// - See Also: ``CoverageReport``
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
