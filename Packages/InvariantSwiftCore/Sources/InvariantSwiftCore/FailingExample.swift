/// FailingExample - Data types for persisted test failures
///
/// Part of ISP-0004: Example Database and Reproducible Failures

import Foundation

/// Identifies a specific property test for database lookup.
public struct TestIdentifier: Hashable, Codable, Sendable {
  /// Module containing the test.
  public let module: String

  /// Source file path.
  public let file: String

  /// Function name.
  public let function: String

  /// Signature hash for parameter types.
  public let signature: String

  public init(
    module: String,
    file: String,
    function: String,
    signature: String
  ) {
    self.module = module
    self.file = file
    self.function = function
    self.signature = signature
  }

  /// Creates an identifier from the current source context.
  public init(
    file: StaticString = #file,
    function: StaticString = #function,
    parameterTypes: [Any.Type] = []
  ) {
    module = ""
    self.file = String(describing: file)
    self.function = String(describing: function)
    signature =
      parameterTypes
      .map(String.init(describing:))
      .joined(separator: ",")
  }

  /// Unique key for storage.
  public var storageKey: String {
    [module, file, function, signature].joined(separator: "::")
  }

  /// Directory-safe name for file storage.
  public var directoryName: String {
    function
      .replacingOccurrences(of: "(", with: "_")
      .replacingOccurrences(of: ")", with: "_")
      .replacingOccurrences(of: ":", with: "_")
  }
}

/// Required values describing a property-test failure.
public struct FailingExampleFailure: Sendable {
  public let seed: UInt64
  public let size: Int
  public let message: String

  public init(seed: UInt64, size: Int, message: String) {
    self.seed = seed
    self.size = size
    self.message = message
  }
}

/// Optional reproduction context stored with a failing example.
public struct FailingExampleContext: Sendable {
  public let shrinkPath: [Int]
  public let serializedInput: Data?
  public let inputDescription: String?

  public init(
    shrinkPath: [Int] = [],
    serializedInput: Data? = nil,
    inputDescription: String? = nil
  ) {
    self.shrinkPath = shrinkPath
    self.serializedInput = serializedInput
    self.inputDescription = inputDescription
  }
}

/// Tool versions recorded with a failing example.
public struct FailingExampleVersions: Sendable {
  public let swift: String
  public let framework: String

  public init(
    swift: String = FailingExample.currentSwiftVersion,
    framework: String = FailingExample.currentFrameworkVersion
  ) {
    self.swift = swift
    self.framework = framework
  }
}

/// Persistence metadata assigned to a failing example.
public struct FailingExampleMetadata: Sendable {
  public let id: UUID
  public let timestamp: Date
  public let versions: FailingExampleVersions

  public init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    versions: FailingExampleVersions = .init()
  ) {
    self.id = id
    self.timestamp = timestamp
    self.versions = versions
  }
}

/// A recorded failing example from a property test.
public struct FailingExample: Codable, Sendable, Identifiable {
  public let id: UUID
  public let seed: UInt64
  public let size: Int
  public let shrinkPath: [Int]
  public let serializedInput: Data?
  public let inputDescription: String?
  public let failureMessage: String
  public let timestamp: Date
  public let swiftVersion: String
  public let frameworkVersion: String

  private enum CodingKeys: String, CodingKey {
    case id
    case seed
    case size
    case shrinkPath
    case serializedInput
    case inputDescription
    case failureMessage
    case timestamp
    case swiftVersion
    case frameworkVersion
  }

  public init(
    failure: FailingExampleFailure,
    context: FailingExampleContext = .init(),
    metadata: FailingExampleMetadata = .init()
  ) {
    id = metadata.id
    seed = failure.seed
    size = failure.size
    shrinkPath = context.shrinkPath
    serializedInput = context.serializedInput
    inputDescription = context.inputDescription
    failureMessage = failure.message
    timestamp = metadata.timestamp
    swiftVersion = metadata.versions.swift
    frameworkVersion = metadata.versions.framework
  }

  /// Decodes legacy missing or null shrink paths as empty paths.
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    seed = try values.decode(UInt64.self, forKey: .seed)
    size = try values.decode(Int.self, forKey: .size)
    let context = try Self.decodeContext(from: values)
    shrinkPath = context.shrinkPath
    serializedInput = context.serializedInput
    inputDescription = context.inputDescription
    failureMessage = try values.decode(String.self, forKey: .failureMessage)
    timestamp = try values.decode(Date.self, forKey: .timestamp)
    swiftVersion = try values.decode(String.self, forKey: .swiftVersion)
    frameworkVersion = try values.decode(String.self, forKey: .frameworkVersion)
  }

  private static func decodeContext(
    from values: KeyedDecodingContainer<CodingKeys>
  ) throws -> FailingExampleContext {
    let shrinkPath =
      try values.decodeIfPresent(
        [Int].self,
        forKey: .shrinkPath
      ) ?? []
    let input = try values.decodeIfPresent(Data.self, forKey: .serializedInput)
    let description = try values.decodeIfPresent(
      String.self,
      forKey: .inputDescription
    )
    return FailingExampleContext(
      shrinkPath: shrinkPath,
      serializedInput: input,
      inputDescription: description
    )
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

  /// Shrink path as a reproduction string.
  public var shrinkPathString: String? {
    guard !shrinkPath.isEmpty else { return nil }
    return shrinkPath.map(String.init).joined(separator: ":")
  }

  /// Base64-encoded serialized input.
  public var base64Input: String? {
    serializedInput?.base64EncodedString()
  }

  /// Generates an `@Reproduce` annotation string.
  public func reproduceAnnotation(includePath: Bool = true) -> String {
    var parts = ["seed: 0x\(String(seed, radix: 16, uppercase: true))"]
    parts.append("size: \(size)")
    if includePath, let path = shrinkPathString {
      parts.append("path: \"\(path)\"")
    }
    return "@Reproduce(\(parts.joined(separator: ", ")))"
  }
}
