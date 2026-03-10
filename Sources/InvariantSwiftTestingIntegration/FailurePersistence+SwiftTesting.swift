import Foundation
import Testing

extension PersistedFailure {
  init(report: FailureReport) {
    self.init(
      testName: report.testName,
      seed: report.seed.rawValue,
      originalValue: report.originalValue,
      shrunkValue: report.shrunkValue,
      iterationsBeforeFailure: report.iterationsBeforeFailure,
      shrinkAttempts: report.shrinkAttempts,
      failureReason: report.failureReason.description
    )
  }
}

extension PersistedFailure: CustomTestArgumentEncodable {
  public func encodeTestArgument(to encoder: some Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(id)
  }
}

extension FailurePersistenceManager {
  public func loadReplayFailures(
    forTest testName: String,
    maxExamples: Int? = nil
  ) async throws -> [PersistedFailure] {
    let failures = try failures(forTest: testName).sorted { $0.timestamp > $1.timestamp }

    if let maxExamples {
      return Array(failures.prefix(maxExamples))
    }

    return failures
  }
}
