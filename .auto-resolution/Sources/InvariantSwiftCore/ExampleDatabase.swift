/// FailingExampleDatabase - Persistent storage for failing test examples
///
/// Part of ISP-0004: Example Database and Reproducible Failures

import Foundation

// MARK: - Failing Example Database

/// Persistent storage for failing test examples.
///
/// Automatically saves failing test cases and replays them on subsequent runs
/// to ensure regressions are caught immediately.
///
/// **Usage:**
/// ```swift
/// // Save a failing example
/// await FailingExampleDatabase.shared.save(testID: id, example: failure)
///
/// // Check saved examples first
/// let saved = await FailingExampleDatabase.shared.examples(for: id)
/// for example in saved {
///     if testStillFails(example) { /* report */ }
///     else { await FailingExampleDatabase.shared.markFixed(testID: id, example: example) }
/// }
/// ```
public actor FailingExampleDatabase {

  /// Shared instance using default configuration
  public static let shared = FailingExampleDatabase()

  /// Storage backend
  public let backend: Backend

  /// In-memory cache of examples
  private var cache: [String: [FailingExample]] = [:]

  /// Whether cache is dirty and needs flush
  private var isDirty = false

  // MARK: - Backend

  /// Storage backend options
  public enum Backend: Sendable {
    /// JSON files in a directory (git-friendly)
    case directory(URL)

    /// In-memory only (for testing)
    case memory

    /// Disabled
    case none

    /// Default backend
    public static var `default`: Backend {
      if !FailingExampleConfig.isEnabled {
        return .none
      }
      if let customPath = FailingExampleConfig.customPath {
        return .directory(customPath)
      }
      return .directory(.defaultFailingExampleURL)
    }
  }

  // MARK: - Initialization

  public init(backend: Backend = .default) {
    self.backend = backend
  }

  // MARK: - Public API

  /// Save a failing example for a test
  public func save(testID: TestIdentifier, example: FailingExample) async {
    guard case .directory = backend else {
      if case .memory = backend {
        var examples = cache[testID.storageKey] ?? []
        examples.append(example)
        cache[testID.storageKey] = examples
      }
      return
    }

    var examples = cache[testID.storageKey] ?? []
    examples.append(example)

    // Enforce max limit
    let maxExamples = FailingExampleConfig.maxExamplesPerTest
    if examples.count > maxExamples {
      examples = Array(examples.suffix(maxExamples))
    }

    cache[testID.storageKey] = examples
    isDirty = true

    // Write to disk
    await flush(testID: testID)
  }

  /// Retrieve all known failing examples for a test
  public func examples(for testID: TestIdentifier) async -> [FailingExample] {
    // Check cache first
    if let cached = cache[testID.storageKey] {
      return cached
    }

    // Load from disk
    guard case .directory(let url) = backend else {
      return []
    }

    let examples = loadFromDisk(testID: testID, baseURL: url)
    cache[testID.storageKey] = examples
    return examples
  }

  /// Mark an example as fixed (remove from database)
  public func markFixed(testID: TestIdentifier, example: FailingExample) async {
    var examples = cache[testID.storageKey] ?? []
    examples.removeAll { $0.id == example.id }
    cache[testID.storageKey] = examples
    isDirty = true

    await flush(testID: testID)
  }

  /// Clear all examples for a test
  public func clear(testID: TestIdentifier) async {
    cache[testID.storageKey] = []
    isDirty = true

    guard case .directory(let url) = backend else { return }

    let testDir = url.appendingPathComponent(testID.directoryName)
    try? FileManager.default.removeItem(at: testDir)
  }

  /// Clear entire database
  public func clearAll() async {
    cache = [:]

    guard case .directory(let url) = backend else { return }

    try? FileManager.default.removeItem(at: url)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  /// Get statistics about the database
  public func statistics() -> FailingExampleStatistics {
    let totalExamples = cache.values.reduce(0) { $0 + $1.count }
    return FailingExampleStatistics(
      testCount: cache.count,
      exampleCount: totalExamples,
      backend: backendDescription
    )
  }

  // MARK: - Private Methods

  private func flush(testID: TestIdentifier) async {
    guard case .directory(let baseURL) = backend else { return }

    let examples = cache[testID.storageKey] ?? []
    let testDir = baseURL.appendingPathComponent(testID.directoryName)

    // Ensure directory exists
    try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

    // Remove existing files
    let existingFiles = try? FileManager.default.contentsOfDirectory(
      at: testDir,
      includingPropertiesForKeys: nil
    )
    for file in existingFiles ?? [] {
      try? FileManager.default.removeItem(at: file)
    }

    // Write each example
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    for (index, example) in examples.enumerated() {
      let filename = String(format: "example_%03d.json", index + 1)
      let fileURL = testDir.appendingPathComponent(filename)

      if let data = try? encoder.encode(example) {
        try? data.write(to: fileURL)
      }
    }

    isDirty = false
  }

  private func loadFromDisk(testID: TestIdentifier, baseURL: URL) -> [FailingExample] {
    let testDir = baseURL.appendingPathComponent(testID.directoryName)

    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: testDir,
        includingPropertiesForKeys: nil
      )
    else {
      return []
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    var examples: [FailingExample] = []
    let maxAge = FailingExampleConfig.maxAge

    for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      guard file.pathExtension == "json" else { continue }
      guard let data = try? Data(contentsOf: file) else { continue }
      guard let example = try? decoder.decode(FailingExample.self, from: data) else { continue }

      // Check age
      if let maxAge = maxAge {
        let age = Date().timeIntervalSince(example.timestamp)
        if age > maxAge {
          try? FileManager.default.removeItem(at: file)
          continue
        }
      }

      examples.append(example)
    }

    return examples
  }

  private var backendDescription: String {
    switch backend {
    case .directory(let url):
      return "directory: \(url.path)"

    case .memory:
      return "memory"

    case .none:
      return "disabled"
    }
  }
}

// MARK: - Statistics

/// Statistics about the example database
public struct FailingExampleStatistics: Sendable {
  public let testCount: Int
  public let exampleCount: Int
  public let backend: String
}

// MARK: - Convenience Extension

extension FailingExampleDatabase {
  /// Save a failure with all metadata
  public func saveFailure(
    testID: TestIdentifier,
    seed: UInt64,
    size: Int,
    shrinkPath: [Int]? = nil,
    input: (any Codable & Sendable)? = nil,
    inputDescription: String? = nil,
    failureMessage: String
  ) async {
    let serializedInput: Data?
    if let input = input {
      serializedInput = try? JSONEncoder().encode(AnyEncodable(input))
    } else {
      serializedInput = nil
    }

    let example = FailingExample(
      seed: seed,
      size: size,
      shrinkPath: shrinkPath,
      serializedInput: serializedInput,
      inputDescription: inputDescription,
      failureMessage: failureMessage
    )

    await save(testID: testID, example: example)
  }
}

// MARK: - Type Erasure for Encoding

private struct AnyEncodable: Encodable {
  private let encode: (Encoder) throws -> Void

  init<T: Encodable>(_ value: T) {
    self.encode = { encoder in
      try value.encode(to: encoder)
    }
  }

  func encode(to encoder: Encoder) throws {
    try encode(encoder)
  }
}
