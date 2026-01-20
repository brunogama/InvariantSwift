import Testing
import Foundation
@testable import InvariantSwift

/// Tests for `RegressionBank` - the failure persistence and replay system.
@Suite("Regression Bank Tests")
struct RegressionBankTests {

  // MARK: - Setup

  /// Create a temporary directory for isolated testing
  private func makeTempBank() -> RegressionBank {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("invariant_test_\(UUID().uuidString)")
    return RegressionBank(directory: tempDir)
  }

  // MARK: - Basic Storage Tests

  @Test("Recording a failure stores it persistently")
  func testRecordFailure() async throws {
    let bank = makeTempBank()

    try await bank.recordFailure(
      propertyLabel: "testProperty",
      seed: Seed(value: 12345),
      counterexample: "failing input",
      reason: .predicateFailed,
      iteration: 42
    )

    let failures = await bank.allFailures()
    #expect(failures.count == 1)
    #expect(failures.first?.propertyLabel == "testProperty")
    #expect(failures.first?.seedValue == 12345)
    #expect(failures.first?.failedAtIteration == 42)
  }

  @Test("Seeds for property returns correct seeds")
  func testSeedsForProperty() async throws {
    let bank = makeTempBank()

    try await bank.recordFailure(
      propertyLabel: "propA",
      seed: Seed(value: 100),
      counterexample: "a",
      reason: .predicateFailed,
      iteration: 1
    )

    try await bank.recordFailure(
      propertyLabel: "propB",
      seed: Seed(value: 200),
      counterexample: "b",
      reason: .predicateFailed,
      iteration: 2
    )

    try await bank.recordFailure(
      propertyLabel: "propA",
      seed: Seed(value: 300),
      counterexample: "c",
      reason: .predicateFailed,
      iteration: 3
    )

    let seedsA = await bank.seedsForProperty("propA")
    let seedsB = await bank.seedsForProperty("propB")

    #expect(seedsA.count == 2)
    #expect(seedsA.map(\.rawValue).contains(100))
    #expect(seedsA.map(\.rawValue).contains(300))
    #expect(seedsB.count == 1)
    #expect(seedsB.first?.rawValue == 200)
  }

  @Test("Duplicate failures are deduplicated")
  func testDeduplication() async throws {
    let bank = makeTempBank()

    try await bank.recordFailure(
      propertyLabel: "testProp",
      seed: Seed(value: 999),
      counterexample: "x",
      reason: .predicateFailed,
      iteration: 1
    )

    // Record same property + seed again
    try await bank.recordFailure(
      propertyLabel: "testProp",
      seed: Seed(value: 999),
      counterexample: "differentValue",
      reason: .predicateFailed,
      iteration: 2
    )

    let failures = await bank.allFailures()
    #expect(failures.count == 1)  // Still only 1
  }

  // MARK: - Removal Tests

  @Test("Remove specific failure")
  func testRemoveFailure() async throws {
    let bank = makeTempBank()

    try await bank.recordFailure(
      propertyLabel: "prop",
      seed: Seed(value: 111),
      counterexample: "a",
      reason: .predicateFailed,
      iteration: 1
    )

    try await bank.recordFailure(
      propertyLabel: "prop",
      seed: Seed(value: 222),
      counterexample: "b",
      reason: .predicateFailed,
      iteration: 2
    )

    try await bank.removeFailure(propertyLabel: "prop", seed: Seed(value: 111))

    let failures = await bank.allFailures()
    #expect(failures.count == 1)
    #expect(failures.first?.seedValue == 222)
  }

  @Test("Clear all failures for property")
  func testClearForProperty() async throws {
    let bank = makeTempBank()

    try await bank.recordFailure(
      propertyLabel: "propA",
      seed: Seed(value: 1),
      counterexample: "a",
      reason: .predicateFailed,
      iteration: 1
    )

    try await bank.recordFailure(
      propertyLabel: "propB",
      seed: Seed(value: 2),
      counterexample: "b",
      reason: .predicateFailed,
      iteration: 2
    )

    try await bank.clearFailuresForProperty("propA")

    let failures = await bank.allFailures()
    #expect(failures.count == 1)
    #expect(failures.first?.propertyLabel == "propB")
  }

  @Test("Clear all failures")
  func testClearAll() async throws {
    let bank = makeTempBank()

    try await bank.recordFailure(
      propertyLabel: "propA",
      seed: Seed(value: 1),
      counterexample: "a",
      reason: .predicateFailed,
      iteration: 1
    )

    try await bank.recordFailure(
      propertyLabel: "propB",
      seed: Seed(value: 2),
      counterexample: "b",
      reason: .predicateFailed,
      iteration: 2
    )

    try await bank.clearAll()

    let failures = await bank.allFailures()
    #expect(failures.isEmpty)
  }

  // MARK: - Statistics Tests

  @Test("Statistics are computed correctly")
  func testStatistics() async throws {
    let bank = makeTempBank()

    try await bank.recordFailure(
      propertyLabel: "propA",
      seed: Seed(value: 1),
      counterexample: "a",
      reason: .predicateFailed,
      iteration: 1
    )

    try await bank.recordFailure(
      propertyLabel: "propA",
      seed: Seed(value: 2),
      counterexample: "b",
      reason: .predicateFailed,
      iteration: 2
    )

    try await bank.recordFailure(
      propertyLabel: "propB",
      seed: Seed(value: 3),
      counterexample: "c",
      reason: .predicateFailed,
      iteration: 3
    )

    let stats = await bank.statistics()
    #expect(stats.totalFailures == 3)
    #expect(stats.uniqueProperties == 2)
    #expect(stats.failuresPerProperty["propA"] == 2)
    #expect(stats.failuresPerProperty["propB"] == 1)
  }

  // MARK: - Integration Tests

  @Test("recordFromResult captures failure data")
  func testRecordFromResult() async throws {
    let bank = makeTempBank()

    let result: PropertyResult<String> = .failure(
      counterexample: "original",
      iterations: 50,
      shrunk: "shrunk",
      reason: .predicateFailed,
      seed: Seed(value: 7777)
    )

    try await bank.recordFromResult(result, propertyLabel: "integratedProp")

    let failures = await bank.allFailures()
    #expect(failures.count == 1)
    #expect(failures.first?.seedValue == 7777)
    #expect(failures.first?.counterexampleDescription == "shrunk")
  }

  @Test("Success results are not recorded")
  func testSuccessNotRecorded() async throws {
    let bank = makeTempBank()

    let result: PropertyResult<Int> = .success(iterations: 100)
    try await bank.recordFromResult(result, propertyLabel: "successProp")

    let failures = await bank.allFailures()
    #expect(failures.isEmpty)
  }
}
