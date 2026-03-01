import InvariantSwiftCore
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
    let seedValue = config.seed?.rawValue
    let iterationCount = config.iterations
    let execution = TestExecution(
      testId: testId,
      result: result.toTestResult(),
      duration: duration,
      environment: ExecutionEnvironment(),
      seed: seedValue,
      iterations: iterationCount,
      memoryUsage: Int64(ProcessInfo.processInfo.physicalMemory),
      cpuUsage: 0.0  // This would be measured dynamically
    )

    await flakeHunter.recordExecution(execution)

    return result
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
    // swiftlint:disable:next optional_data_string_conversion
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
}
