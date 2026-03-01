import Foundation

// MARK: - Test Execution Core Types
//
// Core types for recording test execution results and environment snapshots.
// Used by FlakeHunter for flakiness analysis and pattern detection.

// MARK: - Test Execution

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

// MARK: - Test Result

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

// MARK: - Execution Environment

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

// MARK: - ProcessInfo Extension

extension ProcessInfo {
  var machineString: String {
    var size = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    let truncated = machine.prefix { $0 != 0 }
    // swiftlint:disable:next optional_data_string_conversion
    return String(decoding: truncated.map { UInt8(bitPattern: $0) }, as: UTF8.self)
  }
}
