// MARK: - ISP-0008: Targeted Runner
// Orchestrates targeted property testing with feedback loop.

import Foundation

// MARK: - Elite Pool

/// Priority queue of best inputs for exploitation
public actor ElitePool<T: Sendable> {
  private var inputs: [ScoredInput<T>] = []
  private let maxSize: Int

  public var isEmpty: Bool { inputs.isEmpty }
  public var count: Int { inputs.count }
  public var minScore: Double { inputs.last?.score ?? -.infinity }

  public init(maxSize: Int) {
    self.maxSize = max(1, maxSize)
  }

  /// Insert a scored input, maintaining max size
  public func insert(_ scored: ScoredInput<T>) {
    // Insert in sorted order (descending by score)
    let insertIndex = inputs.firstIndex { $0.score < scored.score } ?? inputs.endIndex
    inputs.insert(scored, at: insertIndex)

    // Trim to max size
    if inputs.count > maxSize {
      inputs.removeLast()
    }
  }

  /// Get a random elite input for mutation
  public func randomElement() -> ScoredInput<T>? {
    guard !inputs.isEmpty else { return nil }
    return inputs.randomElement()
  }

  /// Get all inputs
  public func getAll() -> [ScoredInput<T>] {
    inputs
  }
}

// MARK: - Targeted Runner Result

/// Result from a targeted property test run
public struct TargetedRunResult<T: Sendable>: Sendable {
  /// Whether the test passed
  public let passed: Bool

  /// Total iterations run
  public let iterations: Int

  /// Best inputs found (sorted by score descending)
  public let bestInputs: [ScoredInput<T>]

  /// Target statistics across all iterations
  public let statistics: TargetStatistics

  /// Optional failure information
  public let failure: (input: T, error: Error)?

  public init(
    passed: Bool,
    iterations: Int,
    bestInputs: [ScoredInput<T>],
    statistics: TargetStatistics,
    failure: (input: T, error: Error)? = nil
  ) {
    self.passed = passed
    self.iterations = iterations
    self.bestInputs = bestInputs
    self.statistics = statistics
    self.failure = failure
  }
}

// MARK: - Targeted Runner

/// Runs property tests with targeted feedback to find interesting inputs
public struct TargetedRunner<T: Sendable> {
  /// Configuration for targeted testing
  public let config: TargetedConfig

  /// Generator for initial inputs
  public let generator: () -> T

  /// Optional mutator for elite inputs
  public let mutator: ((T) -> T)?

  public init(
    config: TargetedConfig = .default,
    generator: @escaping () -> T,
    mutator: ((T) -> T)? = nil
  ) {
    self.config = config
    self.generator = generator
    self.mutator = mutator
  }

  /// Run a targeted property test
  /// - Parameters:
  ///   - iterations: Number of iterations to run
  ///   - property: The property to test, receives input and target collector
  /// - Returns: Result containing pass/fail, best inputs, and statistics
  public func run(
    iterations: Int,
    property: (T, TargetCollector) throws -> Void
  ) async -> TargetedRunResult<T> {
    let elitePool = ElitePool<T>(maxSize: config.elitePoolSize)
    let history = TargetHistory()
    let collector = TargetCollector()

    var failureInfo: (input: T, error: Error)?

    for iteration in 0..<iterations {
      // Generate input: either mutate elite or generate fresh
      let input: T
      if Double.random(in: 0...1) < config.explorationRate {
        input = generator()
      } else if let elite = await elitePool.randomElement(), let mutator {
        input = mutator(elite.input)
      } else {
        input = generator()
      }

      // Run the property, collecting targets
      collector.clear()
      do {
        try property(input, collector)
      } catch {
        failureInfo = (input, error)
        break
      }

      // Score this iteration
      let targets = collector.targets
      let score = computeScore(targets: targets, history: history, strategy: config.targetStrategy)

      // Record in history
      history.record(targets, iteration: iteration)

      // Add to elite pool if good enough
      let scored = ScoredInput(input: input, score: score, targets: targets, iteration: iteration)
      let currentMinScore = await elitePool.minScore
      let poolIsEmpty = await elitePool.isEmpty
      if score > currentMinScore || poolIsEmpty {
        await elitePool.insert(scored)
      }
    }

    // Compute final statistics
    let statistics = history.computeStatistics()
    let bestInputs = await elitePool.getAll()

    return TargetedRunResult(
      passed: failureInfo == nil,
      iterations: iterations,
      bestInputs: bestInputs,
      statistics: statistics,
      failure: failureInfo
    )
  }

  /// Compute score based on strategy
  private func computeScore(
    targets: [TargetRecord],
    history: TargetHistory,
    strategy: TargetStrategy
  ) -> Double {
    guard !targets.isEmpty else { return 0 }

    switch strategy {
    case .pareto:
      return computeParetoScore(targets: targets, history: history)

    case .weighted(let weights):
      return computeWeightedScore(targets: targets, weights: weights)

    case .lexicographic:
      return computeLexicographicScore(targets: targets)
    }
  }

  private func computeParetoScore(targets: [TargetRecord], history: TargetHistory) -> Double {
    targets.reduce(0) { sum, target in
      let label = target.label ?? "unlabeled"
      let best = history.best(for: label) ?? target.value
      guard best != 0 else { return sum + target.score }
      return sum + target.score / abs(best)
    }
  }

  private func computeWeightedScore(targets: [TargetRecord], weights: [String: Double]) -> Double {
    targets.reduce(0) { sum, target in
      let label = target.label ?? "unlabeled"
      let weight = weights[label] ?? 1.0
      return sum + target.score * weight
    }
  }

  private func computeLexicographicScore(targets: [TargetRecord]) -> Double {
    targets.enumerated().reduce(0) { sum, pair in
      let weight = pow(10.0, Double(targets.count - pair.offset - 1))
      return sum + pair.element.score * weight
    }
  }
}
