// MARK: - SourceKitten Integration for Accurate Protocol Detection
// Uses SourceKitten CLI to get type information from Swift's type system.

import Foundation

// MARK: - SourceKitten Client

/// Client for interacting with SourceKitten CLI to get accurate type information.
public actor SourceKittenClient {

  /// Singleton for shared access
  public static let shared = SourceKittenClient()

  /// Cached availability check
  private var isAvailableCache: Bool?

  private init() {}

  // MARK: - Availability

  /// Check if SourceKitten is installed and available.
  public func isAvailable() async -> Bool {
    if let cached = isAvailableCache {
      return cached
    }

    let result = await runCommand(["which", "sourcekitten"])
    let available = result.status == 0
    isAvailableCache = available
    return available
  }

  // MARK: - Structure Analysis

  /// Analyze a Swift file and return type structure information.
  public func analyzeStructure(filePath: String) async throws -> SourceKittenStructure? {
    guard await isAvailable() else {
      return nil  // Fall back to regex parsing
    }

    let result = await runCommand([
      "sourcekitten", "structure",
      "--file", filePath,
    ])

    guard result.status == 0, let output = result.output else {
      return nil
    }

    guard let data = output.data(using: .utf8) else {
      return nil
    }

    return try JSONDecoder().decode(SourceKittenStructure.self, from: data)
  }

  /// Extract protocol conformances for a type from SourceKitten output.
  public func extractConformances(
    typeName: String,
    from structure: SourceKittenStructure
  ) -> [String] {
    guard let substructures = structure.substructure else {
      return []
    }

    // Find the type declaration
    for item in substructures {
      if item.name == typeName, let inherited = item.inheritedtypes {
        return inherited.compactMap { $0.name }
      }

      // Recurse into nested structures
      if let nested = item.substructure {
        let nestedStructure = SourceKittenStructure(
          diagnosticStage: nil,
          substructure: nested
        )
        let result = extractConformances(typeName: typeName, from: nestedStructure)
        if !result.isEmpty {
          return result
        }
      }
    }

    return []
  }

  // MARK: - Command Execution

  private func runCommand(_ args: [String]) async -> (status: Int32, output: String?) {
    await withCheckedContinuation { continuation in
      let process = Process()
      let pipe = Pipe()

      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = args
      process.standardOutput = pipe
      process.standardError = FileHandle.nullDevice

      do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        continuation.resume(returning: (process.terminationStatus, output))
      } catch {
        continuation.resume(returning: (-1, nil))
      }
    }
  }
}

// MARK: - SourceKitten JSON Models

/// Root structure from SourceKitten JSON output.
public struct SourceKittenStructure: Codable, Sendable {
  public let diagnosticStage: String?
  public let substructure: [SourceKittenItem]?

  enum CodingKeys: String, CodingKey {
    case diagnosticStage = "key.diagnostic_stage"
    case substructure = "key.substructure"
  }
}

/// Individual item in SourceKitten structure.
public struct SourceKittenItem: Codable, Sendable {
  public let kind: String?
  public let name: String?
  public let nameOffset: Int?
  public let nameLength: Int?
  public let accessibility: String?
  public let inheritedtypes: [InheritedType]?
  public let substructure: [SourceKittenItem]?

  enum CodingKeys: String, CodingKey {
    case kind = "key.kind"
    case name = "key.name"
    case nameOffset = "key.nameoffset"
    case nameLength = "key.namelength"
    case accessibility = "key.accessibility"
    case inheritedtypes = "key.inheritedtypes"
    case substructure = "key.substructure"
  }

  /// Check if this is a type declaration (struct, class, enum, actor).
  public var isTypeDeclaration: Bool {
    guard let kind = kind else { return false }
    return kind.contains("decl.struct")
      || kind.contains("decl.class")
      || kind.contains("decl.enum")
      || kind.contains("decl.actor")
      || kind.contains("decl.protocol")
  }
}

/// Inherited type from SourceKitten.
public struct InheritedType: Codable, Sendable {
  public let name: String?

  enum CodingKeys: String, CodingKey {
    case name = "key.name"
  }
}

// MARK: - Protocol Conformance Mapping

/// Maps SourceKitten protocol names to Ghostwriter ProtocolConformance.
public enum ProtocolConformanceMapper {

  /// Map a protocol name to ProtocolConformance if applicable.
  public static func map(_ protocolName: String) -> ProtocolConformance? {
    switch protocolName {
    case "Equatable":
      return .equatable
    case "Hashable":
      return .hashable
    case "Comparable":
      return .comparable
    case "Codable", "Encodable", "Decodable":
      return .codable
    case "Sendable":
      return .sendable
    case "Collection", "Sequence", "RandomAccessCollection":
      return .collection
    case "Identifiable":
      return .identifiable
    default:
      return nil
    }
  }

  /// Map an array of protocol names to ProtocolConformances.
  public static func mapAll(_ protocolNames: [String]) -> [ProtocolConformance] {
    protocolNames.compactMap(map)
  }
}
