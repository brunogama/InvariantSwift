import Foundation
import InvariantSwiftTesting
import Testing

@Suite("Failure Persistence Manager Tests")
struct FailurePersistenceManagerTests {
  @Test("loadReplayFailures filters by test and returns most recent failures first")
  func loadReplayFailuresFiltersAndLimitsResults() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("invariantswift-failures-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }

    let manager = FailurePersistenceManager(storageDirectory: directory)
    let older = PersistedFailure(
      id: UUID(),
      testName: "target",
      seed: 1,
      originalValue: "older",
      shrunkValue: "older",
      timestamp: Date(timeIntervalSince1970: 10),
      iterationsBeforeFailure: 1,
      shrinkAttempts: 0
    )
    let newer = PersistedFailure(
      id: UUID(),
      testName: "target",
      seed: 2,
      originalValue: "newer",
      shrunkValue: "newer",
      timestamp: Date(timeIntervalSince1970: 20),
      iterationsBeforeFailure: 2,
      shrinkAttempts: 1
    )
    let other = PersistedFailure(
      id: UUID(),
      testName: "other",
      seed: 3,
      originalValue: "other",
      shrunkValue: "other",
      timestamp: Date(timeIntervalSince1970: 30),
      iterationsBeforeFailure: 3,
      shrinkAttempts: 2
    )

    try manager.save(older)
    try manager.save(newer)
    try manager.save(other)

    let failures = try await manager.loadReplayFailures(forTest: "target", maxExamples: 1)
    #expect(failures.count == 1)
    #expect(failures.first?.id == newer.id)
  }

  @Test("PersistedFailure encodes only its id as a test argument")
  func persistedFailureCustomArgumentEncodingUsesStableID() throws {
    let failure = PersistedFailure(
      id: UUID(),
      testName: "encoding",
      seed: 42,
      originalValue: "original",
      shrunkValue: "shrunk",
      iterationsBeforeFailure: 7,
      shrinkAttempts: 2
    )

    let data = try JSONEncoder().encode(TestArgumentEnvelope(failure: failure))
    guard let json = String(bytes: data, encoding: .utf8) else {
      Issue.record("Failed to decode test argument payload as UTF-8")
      return
    }

    #expect(json.contains(failure.id.uuidString))
    #expect(json.contains(failure.testName) == false)
    #expect(json.contains(failure.originalValue) == false)
  }
}

private struct TestArgumentEnvelope: Encodable {
  let failure: PersistedFailure

  func encode(to encoder: Encoder) throws {
    try failure.encodeTestArgument(to: encoder)
  }
}
