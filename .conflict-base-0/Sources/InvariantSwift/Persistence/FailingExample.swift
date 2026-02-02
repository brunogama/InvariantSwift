/// FailingExample - Data types for persisted test failures
///
/// Part of ISP-0004: Example Database and Reproducible Failures

import Foundation

// MARK: - Test Identifier

/// Identifies a specific property test for database lookup.
public struct TestIdentifier: Hashable, Codable, Sendable {
  /// Module containing the test
  public let module: String

  /// Source file path
  public let file: String

  /// Function name
  public let function: String

  /// Signature hash for parameter types
  public let signature: String

  public init(module: String, file: String, function: String, signature: String) {
    self.module = module
    self.file = file
    self.function = function
    self.signature = signature
  }

  /// Create from current context
  public init(
    file: StaticString = #file,
    function: StaticString = #function,
    parameterTypes: [Any.Type] = []
  ) {
    self.module = ""  // Will be filled by macro
    self.file = String(describing: file)
    self.function = String(describing: function)
    self.signature = parameterTypes.map { String(describing: $0) }.joined(separator: ",")
  }

  /// Unique key for storage
  public var storageKey: String {
    let components = [module, file, function, signature]
    return components.joined(separator: "::")
  }

  /// Directory-safe name for file storage
  public var directoryName: String {
    let safeName =
      function
      .replacingOccurrences(of: "(", with: "_")
      .replacingOccurrences(of: ")", with: "_")
      .replacingOccurrences(of: ":", with: "_")
    return safeName
  }
}

// MARK: - Failing Example

/// A recorded failing example from a property test.
public struct FailingExample: Codable, Sendable, Identifiable {
  public let id: UUID
  public let seed: UInt64
  public let size: Int
  public let shrinkPath: [Int]?
  public let serializedInput: Data?
  public let inputDescription: String?
  public let failureMessage: String
  public let timestamp: Date
  public let swiftVersion: String
  public let frameworkVersion: String

  public init(
    id: UUID = UUID(),
    seed: UInt64,
    size: Int,
    shrinkPath: [Int]? = nil,
    serializedInput: Data? = nil,
    inputDescription: String? = nil,
    failureMessage: String,
    timestamp: Date = Date(),
    swiftVersion: String = Self.currentSwiftVersion,
    frameworkVersion: String = Self.currentFrameworkVersion
  ) {
    self.id = id
    self.seed = seed
    self.size = size
    self.shrinkPath = shrinkPath
    self.serializedInput = serializedInput
    self.inputDescription = inputDescription
    self.failureMessage = failureMessage
    self.timestamp = timestamp
    self.swiftVersion = swiftVersion
    self.frameworkVersion = frameworkVersion
  }

  public static var currentSwiftVersion: String {
    #if swift(>=6.0)
    return "6.x"
    #elseif swift(>=5.9)
    return "5.9"
    #else
    return "5.x"
    #endif
  }

  public static var currentFrameworkVersion: String { "1.0.0" }

  /// Shrink path as string for reproduction
  public var shrinkPathString: String? {
    shrinkPath.map { $0.map(String.init).joined(separator: ":") }
  }

  /// Base64-encoded serialized input
  public var base64Input: String? {
    serializedInput?.base64EncodedString()
  }

  /// Generate @Reproduce annotation string
  public func reproduceAnnotation(includePath: Bool = true) -> String {
    var parts: [String] = ["seed: 0x\(String(seed, radix: 16, uppercase: true))"]
    parts.append("size: \(size)")
    if includePath, let pathStr = shrinkPathString {
      parts.append("path: \"\(pathStr)\"")
    }
    return "@Reproduce(\(parts.joined(separator: ", ")))"
  }
}

// MARK: - Configuration

/// Global configuration for the failing example database.
public enum FailingExampleConfig {
  /// Maximum examples to store per test
  public static let maxExamplesPerTest: Int = 100

  /// Whether to save examples automatically on failure
  public static let autoSave: Bool = true

  /// Whether to check saved examples before random generation
  public static let checkSavedFirst: Bool = true

  /// Maximum age for examples (prune older ones) - 30 days
  public static let maxAge: TimeInterval? = 30 * 24 * 60 * 60

  /// Whether the database is enabled
  public static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["INVARIANT_EXAMPLES_DISABLED"] == nil
  }

  /// Custom database path from environment
  public static var customPath: URL? {
    ProcessInfo.processInfo.environment["INVARIANT_EXAMPLES_PATH"]
      .map { URL(fileURLWithPath: $0) }
  }

  /// Whether to clear database before run
  public static var shouldClearOnStart: Bool {
    ProcessInfo.processInfo.environment["INVARIANT_CLEAR_EXAMPLES"] != nil
  }

  /// Debug mode
  public static var isDebugMode: Bool {
    ProcessInfo.processInfo.environment["INVARIANT_DEBUG"] != nil
  }
}

// MARK: - URL Extension

extension URL {
  /// Default location: ~/.invariant/examples/
  public static var defaultFailingExampleURL: URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".invariant").appendingPathComponent("examples")
  }
}

// MARK: - Reproduce Report

/// Formatted report with reproduction information for a failing example.
public struct ReproduceReport: CustomStringConvertible, Sendable {
  public let testIdentifier: TestIdentifier
  public let example: FailingExample
  public let originalInput: String?
  public let shrunkInput: String?
  public let shrinkSteps: Int

  public init(
    testIdentifier: TestIdentifier,
    example: FailingExample,
    originalInput: String? = nil,
    shrunkInput: String? = nil,
    shrinkSteps: Int = 0
  ) {
    self.testIdentifier = testIdentifier
    self.example = example
    self.originalInput = originalInput
    self.shrunkInput = shrunkInput
    self.shrinkSteps = shrinkSteps
  }

  public var description: String {
    var lines: [String] = []
    lines.append("❌ Property failed: \(testIdentifier.function)")
    lines.append("")

    if let input = shrunkInput ?? example.inputDescription {
      lines.append("Input: \(input)")
    }
    if let original = originalInput, shrunkInput != nil {
      lines.append("Shrunk from: \(original)")
      lines.append("Shrink steps: \(shrinkSteps)")
    }

    lines.append("")
    lines.append("To reproduce this exact failure, add:")
    lines.append("    \(example.reproduceAnnotation())")

    if let base64 = example.base64Input {
      lines.append("")
      lines.append("Or with serialized input:")
      lines.append("    @Reproduce(input: \"\(base64)\")")
    }

    if FailingExampleConfig.autoSave {
      lines.append("")
      lines.append("Example saved to: \(URL.defaultFailingExampleURL.path)")
    }

    return lines.joined(separator: "\n")
  }
}
