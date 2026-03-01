import InvariantSwiftCore
import Foundation

// MARK: - Flake Hunter Actor

/// **Main Flake Hunter system**
///
/// Advanced system for detecting, analyzing, and quarantining flaky tests.
/// Flaky tests are those that produce inconsistent results - sometimes passing,
/// sometimes failing - without code changes.
///
/// **See also:**
/// - `TestExecution.swift` - Core types (TestExecution, TestResult, ExecutionEnvironment)
/// - `FlakeHunterStatistics.swift` - Statistical analysis (FlakeStatistics, FlakePatterns)
/// - `FlakeHunterReport.swift` - Reporting (FlakeReport, TestFlakeReport, ReportSummary)
/// - `FlakeHunter+PropertyTest.swift` - PropertyRunner integration
/// - `QuarantineSystem.swift` - StringPool, QuarantineReasonBuilder
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
      quarantineDuration: TimeInterval = 24 * 60 * 60,
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
  public init(
    config: Config = .default,
    storageURL: URL? = nil
  ) async throws {
    self.config = config
    self.storageURL = storageURL ?? Self.defaultStorageURL()

    try FileManager.default.createDirectory(
      at: self.storageURL,
      withIntermediateDirectories: true
    )

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
  public func recordExecution(_ execution: TestExecution) async {
    if executionHistory[execution.testId] == nil {
      executionHistory[execution.testId] = []
    }
    executionHistory[execution.testId]?.append(execution)

    if let executions = executionHistory[execution.testId],
      executions.count >= config.minimumExecutions
    {
      await analyzeFlakiness(testId: execution.testId)
    }

    try? await persistData()
  }

  /// **Get flake statistics for a test**
  public func getStatistics(for testId: String) -> FlakeStatistics? {
    guard let executions = executionHistory[testId],
      !executions.isEmpty
    else {
      return nil
    }

    return FlakeStatistics(executions: executions)
  }

  /// **Check if a test is quarantined**
  public func isQuarantined(_ testId: String) -> Bool {
    guard let record = quarantinedTests[testId] else {
      return false
    }

    let quarantineEnd = record.quarantinedAt.addingTimeInterval(record.duration)
    let now = Date()

    if now > quarantineEnd && !record.isPermanent {
      Task { await attemptRehabilitation(testId) }
      return false
    }

    return true
  }

  /// **Get quarantine record for a test**
  public func getQuarantineRecord(for testId: String) -> QuarantineRecord? {
    quarantinedTests[testId]
  }

  /// **Get all quarantined tests**
  public func getAllQuarantinedTests() -> [String: QuarantineRecord] {
    quarantinedTests
  }

  /// **Manually quarantine a test**
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
  public func releaseFromQuarantine(_ testId: String) async {
    quarantinedTests.removeValue(forKey: testId)
    try? await persistData()
  }

  /// **Generate comprehensive flake report**
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

    let recentExecutions = executionHistory[testId]?.suffix(10) ?? []

    guard !recentExecutions.isEmpty else { return }

    let recentStatistics = FlakeStatistics(executions: Array(recentExecutions))

    if recentStatistics.flakinessScore < config.flakinessThreshold * 0.5 {
      quarantinedTests.removeValue(forKey: testId)
    } else if record.rehabilitationAttempts >= config.maxRehabilitationAttempts {
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
      let updatedRecord = QuarantineRecord(
        quarantinedAt: Date(),
        reason: record.reason,
        statistics: recentStatistics,
        rehabilitationAttempts: record.rehabilitationAttempts + 1,
        duration: record.duration * 2,
        isPermanent: false
      )
      quarantinedTests[testId] = updatedRecord
    }

    try? await persistData()
  }

  private func loadPersistedData() async throws {
    let executionHistoryURL = storageURL.appendingPathComponent("execution_history.json")
    let quarantineURL = storageURL.appendingPathComponent("quarantine.json")

    if FileManager.default.fileExists(atPath: executionHistoryURL.path) {
      let data = try Data(contentsOf: executionHistoryURL)
      executionHistory = try JSONDecoder().decode([String: [TestExecution]].self, from: data)
    }

    if FileManager.default.fileExists(atPath: quarantineURL.path) {
      let data = try Data(contentsOf: quarantineURL)
      quarantinedTests = try JSONDecoder().decode([String: QuarantineRecord].self, from: data)
    }
  }

  private func persistData() async throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let executionHistoryURL = storageURL.appendingPathComponent("execution_history.json")
    let historyData = try encoder.encode(executionHistory)
    try historyData.write(to: executionHistoryURL)

    let quarantineURL = storageURL.appendingPathComponent("quarantine.json")
    let quarantineData = try encoder.encode(quarantinedTests)
    try quarantineData.write(to: quarantineURL)
  }
}

// MARK: - PropertyResult Extension

extension PropertyResult {
  func toTestResult() -> TestResult {
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
