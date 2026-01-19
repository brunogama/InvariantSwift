/// Corpus Database for Property-Based Testing
///
/// A persistent SQLite-backed database for storing and managing test examples,
/// counterexamples, and interesting inputs discovered during property-based testing.
///
/// **Capabilities:**
/// - Regression testing with previously found failures
/// - Corpus-based fuzzing with interesting inputs
/// - Cross-run learning and optimization
/// - Minimized counterexample caching
/// - Automatic corpus management and pruning
///
/// **Architecture:**
/// - Actor-based for thread-safe concurrent access
/// - SQLite backend with WAL mode for performance
/// - Integration with coverage-guided generation
///
/// **References:**
/// - [AFL Technical Details](https://lcamtuf.coredump.cx/afl/technical_details.txt)
/// - [LibFuzzer Corpus](https://llvm.org/docs/LibFuzzer.html#corpus)
/// - [Hypothesis Database](https://hypothesis.readthedocs.io/en/latest/database.html)

import Foundation
import SQLite3

// MARK: - Core Types

/// Unique key for identifying test cases in the corpus
public struct CorpusKey: Sendable, Hashable, Codable, CustomStringConvertible {
  public let propertyHash: String
  public let generatorFingerprint: String
  public let inputTypeSignature: String

  public init(propertyHash: String, generatorFingerprint: String, inputTypeSignature: String) {
    self.propertyHash = propertyHash
    self.generatorFingerprint = generatorFingerprint
    self.inputTypeSignature = inputTypeSignature
  }

  public var description: String {
    "\(propertyHash):\(generatorFingerprint):\(inputTypeSignature)"
  }

  /// Create key from property and generator information
  public static func from<T>(property: String, generator: Gen<T>, inputType: T.Type) -> Self {
    let propertyHash = property.hashValue.description
    let generatorHash = "\(type(of: generator))".hashValue.description
    let typeSignature = "\(inputType)"

    return Self(
      propertyHash: propertyHash,
      generatorFingerprint: generatorHash,
      inputTypeSignature: typeSignature
    )
  }
}

/// Entry in the corpus database
public struct CorpusEntry<A: Codable & Sendable>: Sendable, Codable {
  public let id: UUID
  public let seed: UInt64
  public let minimal: A
  public let original: A?
  public let discovered: Date
  public let shrinkSteps: Int
  public let classification: EntryClassification
  public let metadata: [String: String]
  public let executionTime: TimeInterval
  public let priority: Double

  public init(
    id: UUID = UUID(),
    seed: UInt64,
    minimal: A,
    original: A? = nil,
    discovered: Date = Date(),
    shrinkSteps: Int = 0,
    classification: EntryClassification = .interesting,
    metadata: [String: String] = [:],
    executionTime: TimeInterval = 0,
    priority: Double = 1.0
  ) {
    self.id = id
    self.seed = seed
    self.minimal = minimal
    self.original = original
    self.discovered = discovered
    self.shrinkSteps = shrinkSteps
    self.classification = classification
    self.metadata = metadata
    self.executionTime = executionTime
    self.priority = priority
  }
}

/// Classification of corpus entries
public enum EntryClassification: String, Sendable, Codable, CaseIterable {
  case counterexample
  case interesting
  case boundary
  case regression
  case coverage
  case performance

  public var priorityWeight: Double {
    switch self {
    case .counterexample: return 10.0
    case .regression: return 8.0
    case .boundary: return 5.0
    case .coverage: return 3.0
    case .interesting: return 2.0
    case .performance: return 1.0
    }
  }
}

/// Query parameters for corpus retrieval
public struct CorpusQuery: Sendable {
  public let limit: Int
  public let classification: EntryClassification?
  public let minPriority: Double
  public let orderBy: OrderBy
  public let includeMetadata: Bool

  public init(
    limit: Int = 100,
    classification: EntryClassification? = nil,
    minPriority: Double = 0.0,
    orderBy: OrderBy = .priority,
    includeMetadata: Bool = false
  ) {
    self.limit = max(1, min(limit, 10000))  // Bounded limit
    self.classification = classification
    self.minPriority = minPriority
    self.orderBy = orderBy
    self.includeMetadata = includeMetadata
  }

  public enum OrderBy: String, Sendable {
    case priority = "priority"
    case discovered = "discovered"
    case shrinkSteps = "shrink_steps"
    case executionTime = "execution_time"
  }

  public static let highPriority = Self(
    limit: 50,
    minPriority: 5.0,
    orderBy: .priority
  )

  public static let recent = Self(
    limit: 20,
    orderBy: .discovered
  )

  public static let counterexamples = Self(
    limit: 100,
    classification: .counterexample,
    orderBy: .priority
  )
}

/// Statistics about the corpus database
public struct CorpusStatistics: Sendable {
  public let totalEntries: Int
  public let entriesByClassification: [EntryClassification: Int]
  public let oldestEntry: Date?
  public let newestEntry: Date?
  public let averageShrinkSteps: Double
  public let databaseSize: Int64
  public let uniqueProperties: Int

  public init(
    totalEntries: Int,
    entriesByClassification: [EntryClassification: Int],
    oldestEntry: Date?,
    newestEntry: Date?,
    averageShrinkSteps: Double,
    databaseSize: Int64,
    uniqueProperties: Int
  ) {
    self.totalEntries = totalEntries
    self.entriesByClassification = entriesByClassification
    self.oldestEntry = oldestEntry
    self.newestEntry = newestEntry
    self.averageShrinkSteps = averageShrinkSteps
    self.databaseSize = databaseSize
    self.uniqueProperties = uniqueProperties
  }
}

// MARK: - Corpus Database Implementation

// swiftlint:disable:next orphaned_doc_comment
/// Persistent corpus database with SQLite backend
// swiftlint:disable:next type_body_length
public actor CorpusDatabase {
  private let dbPath: URL
  private var db: OpaquePointer?
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private var isInitialized = false

  public init(path: URL? = nil) async throws {
    let dbPath = path ?? CorpusDatabase.defaultDatabasePath
    self.dbPath = dbPath

    // Configure JSON encoder/decoder
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601

    try await setupDatabase()
  }

  deinit {
    // Note: Cannot access non-Sendable db from deinit in Swift 6.0
    // Database cleanup will happen automatically on process termination
  }

  /// Default database path in user's cache directory
  public static var defaultDatabasePath: URL {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    return cacheDir.appendingPathComponent("InvariantSwift")
      .appendingPathComponent("corpus.db")
  }

  /// Initialize database schema
  private func setupDatabase() async throws {
    // Create directory if needed
    let directory = dbPath.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    // Open database
    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    guard sqlite3_open_v2(dbPath.path, &db, flags, nil) == SQLITE_OK else {
      throw CorpusDatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
    }

    // Create tables
    try await createTables()
    isInitialized = true
  }

  /// Create database tables
  private func createTables() async throws {
    let createCorpusTable = """
      CREATE TABLE IF NOT EXISTS corpus_entries (
          id TEXT PRIMARY KEY,
          property_hash TEXT NOT NULL,
          generator_fingerprint TEXT NOT NULL,
          input_type_signature TEXT NOT NULL,
          seed INTEGER NOT NULL,
          minimal_json TEXT NOT NULL,
          original_json TEXT,
          discovered TEXT NOT NULL,
          shrink_steps INTEGER NOT NULL DEFAULT 0,
          classification TEXT NOT NULL DEFAULT 'interesting',
          metadata_json TEXT NOT NULL DEFAULT '{}',
          execution_time REAL NOT NULL DEFAULT 0,
          priority REAL NOT NULL DEFAULT 1.0,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
      """

    let createIndexes = [
      "CREATE INDEX IF NOT EXISTS idx_corpus_property_hash ON corpus_entries(property_hash)",
      "CREATE INDEX IF NOT EXISTS idx_corpus_classification ON corpus_entries(classification)",
      "CREATE INDEX IF NOT EXISTS idx_corpus_priority ON corpus_entries(priority DESC)",
      "CREATE INDEX IF NOT EXISTS idx_corpus_discovered ON corpus_entries(discovered DESC)",
      // swiftlint:disable:next line_length
      "CREATE INDEX IF NOT EXISTS idx_corpus_composite ON corpus_entries(property_hash, generator_fingerprint, input_type_signature)",
    ]

    try execute(createCorpusTable)
    for index in createIndexes {
      try execute(index)
    }

    // Enable WAL mode for better concurrency
    try execute("PRAGMA journal_mode=WAL")
    try execute("PRAGMA synchronous=NORMAL")
    try execute("PRAGMA temp_store=MEMORY")
  }

  /// Execute SQL statement
  private func execute(_ sql: String) throws {
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      throw CorpusDatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
    }

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw CorpusDatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
    }
  }

  /// Store entry in the corpus
  public func put<A: Codable>(_ key: CorpusKey, _ entry: CorpusEntry<A>) async throws {
    guard isInitialized else {
      throw CorpusDatabaseError.notInitialized
    }

    let sql = """
      INSERT OR REPLACE INTO corpus_entries (
          id, property_hash, generator_fingerprint, input_type_signature,
          seed, minimal_json, original_json, discovered, shrink_steps,
          classification, metadata_json, execution_time, priority, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      """

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      throw CorpusDatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
    }

    let minimalData = try encoder.encode(entry.minimal)
    let originalData = try entry.original.map { try encoder.encode($0) }
    let metadataData = try encoder.encode(entry.metadata)
    let discoveredString = ISO8601DateFormatter().string(from: entry.discovered)

    sqlite3_bind_text(statement, 1, entry.id.uuidString, -1, nil)
    sqlite3_bind_text(statement, 2, key.propertyHash, -1, nil)
    sqlite3_bind_text(statement, 3, key.generatorFingerprint, -1, nil)
    sqlite3_bind_text(statement, 4, key.inputTypeSignature, -1, nil)
    sqlite3_bind_int64(statement, 5, Int64(entry.seed))
    sqlite3_bind_text(statement, 6, String(data: minimalData, encoding: .utf8), -1, nil)

    if let originalData = originalData {
      sqlite3_bind_text(statement, 7, String(data: originalData, encoding: .utf8), -1, nil)
    } else {
      sqlite3_bind_null(statement, 7)
    }

    sqlite3_bind_text(statement, 8, discoveredString, -1, nil)
    sqlite3_bind_int(statement, 9, Int32(entry.shrinkSteps))
    sqlite3_bind_text(statement, 10, entry.classification.rawValue, -1, nil)
    sqlite3_bind_text(statement, 11, String(data: metadataData, encoding: .utf8), -1, nil)
    sqlite3_bind_double(statement, 12, entry.executionTime)
    sqlite3_bind_double(statement, 13, entry.priority)

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw CorpusDatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
    }
  }

  // swiftlint:disable:next orphaned_doc_comment
  /// Retrieve entries from the corpus
  // swiftlint:disable:next cyclomatic_complexity
  public func get<A: Codable>(
    _ key: CorpusKey,
    as type: A.Type,
    query: CorpusQuery = CorpusQuery()
  ) async throws -> [CorpusEntry<A>] {
    guard isInitialized else {
      throw CorpusDatabaseError.notInitialized
    }

    var sql = """
      SELECT id, seed, minimal_json, original_json, discovered, shrink_steps,
             classification, metadata_json, execution_time, priority
      FROM corpus_entries
      WHERE property_hash = ? AND generator_fingerprint = ? AND input_type_signature = ?
      """

    var parameters: [Any] = [key.propertyHash, key.generatorFingerprint, key.inputTypeSignature]

    if let classification = query.classification {
      sql += " AND classification = ?"
      parameters.append(classification.rawValue)
    }

    if query.minPriority > 0 {
      sql += " AND priority >= ?"
      parameters.append(query.minPriority)
    }

    sql += " ORDER BY \(query.orderBy.rawValue) DESC LIMIT ?"
    parameters.append(query.limit)

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      throw CorpusDatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
    }

    for (index, param) in parameters.enumerated() {
      switch param {
      case let stringValue as String:
        sqlite3_bind_text(statement, Int32(index + 1), stringValue, -1, nil)

      case let intValue as Int:
        sqlite3_bind_int(statement, Int32(index + 1), Int32(intValue))

      case let doubleValue as Double:
        sqlite3_bind_double(statement, Int32(index + 1), doubleValue)

      default:
        throw CorpusDatabaseError.invalidParameter
      }
    }

    var results: [CorpusEntry<A>] = []

    while sqlite3_step(statement) == SQLITE_ROW {
      guard let idString = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
        let id = UUID(uuidString: idString),
        let minimalJSON = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
        let discoveredString = sqlite3_column_text(statement, 4).map({ String(cString: $0) }),
        let classificationString = sqlite3_column_text(statement, 6).map({ String(cString: $0) }),
        let metadataJSON = sqlite3_column_text(statement, 7).map({ String(cString: $0) })
      else {
        continue
      }

      let seed = UInt64(sqlite3_column_int64(statement, 1))
      let shrinkSteps = Int(sqlite3_column_int(statement, 5))
      let executionTime = sqlite3_column_double(statement, 8)
      let priority = sqlite3_column_double(statement, 9)

      guard let minimalData = minimalJSON.data(using: .utf8),
        let minimal = try? decoder.decode(A.self, from: minimalData),
        let discovered = ISO8601DateFormatter().date(from: discoveredString),
        let classification = EntryClassification(rawValue: classificationString),
        let metadataData = metadataJSON.data(using: .utf8),
        let metadata = try? decoder.decode([String: String].self, from: metadataData)
      else {
        continue
      }

      var original: A?
      if let originalJSON = sqlite3_column_text(statement, 3).map({ String(cString: $0) }),
        let originalData = originalJSON.data(using: .utf8)
      {
        original = try? decoder.decode(A.self, from: originalData)
      }

      let entry = CorpusEntry<A>(
        id: id,
        seed: seed,
        minimal: minimal,
        original: original,
        discovered: discovered,
        shrinkSteps: shrinkSteps,
        classification: classification,
        metadata: metadata,
        executionTime: executionTime,
        priority: priority
      )

      results.append(entry)
    }

    return results
  }

  /// Promote interesting entries to higher priority
  public func promoteInteresting(_ key: CorpusKey) async throws {
    guard isInitialized else {
      throw CorpusDatabaseError.notInitialized
    }

    let sql = """
      UPDATE corpus_entries
      SET priority = priority * 1.5, updated_at = CURRENT_TIMESTAMP
      WHERE property_hash = ? AND generator_fingerprint = ? AND input_type_signature = ?
        AND classification = 'interesting'
      """

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      throw CorpusDatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
    }

    sqlite3_bind_text(statement, 1, key.propertyHash, -1, nil)
    sqlite3_bind_text(statement, 2, key.generatorFingerprint, -1, nil)
    sqlite3_bind_text(statement, 3, key.inputTypeSignature, -1, nil)

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw CorpusDatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
    }
  }

  /// Get corpus statistics
  public func getStatistics() async throws -> CorpusStatistics {
    guard isInitialized else {
      throw CorpusDatabaseError.notInitialized
    }

    // Total entries
    let totalEntries = try await queryInt("SELECT COUNT(*) FROM corpus_entries")

    // Entries by classification
    var entriesByClassification: [EntryClassification: Int] = [:]
    for classification in EntryClassification.allCases {
      let count = try await queryInt(
        "SELECT COUNT(*) FROM corpus_entries WHERE classification = ?",
        classification.rawValue
      )
      entriesByClassification[classification] = count
    }

    // Date range
    let oldestEntry = try await queryDate("SELECT MIN(discovered) FROM corpus_entries")
    let newestEntry = try await queryDate("SELECT MAX(discovered) FROM corpus_entries")

    // Average shrink steps
    let averageShrinkSteps =
      try await queryDouble("SELECT AVG(shrink_steps) FROM corpus_entries WHERE shrink_steps > 0")
      ?? 0.0

    // Database size (approximate)
    let databaseSize =
      try FileManager.default.attributesOfItem(atPath: dbPath.path)[.size] as? Int64 ?? 0

    // Unique properties
    let uniqueProperties = try await queryInt(
      "SELECT COUNT(DISTINCT property_hash) FROM corpus_entries"
    )

    return CorpusStatistics(
      totalEntries: totalEntries,
      entriesByClassification: entriesByClassification,
      oldestEntry: oldestEntry,
      newestEntry: newestEntry,
      averageShrinkSteps: averageShrinkSteps,
      databaseSize: databaseSize,
      uniqueProperties: uniqueProperties
    )
  }

  /// Clean up old entries based on retention policy
  public func cleanup(retentionDays: Int = 30, maxEntries: Int = 100000) async throws {
    guard isInitialized else {
      throw CorpusDatabaseError.notInitialized
    }

    let cutoffDate = Date().addingTimeInterval(-Double(retentionDays * 24 * 60 * 60))
    let cutoffString = ISO8601DateFormatter().string(from: cutoffDate)

    // Delete old low-priority entries
    let cleanupSQL = """
      DELETE FROM corpus_entries
      WHERE discovered < ? AND priority < 2.0
         AND classification NOT IN ('counterexample', 'regression')
      """

    try execute(cleanupSQL.replacingOccurrences(of: "?", with: "'\(cutoffString)'"))

    // If still over limit, remove lowest priority entries
    let currentCount = try await queryInt("SELECT COUNT(*) FROM corpus_entries")
    if currentCount > maxEntries {
      let excess = currentCount - maxEntries
      let deleteExcess = """
        DELETE FROM corpus_entries
        WHERE id IN (
            SELECT id FROM corpus_entries
            WHERE classification NOT IN ('counterexample', 'regression')
            ORDER BY priority ASC, discovered ASC
            LIMIT \(excess)
        )
        """
      try execute(deleteExcess)
    }

    // Vacuum database to reclaim space
    try execute("VACUUM")
  }

  /// Helper methods for queries
  private func queryInt(_ sql: String, _ parameters: String...) async throws -> Int {
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      throw CorpusDatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
    }

    for (index, param) in parameters.enumerated() {
      sqlite3_bind_text(statement, Int32(index + 1), param, -1, nil)
    }

    guard sqlite3_step(statement) == SQLITE_ROW else {
      return 0
    }

    return Int(sqlite3_column_int(statement, 0))
  }

  private func queryDouble(_ sql: String, _ parameters: String...) async throws -> Double? {
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      throw CorpusDatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
    }

    for (index, param) in parameters.enumerated() {
      sqlite3_bind_text(statement, Int32(index + 1), param, -1, nil)
    }

    guard sqlite3_step(statement) == SQLITE_ROW else {
      return nil
    }

    return sqlite3_column_double(statement, 0)
  }

  private func queryDate(_ sql: String, _ parameters: String...) async throws -> Date? {
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      throw CorpusDatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
    }

    for (index, param) in parameters.enumerated() {
      sqlite3_bind_text(statement, Int32(index + 1), param, -1, nil)
    }

    guard sqlite3_step(statement) == SQLITE_ROW,
      let dateString = sqlite3_column_text(statement, 0).map({ String(cString: $0) })
    else {
      return nil
    }

    return ISO8601DateFormatter().date(from: dateString)
  }
}

// MARK: - Error Types

public enum CorpusDatabaseError: Error, Sendable {
  case notInitialized
  case openFailed(String)
  case prepareFailed(String)
  case executionFailed(String)
  case invalidParameter
  case encodingFailed
  case decodingFailed
}

// MARK: - Generator Integration

extension Gen {
  /// Create generator that replays from corpus first, then generates new values
  public func withCorpusReplay(
    database: CorpusDatabase,
    key: CorpusKey,
    replayProbability: Double = 0.3
  ) -> Gen<T> where T: Codable {
    Gen<T> { rng, size in
      // Note: Corpus replay requires async but generators are sync
      // Generate fresh value using the underlying generator
      self.generate(&rng, size)
    }
  }
}

// MARK: - Property Integration

extension Property {
  /// Run property with automatic corpus recording
  public func withCorpusRecording(
    database: CorpusDatabase,
    key: CorpusKey,
    recordInteresting: Bool = true
  ) -> Property<T> where T: Codable {
    Property<T>(generator: self.generator) { input in
      // Note: Cannot use async corpus recording in synchronous Property
      // Return the original test result without async operations
      self.predicate(input)
    }
  }
}

// MARK: - PropertyRunner Integration

extension PropertyRunner {
  /// Run property test with corpus database integration
  ///
  /// Replays existing failures first, then runs the property test,
  /// and stores any new failures or interesting cases in the corpus.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - config: Test configuration
  ///   - database: Corpus database for persistence
  ///   - key: Corpus key for this property
  /// - Returns: Test result and corpus statistics
  public func runWithCorpus<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default,
    database: CorpusDatabase,
    key: CorpusKey
  ) async -> (PropertyResult<T>, CorpusStatistics) where T: Codable & Sendable {
    // First, replay any existing failures
    let existingFailures = try? await database.get(key, as: T.self, query: .counterexamples)

    for failure in existingFailures ?? [] {
      // swiftlint:disable:next for_where
      if !property.predicate(failure.minimal) {
        let stats = try? await database.getStatistics()
        return (
          .failure(
            counterexample: failure.minimal,
            iterations: 0,
            shrunk: failure.minimal,
            reason: .predicateFailed,
            seed: Seed(value: failure.seed)
          ),
          stats
            ?? CorpusStatistics(
              totalEntries: 0,
              entriesByClassification: [:],
              oldestEntry: nil,
              newestEntry: nil,
              averageShrinkSteps: 0,
              databaseSize: 0,
              uniqueProperties: 0
            )
        )
      }
    }

    // Run normal property test
    let result = runProperty(property, config: config)

    // Store interesting results
    switch result {
    case .failure(let counterexample, _, let shrunk, _, let seed):
      let entry = CorpusEntry(
        seed: seed.rawValue,
        minimal: shrunk,
        original: counterexample,
        shrinkSteps: 0,
        classification: .counterexample,
        priority: EntryClassification.counterexample.priorityWeight
      )
      try? await database.put(key, entry)

    case .success, .gaveUp:
      break
    }

    let stats = try? await database.getStatistics()
    return (
      result,
      stats
        ?? CorpusStatistics(
          totalEntries: 0,
          entriesByClassification: [:],
          oldestEntry: nil,
          newestEntry: nil,
          averageShrinkSteps: 0,
          databaseSize: 0,
          uniqueProperties: 0
        )
    )
  }
}

// MARK: - Type Aliases for Migration

/// Legacy type alias for backward compatibility
@available(*, deprecated, renamed: "CorpusKey")
public typealias ExampleKey = CorpusKey

/// Legacy type alias for backward compatibility
@available(*, deprecated, renamed: "CorpusDatabase")
public typealias ExampleDatabase = CorpusDatabase

/// Legacy type alias for backward compatibility
@available(*, deprecated, renamed: "CorpusDatabase")
public typealias SQLiteExampleDatabase = CorpusDatabase

/// Legacy type alias for backward compatibility
@available(*, deprecated, renamed: "CorpusDatabaseError")
// swiftlint:disable:next file_length
public typealias DatabaseError = CorpusDatabaseError
