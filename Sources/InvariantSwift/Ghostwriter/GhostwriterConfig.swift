// MARK: - ISP-0009: Ghostwriter Configuration Types
// Configuration and type definitions for automatic test generation.

import Foundation

// MARK: - Test Patterns

/// Available test patterns that Ghostwriter can detect and generate.
public enum TestPattern: String, CaseIterable, Sendable {
  /// Codable roundtrip: encode then decode equals original
  case codableRoundtrip = "codable_roundtrip"

  /// Equatable reflexive: x == x
  case equatableReflexive = "equatable_reflexive"

  /// Equatable symmetric: x == y implies y == x
  case equatableSymmetric = "equatable_symmetric"

  /// Equatable transitive: x == y && y == z implies x == z
  case equatableTransitive = "equatable_transitive"

  /// Hashable consistency: x == y implies x.hashValue == y.hashValue
  case hashableConsistency = "hashable_consistency"

  /// Comparable irreflexive: !(x < x)
  case comparableIrreflexive = "comparable_irreflexive"

  /// Comparable asymmetric: x < y implies !(y < x)
  case comparableAsymmetric = "comparable_asymmetric"

  /// Comparable transitive: x < y && y < z implies x < z
  case comparableTransitive = "comparable_transitive"

  /// Comparable trichotomy: exactly one of <, ==, > holds
  case comparableTrichotomy = "comparable_trichotomy"

  /// Idempotent function: f(f(x)) == f(x)
  case idempotent = "idempotent"

  /// Inverse functions: decode(encode(x)) == x
  case inverseFunctions = "inverse_functions"

  /// Collection count matches iteration
  case collectionCount = "collection_count"

  /// Collection indices are valid
  case collectionIndices = "collection_indices"

  /// Human-readable description of the pattern
  public var description: String {
    switch self {
    case .codableRoundtrip:
      return "Codable encode/decode roundtrip preserves value"
    case .equatableReflexive:
      return "Equatable reflexivity: x == x"
    case .equatableSymmetric:
      return "Equatable symmetry: x == y implies y == x"
    case .equatableTransitive:
      return "Equatable transitivity: x == y && y == z implies x == z"
    case .hashableConsistency:
      return "Hashable consistency: equal values have equal hashes"
    case .comparableIrreflexive:
      return "Comparable irreflexivity: !(x < x)"
    case .comparableAsymmetric:
      return "Comparable asymmetry: x < y implies !(y < x)"
    case .comparableTransitive:
      return "Comparable transitivity: x < y && y < z implies x < z"
    case .comparableTrichotomy:
      return "Comparable trichotomy: exactly one of <, ==, > holds"
    case .idempotent:
      return "Idempotent: f(f(x)) == f(x)"
    case .inverseFunctions:
      return "Inverse functions: decode(encode(x)) == x"
    case .collectionCount:
      return "Collection count matches iteration count"
    case .collectionIndices:
      return "Collection indices are all valid"
    }
  }

  /// Patterns that apply to Equatable types
  public static var equatableLaws: [TestPattern] {
    [.equatableReflexive, .equatableSymmetric, .equatableTransitive]
  }

  /// Patterns that apply to Comparable types
  public static var comparableLaws: [TestPattern] {
    [.comparableIrreflexive, .comparableAsymmetric, .comparableTransitive, .comparableTrichotomy]
  }
}

// MARK: - Ghostwriter Configuration

/// Configuration for the Ghostwriter test generator.
public struct GhostwriterConfig: Sendable {
  /// Source files or directories to analyze
  public let sources: [String]

  /// Output directory for generated tests
  public let outputDirectory: String

  /// Patterns to generate (empty = all applicable)
  public let patterns: [TestPattern]

  /// File patterns to exclude
  public let excludePatterns: [String]

  /// Whether to perform a dry run (preview without writing)
  public let dryRun: Bool

  /// Whether to show verbose output
  public let verbose: Bool

  /// Whether to force regeneration even if up-to-date
  public let force: Bool

  /// Test function name prefix
  public let testPrefix: String

  /// Test file name suffix
  public let testSuffix: String

  public init(
    sources: [String],
    outputDirectory: String = "Tests/Generated/",
    patterns: [TestPattern] = [],
    excludePatterns: [String] = [],
    dryRun: Bool = false,
    verbose: Bool = false,
    force: Bool = false,
    testPrefix: String = "test",
    testSuffix: String = "PropertyTests"
  ) {
    self.sources = sources
    self.outputDirectory = outputDirectory
    self.patterns = patterns
    self.excludePatterns = excludePatterns
    self.dryRun = dryRun
    self.verbose = verbose
    self.force = force
    self.testPrefix = testPrefix
    self.testSuffix = testSuffix
  }

  /// Default configuration
  public static let `default` = GhostwriterConfig(sources: [])
}

// MARK: - Generated Test Info

/// Information about a generated test.
public struct GeneratedTest: Sendable, Codable {
  /// Name of the test function
  public let name: String

  /// Source file the test was generated from
  public let sourceFile: String

  /// Line number in source file
  public let sourceLine: Int

  /// Type being tested
  public let typeName: String

  /// Pattern used to generate the test
  public let pattern: String

  /// The generated test code
  public let code: String

  public init(
    name: String,
    sourceFile: String,
    sourceLine: Int,
    typeName: String,
    pattern: String,
    code: String
  ) {
    self.name = name
    self.sourceFile = sourceFile
    self.sourceLine = sourceLine
    self.typeName = typeName
    self.pattern = pattern
    self.code = code
  }
}

// MARK: - Ghostwriter Manifest

/// Manifest tracking generated tests for incremental regeneration.
public struct GhostwriterManifest: Sendable, Codable {
  /// Manifest format version
  public let version: String

  /// When the tests were last generated
  public let generatedAt: Date

  /// Hash of source files for change detection
  public let sourceHash: String

  /// List of generated tests
  public let tests: [GeneratedTest]

  public init(
    version: String = "1.0",
    generatedAt: Date = Date(),
    sourceHash: String,
    tests: [GeneratedTest]
  ) {
    self.version = version
    self.generatedAt = generatedAt
    self.sourceHash = sourceHash
    self.tests = tests
  }

  /// Load manifest from file
  public static func load(from url: URL) throws -> GhostwriterManifest {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(GhostwriterManifest.self, from: data)
  }

  /// Save manifest to file
  public func save(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    try data.write(to: url)
  }
}

// MARK: - Ghostwriter Result

/// Result of running the Ghostwriter.
public struct GhostwriterResult: Sendable {
  /// Files that were analyzed
  public let analyzedFiles: [String]

  /// Types that were found
  public let discoveredTypes: [TypeInfo]

  /// Tests that were generated
  public let generatedTests: [GeneratedTest]

  /// Errors encountered during analysis
  public let errors: [GhostwriterError]

  /// Whether the generation was successful
  public var isSuccess: Bool {
    errors.isEmpty
  }

  /// Summary of generation
  public var summary: String {
    """
    Analyzed \(analyzedFiles.count) file(s)
    Discovered \(discoveredTypes.count) type(s)
    Generated \(generatedTests.count) test(s)
    Errors: \(errors.count)
    """
  }
}

// MARK: - Ghostwriter Errors

/// Errors that can occur during ghostwriting.
public enum GhostwriterError: Error, Sendable, CustomStringConvertible {
  case fileNotFound(String)
  case parseError(file: String, message: String)
  case noTypesFound(String)
  case writeError(file: String, message: String)
  case configurationError(String)

  public var description: String {
    switch self {
    case .fileNotFound(let path):
      return "File not found: \(path)"
    case .parseError(let file, let message):
      return "Parse error in \(file): \(message)"
    case .noTypesFound(let path):
      return "No types found in: \(path)"
    case .writeError(let file, let message):
      return "Write error for \(file): \(message)"
    case .configurationError(let message):
      return "Configuration error: \(message)"
    }
  }
}
