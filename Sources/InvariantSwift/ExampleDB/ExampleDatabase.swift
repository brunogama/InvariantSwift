import Foundation
import Dispatch

// MARK: - Example Database for Corpus Management

/// **Example Database Infrastructure**
///
/// A persistent database for storing and managing test examples, counterexamples,
/// and interesting test cases discovered during property-based testing. This enables:
/// - Regression testing with previously found failures
/// - Corpus-based fuzzing with interesting inputs
/// - Cross-run learning and optimization
/// - Minimized counterexample caching
///
/// **Architecture:**
/// - Actor-based for thread-safe concurrent access
/// - JSON-based storage for portability
/// - Automatic corpus management and pruning
/// - Integration with coverage-guided generation
///
/// **Mathematical Foundation:**
/// Based on corpus-based fuzzing techniques from AFL/LibFuzzer, adapted for
/// property-based testing with shrinking and law preservation.
///
/// **External References:**
/// - [AFL Technical Details](https://lcamtuf.coredump.cx/afl/technical_details.txt)
/// - [LibFuzzer Corpus](https://llvm.org/docs/LibFuzzer.html#corpus)
/// - [Property-Based Testing Patterns](https://hypothesis.readthedocs.io/en/latest/database.html)
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public actor ExampleDatabase {

  // MARK: - Types

  /// **Unique key for identifying test properties**
  public struct ExampleKey: Hashable, Codable, Sendable {
    /// Hash of the property function signature
    public let propertyHash: String

    /// Fingerprint of the generator configuration
    public let generatorFingerprint: String

    /// Optional test suite identifier
    public let testSuite: String?

    public init(propertyHash: String, generatorFingerprint: String, testSuite: String? = nil) {
      self.propertyHash = propertyHash
      self.generatorFingerprint = generatorFingerprint
      self.testSuite = testSuite
    }
  }

  /// **Entry in the example corpus**
  public struct CorpusEntry<T: Codable & Sendable>: Codable, Sendable {
    /// The actual test input value
    public let value: T

    /// Seed that generated this value
    public let seed: UInt64

    /// Minimized/shrunk version if this was a counterexample
    public let minimal: T?

    /// When this example was discovered
    public let discovered: Date

    /// Number of shrink steps if minimized
    public let shrinkSteps: Int

    /// Coverage information if available
    public let coverageInfo: CoverageInfo?

    /// Classification/label for this example
    public let classification: String?

    /// Whether this is an interesting/failure case
    public let isFailure: Bool

    /// Priority for replay (higher = more important)
    public let priority: Int

    public init(
      value: T,
      seed: UInt64,
      minimal: T? = nil,
      discovered: Date = Date(),
      shrinkSteps: Int = 0,
      coverageInfo: CoverageInfo? = nil,
      classification: String? = nil,
      isFailure: Bool = false,
      priority: Int = 0
    ) {
      self.value = value
      self.seed = seed
      self.minimal = minimal
      self.discovered = discovered
      self.shrinkSteps = shrinkSteps
      self.coverageInfo = coverageInfo
      self.classification = classification
      self.isFailure = isFailure
      self.priority = priority
    }
  }

  /// **Coverage information for corpus entries**
  public struct CoverageInfo: Codable, Sendable {
    /// Unique code paths covered
    public let pathsCovered: Set<String>

    /// Branch coverage percentage
    public let branchCoverage: Double

    /// New coverage discovered
    public let isNovel: Bool

    public init(pathsCovered: Set<String>, branchCoverage: Double, isNovel: Bool) {
      self.pathsCovered = pathsCovered
      self.branchCoverage = branchCoverage
      self.isNovel = isNovel
    }
  }

  /// **Database statistics**
  public struct DatabaseStats: Sendable {
    public let totalEntries: Int
    public let failureCount: Int
    public let uniqueProperties: Int
    public let totalSize: Int64
    public let oldestEntry: Date?
    public let newestEntry: Date?
  }

  // MARK: - Properties

  private let dbPath: URL
  private var corpus: [ExampleKey: [AnyCorpusEntry]] = [:]
  private let maxCorpusSize: Int
  private let maxEntriesPerKey: Int
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  /// Type-erased corpus entry for internal storage
  private struct AnyCorpusEntry: Codable {
    let data: Data
    let metadata: CorpusMetadata

    struct CorpusMetadata: Codable {
      let discovered: Date
      let isFailure: Bool
      let priority: Int
      let size: Int
    }
  }

  // MARK: - Initialization

  /// Initialize the example database
  /// - Parameters:
  ///   - path: Path to database directory
  ///   - maxCorpusSize: Maximum total corpus size in entries
  ///   - maxEntriesPerKey: Maximum entries per property key
  public init(
    path: URL? = nil,
    maxCorpusSize: Int = 10000,
    maxEntriesPerKey: Int = 100
  ) async throws {
    self.dbPath = path ?? Self.defaultDatabasePath()
    self.maxCorpusSize = maxCorpusSize
    self.maxEntriesPerKey = maxEntriesPerKey

    // Setup encoder/decoder
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601

    // Create directory if needed
    try FileManager.default.createDirectory(
      at: dbPath,
      withIntermediateDirectories: true
    )

    // Load existing corpus
    try await loadCorpus()
  }

  // MARK: - Public Methods

  /// Store an example in the database
  /// - Parameters:
  ///   - entry: The corpus entry to store
  ///   - key: The property key for this entry
  public func put<T: Codable & Sendable>(
    _ entry: CorpusEntry<T>,
    for key: ExampleKey
  ) async throws {
    let data = try encoder.encode(entry)
    let anyEntry = AnyCorpusEntry(
      data: data,
      metadata: .init(
        discovered: entry.discovered,
        isFailure: entry.isFailure,
        priority: entry.priority,
        size: data.count
      )
    )

    // Add to in-memory corpus
    if corpus[key] == nil {
      corpus[key] = []
    }
    corpus[key]?.append(anyEntry)

    // Prune if needed
    await pruneIfNeeded(for: key)

    // Persist to disk
    try await persist(key: key)
  }

  /// Retrieve examples for a property
  /// - Parameters:
  ///   - key: The property key
  ///   - type: The type to decode entries as
  /// - Returns: Array of corpus entries, sorted by priority
  public func get<T: Codable & Sendable>(
    _ key: ExampleKey,
    as type: T.Type
  ) async throws -> [CorpusEntry<T>] {
    guard let entries = corpus[key] else {
      return []
    }

    return
      entries
      .sorted { $0.metadata.priority > $1.metadata.priority }
      .compactMap { entry in
        try? decoder.decode(CorpusEntry<T>.self, from: entry.data)
      }
  }

  /// Get all failure cases across all properties
  /// - Parameter limit: Maximum number of failures to return
  /// - Returns: Dictionary of failures by property key
  public func getAllFailures(limit: Int = 100) async -> [ExampleKey: [Data]] {
    var failures: [ExampleKey: [Data]] = [:]
    var count = 0

    for (key, entries) in corpus {
      let failureEntries =
        entries
        .filter { $0.metadata.isFailure }
        .prefix(limit - count)
        .map { $0.data }

      if !failureEntries.isEmpty {
        failures[key] = Array(failureEntries)
        count += failureEntries.count
      }

      if count >= limit { break }
    }

    return failures
  }

  /// Promote an interesting example to higher priority
  /// - Parameters:
  ///   - key: The property key
  ///   - index: Index of the entry to promote
  public func promoteInteresting(_ key: ExampleKey, at index: Int) async {
    guard var entries = corpus[key],
      index < entries.count
    else { return }

    // Move to front (highest priority position)
    let promoted = entries.remove(at: index)
    entries.insert(promoted, at: 0)
    corpus[key] = entries
  }

  /// Clear all examples for a specific property
  /// - Parameter key: The property key to clear
  public func clear(_ key: ExampleKey) async throws {
    corpus[key] = nil
    try await persist(key: key, delete: true)
  }

  /// Clear the entire database
  public func clearAll() async throws {
    corpus.removeAll()

    // Remove all files
    let contents = try FileManager.default.contentsOfDirectory(
      at: dbPath,
      includingPropertiesForKeys: nil
    )
    for file in contents {
      try FileManager.default.removeItem(at: file)
    }
  }

  /// Get database statistics
  /// - Returns: Statistics about the database
  public func getStats() async -> DatabaseStats {
    let totalEntries = corpus.values.reduce(0) { $0 + $1.count }
    let failureCount = corpus.values.flatMap { $0 }.filter { $0.metadata.isFailure }.count
    let uniqueProperties = corpus.keys.count
    let totalSize = corpus.values.flatMap { $0 }.reduce(0) { $0 + Int64($1.data.count) }

    let allDates = corpus.values.flatMap { $0 }.map { $0.metadata.discovered }
    let oldestEntry = allDates.min()
    let newestEntry = allDates.max()

    return DatabaseStats(
      totalEntries: totalEntries,
      failureCount: failureCount,
      uniqueProperties: uniqueProperties,
      totalSize: totalSize,
      oldestEntry: oldestEntry,
      newestEntry: newestEntry
    )
  }

  // MARK: - Private Methods

  internal static func defaultDatabasePath() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!

    return
      appSupport
      .appendingPathComponent("FunctionalTesting")
      .appendingPathComponent("ExampleDB")
  }

  private func loadCorpus() async throws {
    let files = try FileManager.default.contentsOfDirectory(
      at: dbPath,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "json" }

    for file in files {
      let data = try Data(contentsOf: file)
      if let corpusData = try? decoder.decode([ExampleKey: [AnyCorpusEntry]].self, from: data) {
        for (key, entries) in corpusData {
          corpus[key] = entries
        }
      }
    }
  }

  private func persist(key: ExampleKey, delete: Bool = false) async throws {
    let filename = "\(key.propertyHash)_\(key.generatorFingerprint).json"
    let fileURL = dbPath.appendingPathComponent(filename)

    if delete {
      try? FileManager.default.removeItem(at: fileURL)
    } else if let entries = corpus[key] {
      let data = try encoder.encode([key: entries])
      try data.write(to: fileURL)
    }
  }

  private func pruneIfNeeded(for key: ExampleKey) async {
    guard let entries = corpus[key],
      entries.count > maxEntriesPerKey
    else { return }

    // Keep failures and high-priority entries
    let failures = entries.filter { $0.metadata.isFailure }
    let nonFailures = entries.filter { !$0.metadata.isFailure }
      .sorted { $0.metadata.priority > $1.metadata.priority }
      .prefix(maxEntriesPerKey - failures.count)

    corpus[key] = failures + Array(nonFailures)
  }
}

// MARK: - Integration with PropertyRunner

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension PropertyRunner {

  /// Run property test with example database integration
  /// - Parameters:
  ///   - property: The property to test
  ///   - config: Test configuration
  ///   - database: Example database for corpus management
  ///   - key: Property key for database storage
  /// - Returns: Test result and database statistics
  public func runPropertyWithDatabase<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default,
    database: ExampleDatabase,
    key: ExampleDatabase.ExampleKey
  ) async -> (PropertyResult<T>, ExampleDatabase.DatabaseStats) where T: Codable & Sendable {

    // First, replay any existing failures
    let existingFailures = try? await database.get(key, as: T.self)
      .filter { $0.isFailure }

    for failure in existingFailures ?? [] {
      if !property.predicate(failure.minimal ?? failure.value) {
        return (
          .failure(
            counterexample: failure.value,
            iterations: 0,
            shrunk: failure.minimal ?? failure.value,
            reason: .predicateFailed,
            seed: Seed(value: failure.seed)
          ),
          await database.getStats()
        )
      }
    }

    // Run normal property test
    let result = runProperty(property, config: config)

    // Store interesting results
    switch result {
    case .failure(let counterexample, _, let shrunk, _, let seed):
      let entry = ExampleDatabase.CorpusEntry(
        value: counterexample,
        seed: seed.rawValue,
        minimal: shrunk,
        discovered: Date(),
        shrinkSteps: 0,
        isFailure: true,
        priority: 100
      )
      try? await database.put(entry, for: key)

    case .success:
      // Optionally store interesting successful cases
      break

    case .gaveUp:
      break
    }

    let stats = await database.getStats()
    return (result, stats)
  }
}
