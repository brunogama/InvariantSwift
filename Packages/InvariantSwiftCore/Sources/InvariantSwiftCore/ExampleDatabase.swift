/// Persistent storage for failing test examples.
///
/// Part of ISP-0004: Example Database and Reproducible Failures

import Foundation

/// Global configuration for the failing example database.
public enum FailingExampleConfig {
  public static let maxExamplesPerTest = 100
  public static let autoSave = true
  public static let checkSavedFirst = true
  public static let maxAge: TimeInterval? = 30 * 24 * 60 * 60

  public static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["INVARIANT_EXAMPLES_DISABLED"] == nil
  }

  public static var customPath: URL? {
    ProcessInfo.processInfo.environment["INVARIANT_EXAMPLES_PATH"]
      .map(URL.init(fileURLWithPath:))
  }

  public static var shouldClearOnStart: Bool {
    ProcessInfo.processInfo.environment["INVARIANT_CLEAR_EXAMPLES"] != nil
  }

  public static var isDebugMode: Bool {
    ProcessInfo.processInfo.environment["INVARIANT_DEBUG"] != nil
  }
}

extension URL {
  /// Default location for persisted failing examples.
  public static var defaultFailingExampleURL: URL {
    #if os(macOS)
    let baseURL = FileManager.default.homeDirectoryForCurrentUser
    #else
    let baseURL =
      FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    #endif
    return
      baseURL
      .appendingPathComponent(".invariant")
      .appendingPathComponent("examples")
  }
}

/// Persistent storage for failing test examples.
public actor FailingExampleDatabase {
  /// Shared instance using default configuration.
  public static let shared = FailingExampleDatabase()

  /// Storage backend options.
  public enum Backend: Sendable {
    /// JSON files in a directory.
    case directory(URL)

    /// In-memory storage for testing.
    case memory

    /// Disabled storage.
    case none

    /// Default storage backend.
    public static var `default`: Backend {
      guard FailingExampleConfig.isEnabled else { return .none }
      if let path = FailingExampleConfig.customPath {
        return .directory(path)
      }
      return .directory(.defaultFailingExampleURL)
    }
  }

  /// Storage backend.
  public let backend: Backend

  private var cache: [String: [FailingExample]] = [:]
  private var isDirty = false

  public init(backend: Backend = .default) {
    self.backend = backend
  }

  /// Saves a failing example for a test.
  public func save(testID: TestIdentifier, example: FailingExample) async {
    if case .memory = backend {
      append(example, for: testID)
      return
    }
    guard case .directory = backend else { return }

    append(example, for: testID)
    limitExamples(for: testID)
    isDirty = true
    await flush(testID: testID)
  }

  /// Retrieves all known failing examples for a test.
  public func examples(for testID: TestIdentifier) async -> [FailingExample] {
    if let cached = cache[testID.storageKey] {
      return cached
    }
    guard case .directory(let baseURL) = backend else { return [] }

    let examples = FailingExampleDiskStore.load(testID: testID, from: baseURL)
    cache[testID.storageKey] = examples
    return examples
  }

  /// Removes a fixed example from the database.
  public func markFixed(
    testID: TestIdentifier,
    example: FailingExample
  ) async {
    var examples = cache[testID.storageKey] ?? []
    examples.removeAll { $0.id == example.id }
    cache[testID.storageKey] = examples
    isDirty = true
    await flush(testID: testID)
  }

  /// Clears all examples for a test.
  public func clear(testID: TestIdentifier) async {
    cache[testID.storageKey] = []
    isDirty = true
    guard case .directory(let baseURL) = backend else { return }

    let testDirectory = baseURL.appendingPathComponent(testID.directoryName)
    try? FileManager.default.removeItem(at: testDirectory)
  }

  /// Clears the entire database.
  public func clearAll() async {
    cache = [:]
    guard case .directory(let baseURL) = backend else { return }

    try? FileManager.default.removeItem(at: baseURL)
    try? FileManager.default.createDirectory(
      at: baseURL,
      withIntermediateDirectories: true
    )
  }

  /// Returns statistics about the database.
  public func statistics() -> FailingExampleStatistics {
    let exampleCount = cache.values.reduce(0) { $0 + $1.count }
    return FailingExampleStatistics(
      testCount: cache.count,
      exampleCount: exampleCount,
      backend: backendDescription
    )
  }

  private func append(_ example: FailingExample, for testID: TestIdentifier) {
    cache[testID.storageKey, default: []].append(example)
  }

  private func limitExamples(for testID: TestIdentifier) {
    let examples = cache[testID.storageKey] ?? []
    let limit = FailingExampleConfig.maxExamplesPerTest
    guard examples.count > limit else { return }
    cache[testID.storageKey] = Array(examples.suffix(limit))
  }

  private func flush(testID: TestIdentifier) async {
    guard case .directory(let baseURL) = backend else { return }
    let examples = cache[testID.storageKey] ?? []
    FailingExampleDiskStore.write(examples, testID: testID, to: baseURL)
    isDirty = false
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

private struct FailingExampleDiskEntry {
  let example: FailingExample
  let index: Int
  let directory: URL
}

enum FailingExampleDiskStore {
  static func write(
    _ examples: [FailingExample],
    testID: TestIdentifier,
    to baseURL: URL
  ) {
    let directory = baseURL.appendingPathComponent(testID.directoryName)
    prepare(directory)
    let encoder = makeEncoder()
    for (index, example) in examples.enumerated() {
      let entry = FailingExampleDiskEntry(
        example: example,
        index: index,
        directory: directory
      )
      write(entry, encoder: encoder)
    }
  }

  static func load(
    testID: TestIdentifier,
    from baseURL: URL
  ) -> [FailingExample] {
    let directory = baseURL.appendingPathComponent(testID.directoryName)
    let decoder = makeDecoder()
    return contents(of: directory).compactMap { load($0, decoder: decoder) }
  }

  private static func prepare(_ directory: URL) {
    try? FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    for file in contents(of: directory) {
      try? FileManager.default.removeItem(at: file)
    }
  }

  private static func contents(of directory: URL) -> [URL] {
    let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )
    return files?.sorted {
      $0.lastPathComponent < $1.lastPathComponent
    } ?? []
  }

  private static func write(
    _ entry: FailingExampleDiskEntry,
    encoder: JSONEncoder
  ) {
    guard let data = try? encoder.encode(entry.example) else { return }
    let name = String(format: "example_%03d.json", entry.index + 1)
    try? data.write(to: entry.directory.appendingPathComponent(name))
  }

  private static func load(
    _ file: URL,
    decoder: JSONDecoder
  ) -> FailingExample? {
    guard file.pathExtension == "json" else { return nil }
    guard let data = try? Data(contentsOf: file) else { return nil }
    guard
      let example = try? decoder.decode(FailingExample.self, from: data)
    else {
      return nil
    }
    guard isCurrent(example) else {
      try? FileManager.default.removeItem(at: file)
      return nil
    }
    return example
  }

  private static func isCurrent(_ example: FailingExample) -> Bool {
    guard let maxAge = FailingExampleConfig.maxAge else { return true }
    return Date().timeIntervalSince(example.timestamp) <= maxAge
  }

  private static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

/// Statistics about the example database.
public struct FailingExampleStatistics: Sendable {
  public let testCount: Int
  public let exampleCount: Int
  public let backend: String
}
