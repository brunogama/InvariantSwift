import Testing
import Foundation
@testable import InvariantSwiftCore
@testable import InvariantSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@Test("RegressionBank integration with PropertyRunner")
func testRegressionBankIntegration() async throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("regression-bank-test-\(UUID().uuidString)")
  let bank = RegressionBank(directory: tempDir)

  defer {
    try? FileManager.default.removeItem(at: tempDir)
  }

  let config = PropertyConfig(
    iterations: 100,
    regressionBank: bank,
    propertyId: "testFailingProperty"
  )

  let failingProperty = Property(generator: Gen<Int>.int) { n in
    n != 42
  }

  let runner = PropertyRunner(seed: Seed(value: 42))
  let result = await runner.runProperty(failingProperty, config: config)

  switch result {
  case .failure:
    let failures = await bank.failuresForProperty("testFailingProperty")
    #expect(failures.count == 1)
    #expect(failures.first?.seedValue == 42)

  case .success, .gaveUp:
    Issue.record("Expected failure but got \(result)")
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@Test("Regression replay executes stored failures first")
func testRegressionReplay() async throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("regression-replay-test-\(UUID().uuidString)")
  let bank = RegressionBank(directory: tempDir)

  defer {
    try? FileManager.default.removeItem(at: tempDir)
  }

  let failingEntry = FailureEntry(
    propertyLabel: "testReplayProperty",
    seedValue: 999,
    counterexampleDescription: "42",
    failureReason: "predicate returned false",
    failedAtIteration: 1
  )
  try await bank.recordFailureEntry(failingEntry)

  let config = PropertyConfig(
    iterations: 10,
    regressionBank: bank,
    propertyId: "testReplayProperty"
  )

  let property = Property(generator: Gen<Int>.int) { n in
    n != 42
  }

  let runner = PropertyRunner()
  let result = await runner.runProperty(property, config: config)

  switch result {
  case .failure(_, _, let shrunk, _, let seed):
    #expect(seed.rawValue == 999)

  case .success, .gaveUp:
    Issue.record("Expected regression to be replayed and fail")
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@Test("Regressions execute oldest-first")
func testRegressionExecutionOrder() async throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("regression-order-test-\(UUID().uuidString)")
  let bank = RegressionBank(directory: tempDir)

  defer {
    try? FileManager.default.removeItem(at: tempDir)
  }

  let oldFailure = FailureEntry(
    propertyLabel: "testOrderProperty",
    seedValue: 100,
    counterexampleDescription: "10",
    failureReason: "predicate returned false",
    timestamp: Date().addingTimeInterval(-3600),
    failedAtIteration: 1
  )
  let newFailure = FailureEntry(
    propertyLabel: "testOrderProperty",
    seedValue: 200,
    counterexampleDescription: "20",
    failureReason: "predicate returned false",
    timestamp: Date(),
    failedAtIteration: 1
  )

  try await bank.recordFailureEntry(newFailure)
  try await bank.recordFailureEntry(oldFailure)

  let seeds = await bank.seedsForProperty("testOrderProperty")
  #expect(seeds.count == 2)
  #expect(seeds[0].rawValue == 100)
  #expect(seeds[1].rawValue == 200)
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@Test("RegressionBank deduplicates by property + seed")
func testRegressionDeduplication() async throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("regression-dedup-test-\(UUID().uuidString)")
  let bank = RegressionBank(directory: tempDir)

  defer {
    try? FileManager.default.removeItem(at: tempDir)
  }

  let entry1 = FailureEntry(
    propertyLabel: "testDedupProperty",
    seedValue: 42,
    counterexampleDescription: "first",
    failureReason: "predicate returned false",
    failedAtIteration: 1
  )
  let entry2 = FailureEntry(
    propertyLabel: "testDedupProperty",
    seedValue: 42,
    counterexampleDescription: "second",
    failureReason: "predicate returned false",
    failedAtIteration: 2
  )

  try await bank.recordFailureEntry(entry1)
  try await bank.recordFailureEntry(entry2)

  let failures = await bank.failuresForProperty("testDedupProperty")
  #expect(failures.count == 1)
  #expect(failures.first?.counterexampleDescription == "first")
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@Test("Regression bank is opt-in via PropertyConfig")
func testRegressionBankOptIn() async throws {
  let configWithoutBank = PropertyConfig(iterations: 10)
  #expect(configWithoutBank.regressionBank == nil)
  #expect(configWithoutBank.propertyId == nil)

  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("regression-optin-test-\(UUID().uuidString)")
  defer {
    try? FileManager.default.removeItem(at: tempDir)
  }

  let bank = RegressionBank(directory: tempDir)
  let configWithBank = PropertyConfig(
    iterations: 10,
    regressionBank: bank,
    propertyId: "testProperty"
  )
  #expect(configWithBank.regressionBank != nil)
  #expect(configWithBank.propertyId == "testProperty")
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@Test("Regression bank persistence round-trip")
func testPersistenceRoundTrip() async throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("regression-persistence-test-\(UUID().uuidString)")

  defer {
    try? FileManager.default.removeItem(at: tempDir)
  }

  do {
    let bank1 = RegressionBank(directory: tempDir)
    let entry = FailureEntry(
      propertyLabel: "testPersistenceProperty",
      seedValue: 123,
      counterexampleDescription: "test value",
      failureReason: "predicate returned false",
      failedAtIteration: 5
    )
    try await bank1.recordFailureEntry(entry)
  }

  let bank2 = RegressionBank(directory: tempDir)
  let failures = await bank2.failuresForProperty("testPersistenceProperty")
  #expect(failures.count == 1)
  #expect(failures.first?.seedValue == 123)
  #expect(failures.first?.counterexampleDescription == "test value")
}
