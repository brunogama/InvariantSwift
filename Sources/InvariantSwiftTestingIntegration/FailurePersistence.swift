// FailurePersistence.swift
// InvariantSwift
//
// Save and replay failing test cases for debugging.
// Implements Task 2.9 from the roadmap.

import Foundation

// MARK: - Persisted Failure

/// A persisted record of a property test failure.
///
/// Contains all information needed to reproduce a failing test case.
public struct PersistedFailure: Sendable, Codable, Identifiable {
  /// Unique identifier for this failure.
  public let id: UUID

  /// Name of the failing test.
  public let testName: String

  /// Seed used to generate the failing value.
  public let seed: UInt64

  /// String representation of the original failing value.
  public let originalValue: String

  /// String representation of the shrunken counterexample.
  public let shrunkValue: String

  /// Timestamp when the failure was recorded.
  public let timestamp: Date

  /// Number of iterations before failure.
  public let iterationsBeforeFailure: Int

  /// Number of shrink attempts performed.
  public let shrinkAttempts: Int

  /// Optional error message or reason for failure.
  public let failureReason: String?

  /// Git commit hash at time of failure (if available).
  public let gitCommit: String?

  /// Creates a new persisted failure record.
  public init(
    id: UUID = UUID(),
    testName: String,
    seed: UInt64,
    originalValue: String,
    shrunkValue: String,
    timestamp: Date = Date(),
    iterationsBeforeFailure: Int,
    shrinkAttempts: Int,
    failureReason: String? = nil,
    gitCommit: String? = nil
  ) {
    self.id = id
    self.testName = testName
    self.seed = seed
    self.originalValue = originalValue
    self.shrunkValue = shrunkValue
    self.timestamp = timestamp
    self.iterationsBeforeFailure = iterationsBeforeFailure
    self.shrinkAttempts = shrinkAttempts
    self.failureReason = failureReason
    self.gitCommit = gitCommit
  }

  /// Command to reproduce this failure.
  public var reproductionCommand: String {
    "swift test --filter \(testName) --seed \(seed)"
  }
}

// MARK: - Failure Database

/// Container for multiple persisted failures.
public struct FailureDatabase: Sendable, Codable {
  /// Version of the database format.
  public let version: Int

  /// All recorded failures.
  public var failures: [PersistedFailure]

  /// Timestamp of last update.
  public var lastUpdated: Date

  /// Creates a new failure database.
  public init(version: Int = 1, failures: [PersistedFailure] = [], lastUpdated: Date = Date()) {
    self.version = version
    self.failures = failures
    self.lastUpdated = lastUpdated
  }

  /// Adds a failure to the database.
  public mutating func add(_ failure: PersistedFailure) {
    failures.append(failure)
    lastUpdated = Date()
  }

  /// Removes a failure by ID.
  @discardableResult
  public mutating func remove(id: UUID) -> PersistedFailure? {
    guard let index = failures.firstIndex(where: { $0.id == id }) else { return nil }
    lastUpdated = Date()
    return failures.remove(at: index)
  }

  /// Removes all failures for a specific test.
  public mutating func removeAll(forTest testName: String) {
    failures.removeAll { $0.testName == testName }
    lastUpdated = Date()
  }

  /// Returns failures for a specific test.
  public func failures(forTest testName: String) -> [PersistedFailure] {
    failures.filter { $0.testName == testName }
  }

  /// Returns the most recent failures.
  public func recentFailures(limit: Int = 10) -> [PersistedFailure] {
    Array(failures.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
  }
}

// MARK: - Failure Persistence Manager

/// Manages persistence of failure records to disk.
///
/// Failures are saved to `.invariantswift/failures.json` in the project directory.
/// This file should be git-ignored.
///
/// ## Example Usage
///
/// ```swift
/// let manager = FailurePersistenceManager()
///
/// // Save a failure
/// let failure = PersistedFailure(
///     testName: "testSorting",
///     seed: 12345,
///     originalValue: "[3, 1, 2]",
///     shrunkValue: "[2, 1]",
///     iterationsBeforeFailure: 42,
///     shrinkAttempts: 10
/// )
/// try manager.save(failure)
///
/// // Load all failures
/// let failures = try manager.loadAll()
///
/// // Replay failures for a specific test
/// let sorting = manager.failures(forTest: "testSorting")
/// ```
public final class FailurePersistenceManager: @unchecked Sendable {

  // MARK: - Properties

  /// Directory where failures are stored.
  public let storageDirectory: URL

  /// Path to the failures JSON file.
  public var failuresPath: URL {
    storageDirectory.appendingPathComponent("failures.json")
  }

  private let fileManager = FileManager.default
  private let lock = NSLock()

  // MARK: - Initialization

  /// Creates a new failure persistence manager.
  ///
  /// - Parameter storageDirectory: Optional custom directory. Defaults to `.invariantswift/`.
  public init(storageDirectory: URL? = nil) {
    if let dir = storageDirectory {
      self.storageDirectory = dir
    } else {
      // Default to .invariantswift in current directory
      self.storageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".invariantswift")
    }
  }

  // MARK: - Storage Operations

  /// Ensures the storage directory exists.
  private func ensureDirectoryExists() throws {
    if !fileManager.fileExists(atPath: storageDirectory.path) {
      try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }
  }

  /// Loads the failure database from disk.
  ///
  /// - Returns: The loaded database, or a new empty one if not found.
  public func loadDatabase() throws -> FailureDatabase {
    lock.lock()
    defer { lock.unlock() }

    guard fileManager.fileExists(atPath: failuresPath.path) else {
      return FailureDatabase()
    }

    let data = try Data(contentsOf: failuresPath)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(FailureDatabase.self, from: data)
  }

  /// Saves the failure database to disk.
  ///
  /// - Parameter database: The database to save.
  public func saveDatabase(_ database: FailureDatabase) throws {
    lock.lock()
    defer { lock.unlock() }

    try ensureDirectoryExists()

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let data = try encoder.encode(database)
    try data.write(to: failuresPath, options: .atomic)
  }

  // MARK: - Convenience Methods

  /// Saves a single failure.
  ///
  /// - Parameter failure: The failure to save.
  public func save(_ failure: PersistedFailure) throws {
    var database = try loadDatabase()
    database.add(failure)
    try saveDatabase(database)
  }

  /// Loads all failures.
  ///
  /// - Returns: Array of all persisted failures.
  public func loadAll() throws -> [PersistedFailure] {
    try loadDatabase().failures
  }

  /// Returns failures for a specific test.
  ///
  /// - Parameter testName: Name of the test to filter by.
  /// - Returns: Array of failures for that test.
  public func failures(forTest testName: String) throws -> [PersistedFailure] {
    try loadDatabase().failures(forTest: testName)
  }

  /// Removes a failure by ID.
  ///
  /// - Parameter id: The failure ID to remove.
  public func remove(id: UUID) throws {
    var database = try loadDatabase()
    database.remove(id: id)
    try saveDatabase(database)
  }

  /// Removes all failures.
  public func clearAll() throws {
    try saveDatabase(FailureDatabase())
  }

  /// Removes all failures for a specific test.
  ///
  /// - Parameter testName: Name of the test to clear.
  public func clearFailures(forTest testName: String) throws {
    var database = try loadDatabase()
    database.removeAll(forTest: testName)
    try saveDatabase(database)
  }

  /// Returns the most recent failures.
  ///
  /// - Parameter limit: Maximum number of failures to return.
  /// - Returns: Array of recent failures.
  public func recentFailures(limit: Int = 10) throws -> [PersistedFailure] {
    try loadDatabase().recentFailures(limit: limit)
  }

  /// Checks if any failures exist.
  public var hasFailures: Bool {
    (try? loadAll().isEmpty == false) ?? false
  }

  /// Count of stored failures.
  public var failureCount: Int {
    (try? loadAll().count) ?? 0
  }
}

// MARK: - Failure Report

extension PersistedFailure {
  /// Generates a formatted failure report.
  public func formattedReport() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .medium

    return """
      ╭─────────────────────────────────────────────────────────────╮
      │ PROPERTY TEST FAILURE                                       │
      ├─────────────────────────────────────────────────────────────┤
      │ Test: \(testName)
      │ Date: \(dateFormatter.string(from: timestamp))
      │ Seed: \(seed)
      ├─────────────────────────────────────────────────────────────┤
      │ Original value:
      │   \(originalValue)
      │ Shrunken counterexample:
      │   \(shrunkValue)
      ├─────────────────────────────────────────────────────────────┤
      │ Iterations before failure: \(iterationsBeforeFailure)
      │ Shrink attempts: \(shrinkAttempts)
      │ Failure reason: \(failureReason ?? "property predicate failed")
      ├─────────────────────────────────────────────────────────────┤
      │ To reproduce:
      │   \(reproductionCommand)
      ╰─────────────────────────────────────────────────────────────╯
      """
  }
}
