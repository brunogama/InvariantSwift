// FailurePersistenceTests.swift
// InvariantSwift Tests
//
// Tests for the FailurePersistence system.

import Testing
import Foundation
@testable import InvariantSwift

@Suite("FailurePersistence Tests")
struct FailurePersistenceTests {

  // Create a temporary directory for tests
  private func tempDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("InvariantSwiftTests")
      .appendingPathComponent(UUID().uuidString)
  }

  // MARK: - PersistedFailure Tests

  @Test("PersistedFailure creates with defaults")
  func testPersistedFailureDefaults() {
    let failure = PersistedFailure(
      testName: "testExample",
      seed: 12345,
      originalValue: "[1, 2, 3]",
      shrunkValue: "[1]",
      iterationsBeforeFailure: 42,
      shrinkAttempts: 10
    )

    #expect(failure.testName == "testExample")
    #expect(failure.seed == 12345)
    #expect(failure.originalValue == "[1, 2, 3]")
    #expect(failure.shrunkValue == "[1]")
    #expect(failure.iterationsBeforeFailure == 42)
    #expect(failure.shrinkAttempts == 10)
    #expect(failure.failureReason == nil)
    #expect(failure.gitCommit == nil)
  }

  @Test("PersistedFailure reproduction command")
  func testReproductionCommand() {
    let failure = PersistedFailure(
      testName: "testSorting",
      seed: 99999,
      originalValue: "[]",
      shrunkValue: "[]",
      iterationsBeforeFailure: 1,
      shrinkAttempts: 0
    )

    #expect(failure.reproductionCommand == "swift test --filter testSorting --seed 99999")
  }

  // MARK: - FailureDatabase Tests

  @Test("FailureDatabase add and remove")
  func testDatabaseOperations() {
    var database = FailureDatabase()

    let failure1 = PersistedFailure(
      testName: "test1",
      seed: 1,
      originalValue: "a",
      shrunkValue: "a",
      iterationsBeforeFailure: 1,
      shrinkAttempts: 0
    )

    let failure2 = PersistedFailure(
      testName: "test2",
      seed: 2,
      originalValue: "b",
      shrunkValue: "b",
      iterationsBeforeFailure: 1,
      shrinkAttempts: 0
    )

    database.add(failure1)
    database.add(failure2)

    #expect(database.failures.count == 2)

    let removed = database.remove(id: failure1.id)
    #expect(removed?.id == failure1.id)
    #expect(database.failures.count == 1)
  }

  @Test("FailureDatabase filter by test name")
  func testDatabaseFilterByTestName() {
    var database = FailureDatabase()

    for i in 1...5 {
      database.add(
        PersistedFailure(
          testName: i <= 3 ? "testA" : "testB",
          seed: UInt64(i),
          originalValue: "\(i)",
          shrunkValue: "\(i)",
          iterationsBeforeFailure: i,
          shrinkAttempts: 0
        )
      )
    }

    let testAFailures = database.failures(forTest: "testA")
    let testBFailures = database.failures(forTest: "testB")

    #expect(testAFailures.count == 3)
    #expect(testBFailures.count == 2)
  }

  @Test("FailureDatabase recent failures")
  func testRecentFailures() {
    var database = FailureDatabase()

    for i in 1...15 {
      database.add(
        PersistedFailure(
          testName: "test\(i)",
          seed: UInt64(i),
          originalValue: "\(i)",
          shrunkValue: "\(i)",
          timestamp: Date().addingTimeInterval(TimeInterval(i)),
          iterationsBeforeFailure: i,
          shrinkAttempts: 0
        )
      )
    }

    let recent = database.recentFailures(limit: 5)
    #expect(recent.count == 5)
    #expect(recent.first?.testName == "test15")  // Most recent
  }

  // MARK: - FailurePersistenceManager Tests

  @Test("Manager saves and loads failures")
  func testManagerSaveLoad() throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let manager = FailurePersistenceManager(storageDirectory: dir)

    let failure = PersistedFailure(
      testName: "testPersistence",
      seed: 42,
      originalValue: "[1, 2, 3]",
      shrunkValue: "[1]",
      iterationsBeforeFailure: 10,
      shrinkAttempts: 5
    )

    try manager.save(failure)

    let loaded = try manager.loadAll()
    #expect(loaded.count == 1)
    #expect(loaded.first?.testName == "testPersistence")
    #expect(loaded.first?.seed == 42)
  }

  @Test("Manager clears failures")
  func testManagerClear() throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let manager = FailurePersistenceManager(storageDirectory: dir)

    for i in 1...3 {
      try manager.save(
        PersistedFailure(
          testName: "test\(i)",
          seed: UInt64(i),
          originalValue: "\(i)",
          shrunkValue: "\(i)",
          iterationsBeforeFailure: i,
          shrinkAttempts: 0
        )
      )
    }

    #expect(manager.failureCount == 3)

    try manager.clearAll()

    #expect(manager.failureCount == 0)
  }

  @Test("Manager handles empty database")
  func testEmptyDatabase() throws {
    let dir = tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let manager = FailurePersistenceManager(storageDirectory: dir)

    let failures = try manager.loadAll()
    #expect(failures.isEmpty)
    #expect(manager.hasFailures == false)
  }

  // MARK: - Formatted Report Tests

  @Test("Formatted report contains expected elements")
  func testFormattedReport() {
    let failure = PersistedFailure(
      testName: "testReporting",
      seed: 12345,
      originalValue: "[4, 3, 2, 1]",
      shrunkValue: "[2, 1]",
      iterationsBeforeFailure: 50,
      shrinkAttempts: 15,
      failureReason: "Array not sorted"
    )

    let report = failure.formattedReport()

    #expect(report.contains("testReporting"))
    #expect(report.contains("12345"))
    #expect(report.contains("[4, 3, 2, 1]"))
    #expect(report.contains("[2, 1]"))
    #expect(report.contains("Array not sorted"))
    #expect(report.contains("swift test"))
  }
}
