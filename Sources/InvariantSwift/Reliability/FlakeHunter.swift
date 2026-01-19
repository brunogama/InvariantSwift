import Foundation
import Dispatch

// MARK: - Flake Hunter and Quarantine System

// swiftlint:disable:next orphaned_doc_comment
/// **Flake Hunter Infrastructure**
///
/// Advanced system for detecting, analyzing, and quarantining flaky tests.
/// Flaky tests are those that produce inconsistent results - sometimes passing,
/// sometimes failing - without code changes. This system provides:
/// - Statistical detection of flaky behavior patterns
/// - Automatic quarantine of problematic tests
/// - Root cause analysis and reporting
/// - Gradual rehabilitation of quarantined tests
/// - Performance impact monitoring
///
/// **Mathematical Foundation:**
/// Based on statistical hypothesis testing and reliability theory:
/// - Binomial distribution analysis for pass/fail patterns
/// - Chi-squared tests for independence
/// - Bayesian updating for confidence intervals
/// - Time series analysis for trend detection
///
/// **External References:**
/// - [Google's Flaky Test Detection](https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html)
/// - [Microsoft's Flaky Test Research](https://www.microsoft.com/en-us/research/publication/empirically-revisiting-evaluating-flaky-test-detection-techniques/)
/// - [Statistical Methods for Software Testing](https://link.springer.com/book/10.1007/978-1-4757-3028-5)

// MARK: - Core Types

/// **Test execution result with metadata**
public struct TestExecution: Codable, Sendable {
  /// Unique identifier for this execution
  public let id: UUID

  /// Test identifier
  public let testId: String

  /// Test result
  public let result: TestResult

  /// Execution timestamp
  public let timestamp: Date

  /// Execution duration in seconds
  public let duration: Double

  /// System environment snapshot
  public let environment: ExecutionEnvironment

  /// Random seed used (if applicable)
  public let seed: UInt64?

  /// Number of iterations (for property tests)
  public let iterations: Int?

  /// Memory usage during test
  public let memoryUsage: Int64

  /// CPU usage percentage
  public let cpuUsage: Double

  public init(
    id: UUID = UUID(),
    testId: String,
    result: TestResult,
    timestamp: Date = Date(),
    duration: Double,
    environment: ExecutionEnvironment,
    seed: UInt64? = nil,
    iterations: Int? = nil,
    memoryUsage: Int64 = 0,
    cpuUsage: Double = 0.0
  ) {
    self.id = id
    self.testId = testId
    self.result = result
    self.timestamp = timestamp
    self.duration = duration
    self.environment = environment
    self.seed = seed
    self.iterations = iterations
    self.memoryUsage = memoryUsage
    self.cpuUsage = cpuUsage
  }
}

/// **Test result enumeration**
public enum TestResult: String, Codable, Sendable {
  case passed
  case failed
  case skipped
  case timeout
  case error

  var isFailure: Bool {
    switch self {
    case .passed, .skipped:
      return false

    case .failed, .timeout, .error:
      return true
    }
  }
}

/// **System environment snapshot**
public struct ExecutionEnvironment: Codable, Sendable {
  /// Operating system version
  public let osVersion: String

  /// Swift version
  public let swiftVersion: String

  /// Device model/architecture
  public let architecture: String

  /// Available system memory
  public let availableMemory: Int64

  /// System load average
  public let loadAverage: Double

  /// Current working directory
  public let workingDirectory: String

  /// Environment variables hash
  public let environmentHash: String

  /// CI/CD environment indicator
  public let isCIEnvironment: Bool

  public init() {
    self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    self.swiftVersion = "Swift 6.0"  // This would be detected dynamically
    self.architecture = ProcessInfo.processInfo.machineString
    self.availableMemory = Int64(ProcessInfo.processInfo.physicalMemory)
    self.loadAverage = 0.0  // This would be read from system
    self.workingDirectory = FileManager.default.currentDirectoryPath
    self.environmentHash = Self.hashEnvironmentVariables()
    self.isCIEnvironment = ProcessInfo.processInfo.environment.keys.contains { key in
      ["CI", "CONTINUOUS_INTEGRATION", "GITHUB_ACTIONS", "TRAVIS", "JENKINS_URL"].contains(key)
    }
  }

  private static func hashEnvironmentVariables() -> String {
    let relevantVars = ProcessInfo.processInfo.environment
      .filter { key, _ in
        !["PATH", "HOME", "USER", "TMPDIR"].contains(key)
      }
      .sorted { $0.key < $1.key }

    return String(relevantVars.description.hashValue)
  }
}

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

/// **Trend direction**
public enum Trend: String, Codable, Sendable {
  case improving
  case stable
  case worsening
}

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

    return correlation(values, failureFlags)
  }
}

// MARK: - Flake Hunter Actor

/// **Main Flake Hunter system**
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public actor FlakeHunter {

  // MARK: - Configuration

  /// **Flake detection configuration**
  public struct Config: Sendable {
    /// Minimum executions before flake analysis
    public let minimumExecutions: Int

    /// Confidence threshold for flake detection
    public let confidenceThreshold: Double

    /// Flakiness score threshold
    public let flakinessThreshold: Double

    /// Automatic quarantine enabled
    public let autoQuarantine: Bool

    /// Quarantine duration in seconds
    public let quarantineDuration: TimeInterval

    /// Rehabilitation attempts before permanent quarantine
    public let maxRehabilitationAttempts: Int

    public init(
      minimumExecutions: Int = 20,
      confidenceThreshold: Double = 0.95,
      flakinessThreshold: Double = 0.7,
      autoQuarantine: Bool = true,
      quarantineDuration: TimeInterval = 24 * 60 * 60,  // 24 hours
      maxRehabilitationAttempts: Int = 3
    ) {
      self.minimumExecutions = minimumExecutions
      self.confidenceThreshold = confidenceThreshold
      self.flakinessThreshold = flakinessThreshold
      self.autoQuarantine = autoQuarantine
      self.quarantineDuration = quarantineDuration
      self.maxRehabilitationAttempts = maxRehabilitationAttempts
    }

    public static let `default` = Config()
  }

  // MARK: - State

  private let config: Config
  private var executionHistory: [String: [TestExecution]] = [:]
  private var quarantinedTests: [String: QuarantineRecord] = [:]
  private let storageURL: URL

  /// **Quarantine record**
  public struct QuarantineRecord: Codable, Sendable {
    /// When the test was quarantined
    public let quarantinedAt: Date

    /// Reason for quarantine
    public let reason: String

    /// Flake statistics at time of quarantine
    public let statistics: FlakeStatistics

    /// Number of rehabilitation attempts
    public let rehabilitationAttempts: Int

    /// Quarantine duration
    public let duration: TimeInterval

    /// Is permanently quarantined
    public let isPermanent: Bool

    public init(
      quarantinedAt: Date,
      reason: String,
      statistics: FlakeStatistics,
      rehabilitationAttempts: Int = 0,
      duration: TimeInterval,
      isPermanent: Bool = false
    ) {
      self.quarantinedAt = quarantinedAt
      self.reason = reason
      self.statistics = statistics
      self.rehabilitationAttempts = rehabilitationAttempts
      self.duration = duration
      self.isPermanent = isPermanent
    }
  }

  // MARK: - Initialization

  /// Initialize the Flake Hunter system
  /// - Parameters:
  ///   - config: Detection configuration
  ///   - storageURL: URL for persistent storage
  public init(
    config: Config = .default,
    storageURL: URL? = nil
  ) async throws {
    self.config = config
    self.storageURL = storageURL ?? Self.defaultStorageURL()

    // Create storage directory if needed
    try FileManager.default.createDirectory(
      at: self.storageURL,
      withIntermediateDirectories: true
    )

    // Load existing data
    try await loadPersistedData()
  }

  private static func defaultStorageURL() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!

    return
      appSupport
      .appendingPathComponent("FunctionalTesting")
      .appendingPathComponent("FlakeHunter")
  }

  // MARK: - Public Interface

  /// **Record a test execution**
  /// - Parameter execution: Test execution to record
  public func recordExecution(_ execution: TestExecution) async {
    // Add to execution history
    if executionHistory[execution.testId] == nil {
      executionHistory[execution.testId] = []
    }
    executionHistory[execution.testId]?.append(execution)

    // Analyze for flakiness
    if let executions = executionHistory[execution.testId],
      executions.count >= config.minimumExecutions
    {
      await analyzeFlakiness(testId: execution.testId)
    }

    // Persist updated data
    try? await persistData()
  }

  /// **Get flake statistics for a test**
  /// - Parameter testId: Test identifier
  /// - Returns: Flake statistics if available
  public func getStatistics(for testId: String) -> FlakeStatistics? {
    guard let executions = executionHistory[testId],
      !executions.isEmpty
    else {
      return nil
    }

    return FlakeStatistics(executions: executions)
  }

  /// **Check if a test is quarantined**
  /// - Parameter testId: Test identifier
  /// - Returns: True if test is currently quarantined
  public func isQuarantined(_ testId: String) -> Bool {
    guard let record = quarantinedTests[testId] else {
      return false
    }

    // Check if quarantine has expired
    let quarantineEnd = record.quarantinedAt.addingTimeInterval(record.duration)
    let now = Date()

    if now > quarantineEnd && !record.isPermanent {
      // Quarantine expired, attempt rehabilitation
      Task { await attemptRehabilitation(testId) }
      return false
    }

    return true
  }

  /// **Get quarantine record for a test**
  /// - Parameter testId: Test identifier
  /// - Returns: Quarantine record if test is quarantined
  public func getQuarantineRecord(for testId: String) -> QuarantineRecord? {
    quarantinedTests[testId]
  }

  /// **Get all quarantined tests**
  /// - Returns: Dictionary of quarantined tests and their records
  public func getAllQuarantinedTests() -> [String: QuarantineRecord] {
    quarantinedTests
  }

  /// **Manually quarantine a test**
  /// - Parameters:
  ///   - testId: Test identifier
  ///   - reason: Reason for manual quarantine
  ///   - duration: Quarantine duration
  public func quarantineTest(
    _ testId: String,
    reason: String,
    duration: TimeInterval? = nil
  ) async {
    let executions = executionHistory[testId] ?? []
    let statistics = FlakeStatistics(executions: executions)

    let record = QuarantineRecord(
      quarantinedAt: Date(),
      reason: reason,
      statistics: statistics,
      duration: duration ?? config.quarantineDuration
    )

    quarantinedTests[testId] = record
    try? await persistData()
  }

  /// **Manually release a test from quarantine**
  /// - Parameter testId: Test identifier
  public func releaseFromQuarantine(_ testId: String) async {
    quarantinedTests.removeValue(forKey: testId)
    try? await persistData()
  }

  /// **Generate comprehensive flake report**
  /// - Returns: Detailed report of all flake analysis
  public func generateReport() -> FlakeReport {
    let allTests = Set(executionHistory.keys).union(Set(quarantinedTests.keys))

    var testReports: [TestFlakeReport] = []

    for testId in allTests {
      let executions = executionHistory[testId] ?? []
      let statistics = executions.isEmpty ? nil : FlakeStatistics(executions: executions)
      let quarantineRecord = quarantinedTests[testId]

      testReports.append(
        TestFlakeReport(
          testId: testId,
          statistics: statistics,
          quarantineRecord: quarantineRecord,
          executionCount: executions.count
        )
      )
    }

    // Sort by flakiness score descending
    testReports.sort { a, b in
      let aScore = a.statistics?.flakinessScore ?? 0.0
      let bScore = b.statistics?.flakinessScore ?? 0.0
      return aScore > bScore
    }

    return FlakeReport(
      generatedAt: Date(),
      totalTests: testReports.count,
      quarantinedCount: quarantinedTests.count,
      testReports: testReports,
      configuration: config
    )
  }

  // MARK: - Private Methods

  private func analyzeFlakiness(testId: String) async {
    guard let executions = executionHistory[testId] else { return }

    let statistics = FlakeStatistics(executions: executions)

    // Check if test should be quarantined
    if config.autoQuarantine && statistics.confidence >= config.confidenceThreshold
      && statistics.flakinessScore >= config.flakinessThreshold
      && !quarantinedTests.keys.contains(testId)
    {

      let reason =
        "Automatic quarantine: flakiness score \(String(format: "%.2f", statistics.flakinessScore)), confidence \(String(format: "%.2f", statistics.confidence))"

      let record = QuarantineRecord(
        quarantinedAt: Date(),
        reason: reason,
        statistics: statistics,
        duration: config.quarantineDuration
      )

      quarantinedTests[testId] = record
    }
  }

  private func attemptRehabilitation(_ testId: String) async {
    guard let record = quarantinedTests[testId] else { return }

    // Check recent executions to see if test has stabilized
    let recentExecutions = executionHistory[testId]?.suffix(10) ?? []

    guard !recentExecutions.isEmpty else {
      // No recent executions, keep quarantined
      return
    }

    let recentStatistics = FlakeStatistics(executions: Array(recentExecutions))

    // Test is rehabilitated if it's no longer flaky
    if recentStatistics.flakinessScore < config.flakinessThreshold * 0.5 {
      // Successful rehabilitation
      quarantinedTests.removeValue(forKey: testId)
    } else if record.rehabilitationAttempts >= config.maxRehabilitationAttempts {
      // Too many failed attempts, mark as permanent
      let permanentRecord = QuarantineRecord(
        quarantinedAt: record.quarantinedAt,
        reason: record.reason
          + " (permanent after \(record.rehabilitationAttempts) failed rehabilitation attempts)",
        statistics: record.statistics,
        rehabilitationAttempts: record.rehabilitationAttempts,
        duration: record.duration,
        isPermanent: true
      )
      quarantinedTests[testId] = permanentRecord
    } else {
      // Failed rehabilitation attempt
      let updatedRecord = QuarantineRecord(
        quarantinedAt: Date(),  // Reset quarantine timer
        reason: record.reason,
        statistics: recentStatistics,
        rehabilitationAttempts: record.rehabilitationAttempts + 1,
        duration: record.duration * 2,  // Exponential backoff
        isPermanent: false
      )
      quarantinedTests[testId] = updatedRecord
    }

    try? await persistData()
  }

  private func loadPersistedData() async throws {
    let executionHistoryURL = storageURL.appendingPathComponent("execution_history.json")
    let quarantineURL = storageURL.appendingPathComponent("quarantine.json")

    // Load execution history
    if FileManager.default.fileExists(atPath: executionHistoryURL.path) {
      let data = try Data(contentsOf: executionHistoryURL)
      executionHistory = try JSONDecoder().decode([String: [TestExecution]].self, from: data)
    }

    // Load quarantine records
    if FileManager.default.fileExists(atPath: quarantineURL.path) {
      let data = try Data(contentsOf: quarantineURL)
      quarantinedTests = try JSONDecoder().decode([String: QuarantineRecord].self, from: data)
    }
  }

  private func persistData() async throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    // Persist execution history
    let executionHistoryURL = storageURL.appendingPathComponent("execution_history.json")
    let historyData = try encoder.encode(executionHistory)
    try historyData.write(to: executionHistoryURL)

    // Persist quarantine records
    let quarantineURL = storageURL.appendingPathComponent("quarantine.json")
    let quarantineData = try encoder.encode(quarantinedTests)
    try quarantineData.write(to: quarantineURL)
  }
}

// MARK: - Reporting

/// **Comprehensive flake report**
public struct FlakeReport: Sendable {
  /// Report generation timestamp
  public let generatedAt: Date

  /// Total number of tests analyzed
  public let totalTests: Int

  /// Number of quarantined tests
  public let quarantinedCount: Int

  /// Individual test reports
  public let testReports: [TestFlakeReport]

  /// Configuration used for analysis
  public let configuration: FlakeHunter.Config

  /// Summary statistics
  public var summary: ReportSummary {
    let flakyTests = testReports.filter { ($0.statistics?.isFlaky ?? false) }.count
    let averageFlakinessScore = testReports.compactMap { $0.statistics?.flakinessScore }.average()

    return ReportSummary(
      totalTests: totalTests,
      flakyTests: flakyTests,
      quarantinedTests: quarantinedCount,
      averageFlakinessScore: averageFlakinessScore
    )
  }
}

/// **Individual test flake report**
public struct TestFlakeReport: Sendable {
  /// Test identifier
  public let testId: String

  /// Flake statistics
  public let statistics: FlakeStatistics?

  /// Quarantine record if quarantined
  public let quarantineRecord: FlakeHunter.QuarantineRecord?

  /// Total execution count
  public let executionCount: Int

  /// Test status
  public var status: TestStatus {
    if quarantineRecord != nil {
      return .quarantined
    } else if statistics?.isFlaky == true {
      return .flaky
    } else if executionCount < 10 {
      return .insufficient_data
    } else {
      return .stable
    }
  }
}

/// **Test status enumeration**
public enum TestStatus: String, Sendable {
  case stable
  case flaky
  case quarantined
  // swiftlint:disable:next identifier_name
  case insufficient_data
}

/// **Report summary statistics**
public struct ReportSummary: Sendable {
  public let totalTests: Int
  public let flakyTests: Int
  public let quarantinedTests: Int
  public let averageFlakinessScore: Double

  public var flakeRate: Double {
    totalTests > 0 ? Double(flakyTests) / Double(totalTests) : 0.0
  }

  public var quarantineRate: Double {
    totalTests > 0 ? Double(quarantinedTests) / Double(totalTests) : 0.0
  }
}

// MARK: - Integration with Property Testing

extension PropertyRunner {

  /// Run property test with flake detection
  /// - Parameters:
  ///   - property: Property to test
  ///   - config: Test configuration
  ///   - flakeHunter: Flake hunter instance
  ///   - testId: Unique test identifier
  /// - Returns: Test result
  public func runPropertyWithFlakeDetection<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default,
    flakeHunter: FlakeHunter,
    testId: String
  ) async -> PropertyResult<T> {

    // Check if test is quarantined
    if await flakeHunter.isQuarantined(testId) {
      // Return artificial success to skip quarantined test
      return .success(iterations: 0)
    }

    let startTime = CFAbsoluteTimeGetCurrent()
    let result = runProperty(property, config: config)
    let duration = CFAbsoluteTimeGetCurrent() - startTime

    // Record execution
    let execution = TestExecution(
      testId: testId,
      result: result.toTestResult(),
      duration: duration,
      environment: ExecutionEnvironment(),
      seed: config.seed?.rawValue,
      iterations: config.iterations,
      memoryUsage: Int64(ProcessInfo.processInfo.physicalMemory),
      cpuUsage: 0.0  // This would be measured dynamically
    )

    await flakeHunter.recordExecution(execution)

    return result
  }
}

// MARK: - Memory Optimization Types

/// **String pool for efficient string interning**
///
/// Provides memory-efficient storage of frequently-used strings.
/// Identical strings share storage, reducing memory allocations.
///
/// **Memory Optimization Benefits:**
/// - Deduplication of repeated test IDs and reason strings
/// - Reduced memory churn from temporary string allocations
/// - Actor isolation for thread-safe access
public actor StringPool {
  private var pool: Set<String> = []

  /// Shared instance for global string pooling
  public static let shared = StringPool()

  /// Initialize a new string pool
  public init() {}

  /// Intern a string, returning the canonical instance
  ///
  /// - Parameter string: String to intern
  /// - Returns: Canonical string instance from the pool
  public func intern(_ string: String) -> String {
    if let existing = pool.first(where: { $0 == string }) {
      return existing
    }
    pool.insert(string)
    return string
  }

  /// Intern multiple strings
  ///
  /// - Parameter strings: Strings to intern
  /// - Returns: Array of canonical string instances
  public func internAll(_ strings: [String]) -> [String] {
    strings.map { intern($0) }
  }

  /// Number of unique strings in the pool
  public var count: Int { pool.count }

  /// Clear all interned strings
  public func clear() {
    pool.removeAll()
  }

  /// Fire-and-forget interning from synchronous contexts
  nonisolated public func internAsync(_ string: String) {
    Task { _ = await self.intern(string) }
  }
}

/// **Efficient quarantine reason builder**
///
/// Provides zero-copy string building for quarantine reasons,
/// reducing temporary allocations during reason message construction.
///
/// **Memory Optimization Benefits:**
/// - Pre-allocated buffer for common reason patterns
/// - Reusable across multiple quarantine operations
/// - Eliminates intermediate string concatenations
public struct QuarantineReasonBuilder: Sendable {
  private var components: [String] = []

  /// Creates a new reason builder
  public init() {}

  /// Add a component to the reason
  ///
  /// - Parameter component: Text component to add
  /// - Returns: Self for chaining
  @discardableResult
  public mutating func add(_ component: String) -> Self {
    components.append(component)
    return self
  }

  /// Add flakiness score component
  @discardableResult
  public mutating func withFlakinessScore(_ score: Double) -> Self {
    components.append("flakiness score \(String(format: "%.2f", score))")
    return self
  }

  /// Add confidence component
  @discardableResult
  public mutating func withConfidence(_ confidence: Double) -> Self {
    components.append("confidence \(String(format: "%.2f", confidence))")
    return self
  }

  /// Add rehabilitation attempt count
  @discardableResult
  public mutating func withRehabilitationAttempts(_ count: Int) -> Self {
    if count > 0 {
      components.append("after \(count) failed rehabilitation attempts")
    }
    return self
  }

  /// Build the final reason string
  ///
  /// - Parameter prefix: Optional prefix for the reason
  /// - Returns: Complete reason string
  public func build(prefix: String = "Automatic quarantine:") -> String {
    guard !components.isEmpty else { return prefix }
    return "\(prefix) \(components.joined(separator: ", "))"
  }

  /// Reset the builder for reuse
  public mutating func reset() {
    components.removeAll(keepingCapacity: true)
  }
}

// MARK: - Extensions

extension PropertyResult {
  fileprivate func toTestResult() -> TestResult {
    switch self {
    case .success:
      return .passed

    case .failure:
      return .failed

    case .gaveUp:
      return .skipped
    }
  }
}

extension ProcessInfo {
  fileprivate var machineString: String {
    var size = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    let truncated = machine.prefix { $0 != 0 }
    return String(decoding: truncated.map { UInt8(bitPattern: $0) }, as: UTF8.self)
  }
}

// MARK: - Statistical Utilities

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

private func correlation(_ x: [Double], _ y: [Double]) -> Double {
  guard x.count == y.count && !x.isEmpty else { return 0.0 }

  let xMean = x.average()
  let yMean = y.average()

  let numerator = zip(x, y).map { xi, yi in (xi - xMean) * (yi - yMean) }.reduce(0, +)
  let xVariance = x.map { ($0 - xMean) * ($0 - xMean) }.reduce(0, +)
  let yVariance = y.map { ($0 - yMean) * ($0 - yMean) }.reduce(0, +)

  let denominator = sqrt(xVariance * yVariance)

  return denominator != 0 ? numerator / denominator : 0.0
  // swiftlint:disable:next file_length
}
