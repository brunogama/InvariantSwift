import Foundation

// MARK: - FlakeHunter Statistical Analysis Types
//
// Data types for flake statistics, pattern analysis, and resource correlation.
// Extracted from FlakeHunter.swift to keep the actor file under budget.

// MARK: - Flake Detection Statistics

/// **Flake detection statistics**
public struct FlakeStatistics: Codable, Sendable {
  /// Total number of executions
  public let totalExecutions: Int

  /// Number of failures
  public let failures: Int

  /// Failure rate (0.0 to 1.0)
  public let failureRate: Double

  /// Statistical confidence level
  public let confidence: Double

  /// Is this test statistically flaky?
  public let isFlaky: Bool

  /// Flakiness score (0.0 to 1.0)
  public let flakinessScore: Double

  /// Pattern analysis results
  public let patterns: FlakePatterns

  public init(executions: [TestExecution]) {
    self.totalExecutions = executions.count
    self.failures = executions.filter { $0.result.isFailure }.count
    self.failureRate = totalExecutions > 0 ? Double(failures) / Double(totalExecutions) : 0.0

    // Calculate statistical confidence using binomial distribution
    (self.confidence, self.isFlaky) = Self.calculateFlakeConfidence(
      executions: totalExecutions,
      failures: failures,
      threshold: 0.95
    )

    // Calculate flakiness score based on multiple factors
    self.flakinessScore = Self.calculateFlakinessScore(executions)

    // Analyze patterns in the execution history
    self.patterns = FlakePatterns(executions: executions)
  }

  // MARK: - Codable Protocol Witness
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.totalExecutions = try container.decode(Int.self, forKey: .totalExecutions)
    self.failures = try container.decode(Int.self, forKey: .failures)
    self.failureRate = try container.decode(Double.self, forKey: .failureRate)
    self.confidence = try container.decode(Double.self, forKey: .confidence)
    self.isFlaky = try container.decode(Bool.self, forKey: .isFlaky)
    self.flakinessScore = try container.decode(Double.self, forKey: .flakinessScore)
    self.patterns = try container.decode(FlakePatterns.self, forKey: .patterns)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(totalExecutions, forKey: .totalExecutions)
    try container.encode(failures, forKey: .failures)
    try container.encode(failureRate, forKey: .failureRate)
    try container.encode(confidence, forKey: .confidence)
    try container.encode(isFlaky, forKey: .isFlaky)
    try container.encode(flakinessScore, forKey: .flakinessScore)
    try container.encode(patterns, forKey: .patterns)
  }

  private enum CodingKeys: String, CodingKey {
    case totalExecutions, failures, failureRate, confidence, isFlaky, flakinessScore, patterns
  }

  private static func calculateFlakeConfidence(
    executions: Int,
    failures: Int,
    threshold: Double
  ) -> (confidence: Double, isFlaky: Bool) {
    guard executions >= 10 else {
      return (0.0, false)  // Need minimum sample size
    }

    let p = Double(failures) / Double(executions)

    // For a test to be flaky, it should neither always pass nor always fail
    // We expect flaky tests to have failure rates between 0.05 and 0.95
    guard p > 0.05 && p < 0.95 else {
      return (1.0, false)  // Consistently failing or passing
    }

    // Calculate confidence interval for binomial proportion
    let z = 1.96  // 95% confidence
    let standardError = sqrt((p * (1 - p)) / Double(executions))
    let margin = z * standardError

    let lowerBound = max(0.0, p - margin)
    let upperBound = min(1.0, p + margin)

    // Test is flaky if the confidence interval excludes 0 and 1
    let isFlaky = lowerBound > 0.01 && upperBound < 0.99
    let confidence = 1.0 - (upperBound - lowerBound)

    return (confidence, isFlaky)
  }

  private static func calculateFlakinessScore(_ executions: [TestExecution]) -> Double {
    guard executions.count >= 5 else { return 0.0 }

    var score = 0.0

    // Factor 1: Failure rate variance (flaky tests have inconsistent failure rates)
    let failureRate =
      Double(executions.filter { $0.result.isFailure }.count) / Double(executions.count)
    let varianceScore = 4.0 * failureRate * (1.0 - failureRate)  // Maximum at p=0.5
    score += varianceScore * 0.4

    // Factor 2: Temporal clustering (failures clustered in time suggest environmental issues)
    let sortedExecutions = executions.sorted { $0.timestamp < $1.timestamp }
    var clusteringScore = 0.0
    var consecutiveFailures = 0
    var maxConsecutiveFailures = 0

    for execution in sortedExecutions {
      if execution.result.isFailure {
        consecutiveFailures += 1
        maxConsecutiveFailures = max(maxConsecutiveFailures, consecutiveFailures)
      } else {
        consecutiveFailures = 0
      }
    }

    // Penalize high clustering (suggests systematic issues, not flakiness)
    if maxConsecutiveFailures > executions.count / 3 {
      clusteringScore = -0.3
    }
    score += clusteringScore * 0.2

    // Factor 3: Environment correlation
    let environmentGroups = Dictionary(grouping: executions) { $0.environment.environmentHash }
    let environmentVariance = environmentGroups.values.map { group -> Double in
      let failures = group.filter { $0.result.isFailure }.count
      return Double(failures) / Double(group.count)
      // swiftlint:disable:next multiline_function_chains
    }.variance()

    score += environmentVariance * 0.3

    // Factor 4: Duration variance (flaky tests often have variable execution times)
    let durations = executions.map { $0.duration }
    let durationCV = durations.standardDeviation() / durations.average()
    score += min(1.0, durationCV) * 0.1

    return max(0.0, min(1.0, score))
  }
}

// MARK: - Pattern Analysis

/// **Pattern analysis in flaky test behavior**
public struct FlakePatterns: Codable, Sendable {
  /// Tendency to fail in CI vs local environments
  public let ciFailureRate: Double
  public let localFailureRate: Double

  /// Time-based patterns
  public let timePatterns: TimePatterns

  /// Environment correlation
  public let environmentCorrelation: Double

  /// Resource usage correlation
  public let resourceCorrelation: ResourceCorrelation

  public init(executions: [TestExecution]) {
    // Analyze CI vs local failure rates
    let ciExecutions = executions.filter { $0.environment.isCIEnvironment }
    let localExecutions = executions.filter { !$0.environment.isCIEnvironment }

    self.ciFailureRate = Self.calculateFailureRate(ciExecutions)
    self.localFailureRate = Self.calculateFailureRate(localExecutions)

    // Analyze time-based patterns
    self.timePatterns = TimePatterns(executions: executions)

    // Calculate environment correlation
    self.environmentCorrelation = Self.calculateEnvironmentCorrelation(executions)

    // Analyze resource usage correlation
    self.resourceCorrelation = ResourceCorrelation(executions: executions)
  }

  // MARK: - Codable Protocol Witness
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.ciFailureRate = try container.decode(Double.self, forKey: .ciFailureRate)
    self.localFailureRate = try container.decode(Double.self, forKey: .localFailureRate)
    self.timePatterns = try container.decode(TimePatterns.self, forKey: .timePatterns)
    self.environmentCorrelation = try container.decode(Double.self, forKey: .environmentCorrelation)
    self.resourceCorrelation = try container.decode(
      ResourceCorrelation.self,
      forKey: .resourceCorrelation
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(ciFailureRate, forKey: .ciFailureRate)
    try container.encode(localFailureRate, forKey: .localFailureRate)
    try container.encode(timePatterns, forKey: .timePatterns)
    try container.encode(environmentCorrelation, forKey: .environmentCorrelation)
    try container.encode(resourceCorrelation, forKey: .resourceCorrelation)
  }

  private enum CodingKeys: String, CodingKey {
    case ciFailureRate, localFailureRate, timePatterns, environmentCorrelation, resourceCorrelation
  }

  private static func calculateFailureRate(_ executions: [TestExecution]) -> Double {
    guard !executions.isEmpty else { return 0.0 }
    let failures = executions.filter { $0.result.isFailure }.count
    return Double(failures) / Double(executions.count)
  }

  private static func calculateEnvironmentCorrelation(_ executions: [TestExecution]) -> Double {
    // Calculate correlation between environment hash and failure rate
    let environmentGroups = Dictionary(grouping: executions) { $0.environment.environmentHash }
    guard environmentGroups.count > 1 else { return 0.0 }

    let failureRates = environmentGroups.values.map { group in
      calculateFailureRate(Array(group))
    }

    return failureRates.standardDeviation()
  }
}

// MARK: - Time Patterns

/// **Time-based pattern analysis**
public struct TimePatterns: Codable, Sendable {
  /// Failure rate by hour of day
  public let hourlyPattern: [Int: Double]

  /// Failure rate by day of week
  public let dailyPattern: [Int: Double]

  /// Trend over time
  public let trend: Trend

  public init(executions: [TestExecution]) {
    self.hourlyPattern = Self.calculateHourlyPattern(executions)
    self.dailyPattern = Self.calculateDailyPattern(executions)
    self.trend = Self.calculateTrend(executions)
  }

  // MARK: - Codable Protocol Witness
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.hourlyPattern = try container.decode([Int: Double].self, forKey: .hourlyPattern)
    self.dailyPattern = try container.decode([Int: Double].self, forKey: .dailyPattern)
    self.trend = try container.decode(Trend.self, forKey: .trend)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(hourlyPattern, forKey: .hourlyPattern)
    try container.encode(dailyPattern, forKey: .dailyPattern)
    try container.encode(trend, forKey: .trend)
  }

  private enum CodingKeys: String, CodingKey {
    case hourlyPattern, dailyPattern, trend
  }

  private static func calculateHourlyPattern(_ executions: [TestExecution]) -> [Int: Double] {
    let calendar = Calendar.current
    let groups = Dictionary(grouping: executions) { execution in
      calendar.component(.hour, from: execution.timestamp)
    }

    return groups.mapValues { group in
      let failures = group.filter { $0.result.isFailure }.count
      return Double(failures) / Double(group.count)
    }
  }

  private static func calculateDailyPattern(_ executions: [TestExecution]) -> [Int: Double] {
    let calendar = Calendar.current
    let groups = Dictionary(grouping: executions) { execution in
      calendar.component(.weekday, from: execution.timestamp)
    }

    return groups.mapValues { group in
      let failures = group.filter { $0.result.isFailure }.count
      return Double(failures) / Double(group.count)
    }
  }

  private static func calculateTrend(_ executions: [TestExecution]) -> Trend {
    guard executions.count >= 10 else { return .stable }

    let sorted = executions.sorted { $0.timestamp < $1.timestamp }
    let recentHalf = Array(sorted.suffix(sorted.count / 2))
    let olderHalf = Array(sorted.prefix(sorted.count / 2))

    let recentFailureRate =
      Double(recentHalf.filter { $0.result.isFailure }.count) / Double(recentHalf.count)
    let olderFailureRate =
      Double(olderHalf.filter { $0.result.isFailure }.count) / Double(olderHalf.count)

    let difference = recentFailureRate - olderFailureRate

    if difference > 0.1 {
      return .worsening
    } else if difference < -0.1 {
      return .improving
    } else {
      return .stable
    }
  }
}

// MARK: - Trend

/// **Trend direction**
public enum Trend: String, Codable, Sendable {
  case improving
  case stable
  case worsening
}

// MARK: - Resource Correlation

/// **Resource usage correlation analysis**
public struct ResourceCorrelation: Codable, Sendable {
  /// Correlation between memory usage and failures
  public let memoryCorrelation: Double

  /// Correlation between CPU usage and failures
  public let cpuCorrelation: Double

  /// Correlation between system load and failures
  public let loadCorrelation: Double

  public init(executions: [TestExecution]) {
    self.memoryCorrelation = Self.calculateCorrelation(
      executions,
      metric: { $0.memoryUsage },
      failures: { $0.result.isFailure }
    )

    self.cpuCorrelation = Self.calculateCorrelation(
      executions,
      metric: { $0.cpuUsage },
      failures: { $0.result.isFailure }
    )

    self.loadCorrelation = Self.calculateCorrelation(
      executions,
      metric: { $0.environment.loadAverage },
      failures: { $0.result.isFailure }
    )
  }

  // MARK: - Codable Protocol Witness
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.memoryCorrelation = try container.decode(Double.self, forKey: .memoryCorrelation)
    self.cpuCorrelation = try container.decode(Double.self, forKey: .cpuCorrelation)
    self.loadCorrelation = try container.decode(Double.self, forKey: .loadCorrelation)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(memoryCorrelation, forKey: .memoryCorrelation)
    try container.encode(cpuCorrelation, forKey: .cpuCorrelation)
    try container.encode(loadCorrelation, forKey: .loadCorrelation)
  }

  private enum CodingKeys: String, CodingKey {
    case memoryCorrelation, cpuCorrelation, loadCorrelation
  }

  private static func calculateCorrelation<T: Numeric>(
    _ executions: [TestExecution],
    metric: (TestExecution) -> T,
    failures: (TestExecution) -> Bool
  ) -> Double {
    guard executions.count > 5 else { return 0.0 }

    let values = executions.map { Double("\(metric($0))") ?? 0.0 }
    let failureFlags = executions.map { failures($0) ? 1.0 : 0.0 }

    return flakeCorrelation(values, failureFlags)
  }
}

// MARK: - Statistical Utilities (file-private)

private extension Array where Element == Double {
  func average() -> Double {
    guard !isEmpty else { return 0.0 }
    return reduce(0, +) / Double(count)
  }

  func standardDeviation() -> Double {
    let avg = average()
    let squaredDiffs = map { ($0 - avg) * ($0 - avg) }
    return sqrt(squaredDiffs.average())
  }

  func variance() -> Double {
    let avg = average()
    let squaredDiffs = map { ($0 - avg) * ($0 - avg) }
    return squaredDiffs.average()
  }
}

private func flakeCorrelation(_ x: [Double], _ y: [Double]) -> Double {
  guard x.count == y.count && !x.isEmpty else { return 0.0 }

  let xMean = x.average()
  let yMean = y.average()

  let numerator = zip(x, y).map { xi, yi in (xi - xMean) * (yi - yMean) }.reduce(0, +)
  let xVariance = x.map { ($0 - xMean) * ($0 - xMean) }.reduce(0, +)
  let yVariance = y.map { ($0 - yMean) * ($0 - yMean) }.reduce(0, +)

  let denominator = sqrt(xVariance * yVariance)

  return denominator != 0 ? numerator / denominator : 0.0
}
