import InvariantSwiftCore
import Foundation

// MARK: - FlakeHunter Reporting Types
//
// Comprehensive report types, per-test reports, and statistical utilities for FlakeHunter.
// Extracted from FlakeHunter.swift to keep the actor file under budget.

// MARK: - Report Types

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

// MARK: - Statistical Utilities (file-private for FlakeHunterReport)

private extension Array where Element == Double {
  func average() -> Double {
    guard !isEmpty else { return 0.0 }
    return reduce(0, +) / Double(count)
  }
}
