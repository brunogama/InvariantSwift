import Foundation

// MARK: - Regression Test Banking

/// A stored failure case for regression testing.
///
/// `FailureEntry` captures minimal information needed to reproduce a failing test:
/// - The property label identifying which test failed
/// - The seed that generated the failure
/// - A human-readable description of the shrunk counterexample
///
/// The seed is the primary mechanism for reproduction—by replaying with the same
/// seed, the property runner will generate the same sequence and hit the same failure.
public struct FailureEntry: Codable, Sendable, Hashable {
  /// Property label or test identifier
  public let propertyLabel: String

  /// Seed value that reproduces this failure
  public let seedValue: UInt64

  /// Human-readable description of the shrunk counterexample
  public let counterexampleDescription: String

  /// Failure reason description
  public let failureReason: String

  /// Timestamp when the failure was recorded
  public let timestamp: Date

  /// Iteration count when failure occurred
  public let failedAtIteration: Int

  public init(
    propertyLabel: String,
    seedValue: UInt64,
    counterexampleDescription: String,
    failureReason: String,
    timestamp: Date = Date(),
    failedAtIteration: Int
  ) {
    self.propertyLabel = propertyLabel
    self.seedValue = seedValue
    self.counterexampleDescription = counterexampleDescription
    self.failureReason = failureReason
    self.timestamp = timestamp
    self.failedAtIteration = failedAtIteration
  }
}

/// Actor-based regression bank for persisting and replaying failed test cases.
///
/// `RegressionBank` provides:
/// - **Persistence**: Save failing test cases to disk (`.invariant/failures.json`)
/// - **Replay**: Load banked failures and replay them before random generation
/// - **Deduplication**: Avoid storing duplicate failures for the same property/seed
///
/// **Usage**:
/// ```swift
/// let bank = RegressionBank()
///
/// // After a property fails:
/// await bank.recordFailure(
///   propertyLabel: "testArrayReverse",
///   seed: failingSeed,
///   counterexample: shrunkValue,
///   reason: .predicateFailed,
///   iteration: 42
/// )
///
/// // Before running tests, get seeds to replay:
/// let seedsToReplay = await bank.seedsForProperty("testArrayReverse")
/// for seed in seedsToReplay {
///   // Run property with this seed first
/// }
/// ```
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor RegressionBank {

  // MARK: - Configuration

  /// Directory where regression data is stored
  private let storageDirectory: URL

  /// Filename for the failures database
  private static let failuresFileName = "failures.json"

  /// In-memory cache of failures
  private var cachedFailures: [FailureEntry] = []

  /// Whether the cache has been loaded from disk
  private var isLoaded = false

  // MARK: - Initialization

  /// Initialize a regression bank with the default storage location.
  ///
  /// Uses `.invariant/` directory in the current working directory.
  public init() {
    let cwd = FileManager.default.currentDirectoryPath
    self.storageDirectory = URL(fileURLWithPath: cwd)
      .appendingPathComponent(".invariant", isDirectory: true)
  }

  /// Initialize a regression bank with a custom storage directory.
  ///
  /// - Parameter directory: Directory URL where failures will be stored
  public init(directory: URL) {
    self.storageDirectory = directory
  }

  // MARK: - Public API

  /// Record a new failure to the regression bank.
  ///
  /// - Parameters:
  ///   - propertyLabel: Identifier for the property test
  ///   - seed: The seed that produced this failure
  ///   - counterexample: The shrunk counterexample value
  ///   - reason: Why the property failed
  ///   - iteration: Which iteration failed
  public func recordFailure<T: CustomStringConvertible>(
    propertyLabel: String,
    seed: Seed,
    counterexample: T,
    reason: FailureReason,
    iteration: Int
  ) async throws {
    await ensureLoaded()

    let entry = FailureEntry(
      propertyLabel: propertyLabel,
      seedValue: seed.rawValue,
      counterexampleDescription: String(describing: counterexample),
      failureReason: reason.description,
      failedAtIteration: iteration
    )

    // Deduplicate by property + seed
    if !cachedFailures.contains(where: {
      $0.propertyLabel == entry.propertyLabel && $0.seedValue == entry.seedValue
    }) {
      cachedFailures.append(entry)
      try await save()
    }
  }

  /// Get all seeds that should be replayed for a given property.
  ///
  /// - Parameter propertyLabel: The property identifier
  /// - Returns: Array of seeds to replay (oldest first)
  public func seedsForProperty(_ propertyLabel: String) async -> [Seed] {
    await ensureLoaded()
    return
      cachedFailures
      .filter { $0.propertyLabel == propertyLabel }
      .sorted { $0.timestamp < $1.timestamp }
      .map { Seed(value: $0.seedValue) }
  }

  /// Get all banked failure entries.
  ///
  /// - Returns: All stored failure entries
  public func allFailures() async -> [FailureEntry] {
    await ensureLoaded()
    return cachedFailures
  }

  /// Get failures for a specific property.
  ///
  /// - Parameter propertyLabel: The property identifier
  /// - Returns: Failure entries for that property
  public func failuresForProperty(_ propertyLabel: String) async -> [FailureEntry] {
    await ensureLoaded()
    return cachedFailures.filter { $0.propertyLabel == propertyLabel }
  }

  /// Remove a specific failure from the bank (e.g., when bug is fixed).
  ///
  /// - Parameters:
  ///   - propertyLabel: The property identifier
  ///   - seed: The seed to remove
  public func removeFailure(propertyLabel: String, seed: Seed) async throws {
    await ensureLoaded()
    cachedFailures.removeAll {
      $0.propertyLabel == propertyLabel && $0.seedValue == seed.rawValue
    }
    try await save()
  }

  /// Remove all failures for a given property.
  ///
  /// - Parameter propertyLabel: The property identifier
  public func clearFailuresForProperty(_ propertyLabel: String) async throws {
    await ensureLoaded()
    cachedFailures.removeAll { $0.propertyLabel == propertyLabel }
    try await save()
  }

  /// Remove all banked failures.
  public func clearAll() async throws {
    cachedFailures = []
    try await save()
  }

  /// Get summary statistics about the regression bank.
  public func statistics() async -> BankStatistics {
    await ensureLoaded()

    let propertyCounts = Dictionary(grouping: cachedFailures, by: \.propertyLabel)
      .mapValues(\.count)

    return BankStatistics(
      totalFailures: cachedFailures.count,
      uniqueProperties: propertyCounts.count,
      failuresPerProperty: propertyCounts,
      oldestFailure: cachedFailures.min(by: { $0.timestamp < $1.timestamp })?.timestamp,
      newestFailure: cachedFailures.max(by: { $0.timestamp < $1.timestamp })?.timestamp
    )
  }

  // MARK: - Storage

  private var failuresFileURL: URL {
    storageDirectory.appendingPathComponent(Self.failuresFileName)
  }

  private func ensureLoaded() async {
    guard !isLoaded else { return }

    do {
      let data = try Data(contentsOf: failuresFileURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      cachedFailures = try decoder.decode([FailureEntry].self, from: data)
    } catch {
      // File doesn't exist or is corrupted - start fresh
      cachedFailures = []
    }

    isLoaded = true
  }

  private func save() async throws {
    // Ensure directory exists
    try FileManager.default.createDirectory(
      at: storageDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let data = try encoder.encode(cachedFailures)
    try data.write(to: failuresFileURL, options: .atomic)
  }
}

// MARK: - Statistics

/// Statistics about the regression bank.
public struct BankStatistics: Sendable {
  /// Total number of banked failures
  public let totalFailures: Int

  /// Number of unique properties with failures
  public let uniqueProperties: Int

  /// Count of failures per property label
  public let failuresPerProperty: [String: Int]

  /// Timestamp of the oldest failure
  public let oldestFailure: Date?

  /// Timestamp of the newest failure
  public let newestFailure: Date?
}

// MARK: - Integration Helpers

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension RegressionBank {

  /// Convenience method to record a failure from a PropertyResult.
  ///
  /// - Parameters:
  ///   - result: The PropertyResult containing failure information
  ///   - propertyLabel: Label for the property
  public func recordFromResult<T: CustomStringConvertible>(
    _ result: PropertyResult<T>,
    propertyLabel: String
  ) async throws {
    switch result {
    case .failure(_, let iterations, let shrunk, let reason, let seed):
      try await recordFailure(
        propertyLabel: propertyLabel,
        seed: seed,
        counterexample: shrunk,
        reason: reason,
        iteration: iterations
      )

    case .success, .gaveUp:
      break  // Nothing to record
    }
  }
}

// MARK: - Shared Instance

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension RegressionBank {
  /// Shared regression bank instance using default storage location.
  public static let shared = RegressionBank()
}
