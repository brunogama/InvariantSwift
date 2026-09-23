import InvariantSwiftCore
import Foundation

// MARK: - FlakeHunter + PropertyTest Integration

/// Configuration for flaky test detection.
public struct FlakeDetectionConfig: Sendable {
  /// Number of times to run the test
  public let runs: Int

  /// Seeds to use (if nil, generates random seeds)
  public let seeds: [UInt64]?

  /// Flakiness threshold (0.0-1.0) above which test is considered flaky
  public let flakinessThreshold: Double

  /// Whether to fail the test if flaky (vs just warn)
  public let failOnFlaky: Bool

  /// Storage URL for FlakeHunter persistence
  public let storageURL: URL?

  public init(
    runs: Int = 100,
    seeds: [UInt64]? = nil,
    flakinessThreshold: Double = 0.01,  // 1% failure rate = flaky
    failOnFlaky: Bool = false,
    storageURL: URL? = nil
  ) {
    self.runs = runs
    self.seeds = seeds
    self.flakinessThreshold = flakinessThreshold
    self.failOnFlaky = failOnFlaky
    self.storageURL = storageURL
  }

  public static let `default` = Self()
}

/// Result of flaky test detection.
public struct FlakeDetectionResult<T: Sendable>: Sendable {
  /// Total runs performed
  public let totalRuns: Int

  /// Number of passes
  public let passes: Int

  /// Number of failures
  public let failures: Int

  /// Seeds that caused failures
  public let failingSeeds: [UInt64]

  /// Flakiness score (0.0 = stable, 1.0 = maximally flaky)
  public let flakinessScore: Double

  /// Whether test is considered flaky
  public let isFlaky: Bool

  /// Recommended action
  public let recommendation: FlakeRecommendation

  /// Full statistics from FlakeHunter
  public let statistics: FlakeStatistics?

  public init(
    totalRuns: Int,
    passes: Int,
    failures: Int,
    failingSeeds: [UInt64],
    flakinessScore: Double,
    isFlaky: Bool,
    recommendation: FlakeRecommendation,
    statistics: FlakeStatistics?
  ) {
    self.totalRuns = totalRuns
    self.passes = passes
    self.failures = failures
    self.failingSeeds = failingSeeds
    self.flakinessScore = flakinessScore
    self.isFlaky = isFlaky
    self.recommendation = recommendation
    self.statistics = statistics
  }
}

/// Recommended action based on flakiness analysis
public enum FlakeRecommendation: String, Sendable {
  case stable = "Test is stable, no action needed"
  case investigate = "Test shows some flakiness, investigate"
  case quarantine = "Test is highly flaky, consider quarantining"
  case fix = "Test fails consistently, fix the underlying issue"
}

// MARK: - Safe Collection Access

extension Collection {
  /// Safe subscript that returns nil instead of crashing
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

// MARK: - PropertyTest Integration

/// Runs a property test multiple times to detect flakiness.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public func runPropertyWithFlakeDetection<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig = .default,
  flakeConfig: FlakeDetectionConfig = .default,
  testId: String
) async throws -> FlakeDetectionResult<T> {
  // Create FlakeHunter instance
  let hunter = try await FlakeHunter(
    config: FlakeHunter.Config(
      minimumExecutions: flakeConfig.runs,
      flakinessThreshold: flakeConfig.flakinessThreshold
    ),
    storageURL: flakeConfig.storageURL
  )

  var passes = 0
  var failures = 0
  var failingSeeds: [UInt64] = []
  // The environment does not change between runs; capture it once.
  let environment = ExecutionEnvironment()

  // Run the test multiple times with different seeds
  for i in 0..<flakeConfig.runs {
    let seed = flakeConfig.seeds?[safe: i] ?? UInt64.random(in: 0...UInt64.max)
    // TODO: PropertyConfig.seed is immutable - need API redesign
    // Cannot set seed per run without mutable seed field

    let startTime = Date().timeIntervalSinceReferenceDate
    let runner = PropertyRunner()
    let result = await runner.runProperty(property, config: config)
    let duration = Date().timeIntervalSinceReferenceDate - startTime

    let outcome: TestResult
    switch result {
    case .success:
      passes += 1
      outcome = .passed

    case .failure, .gaveUp:
      failures += 1
      failingSeeds.append(seed)
      outcome = .failed
    }

    // Every run feeds the hunter's history; without this, getStatistics
    // below has nothing to summarise and the result carries no statistics.
    await hunter.recordExecution(
      TestExecution(
        testId: testId,
        result: outcome,
        duration: duration,
        environment: environment,
        seed: seed,
        iterations: config.iterations
      )
    )
  }

  // Get statistics from FlakeHunter
  let statistics = await hunter.getStatistics(for: testId)

  // Calculate flakiness score
  // Score is based on the minority outcome (0.0 = consistent, 0.5 = maximally flaky)
  let flakinessScore = Double(min(passes, failures)) / Double(flakeConfig.runs)
  let isFlaky = flakinessScore > flakeConfig.flakinessThreshold

  let recommendation = flakeRecommendation(
    failures: failures,
    runs: flakeConfig.runs,
    flakinessScore: flakinessScore
  )

  return FlakeDetectionResult(
    totalRuns: flakeConfig.runs,
    passes: passes,
    failures: failures,
    failingSeeds: failingSeeds,
    flakinessScore: flakinessScore,
    isFlaky: isFlaky,
    recommendation: recommendation,
    statistics: statistics
  )
}

/// Recommended action for a run's outcome mix.
private func flakeRecommendation(
  failures: Int,
  runs: Int,
  flakinessScore: Double
) -> FlakeRecommendation {
  if failures == 0 {
    return .stable
  }
  if failures == runs {
    return .fix
  }
  return flakinessScore > 0.1 ? .quarantine : .investigate
}
