import Foundation

private enum SourceKittenAvailability: Equatable {
  case unknown
  case available
  case unavailable
}

/// Client for interacting with SourceKitten CLI.
public actor SourceKittenClient {
  /// Shared SourceKitten client.
  public static let shared = SourceKittenClient()

  private var availability: SourceKittenAvailability

  private init() {
    availability = .unknown
  }

  /// Checks whether SourceKitten is installed and available.
  public func isAvailable() async -> Bool {
    if availability == .available { return true }
    if availability == .unavailable { return false }

    let available = await runCommand(["which", "sourcekitten"]).status == 0
    availability = available ? .available : .unavailable
    return available
  }

  /// Analyzes a Swift file and returns its type structure.
  public func analyzeStructure(
    filePath: String
  ) async throws -> SourceKittenStructure? {
    guard await isAvailable() else { return nil }
    let result = await runCommand([
      "sourcekitten",
      "structure",
      "--file",
      filePath,
    ])
    guard result.status == 0, let output = result.output else { return nil }
    guard let data = output.data(using: .utf8) else { return nil }
    return try JSONDecoder().decode(SourceKittenStructure.self, from: data)
  }

  /// Extracts protocol conformances for a named type.
  public func extractConformances(
    typeName: String,
    from structure: SourceKittenStructure
  ) -> [String] {
    Self.extractConformances(typeName: typeName, from: structure.substructure)
  }

  private static func extractConformances(
    typeName: String,
    from items: [SourceKittenItem]
  ) -> [String] {
    for item in items {
      if item.name == typeName {
        return item.inheritedtypes.compactMap(\.name)
      }
      let nested = extractConformances(
        typeName: typeName,
        from: item.substructure
      )
      if !nested.isEmpty { return nested }
    }
    return []
  }

  private func runCommand(
    _ arguments: [String]
  ) async -> (status: Int32, output: String?) {
    #if os(macOS)
    return await withCheckedContinuation { continuation in
      Self.launch(arguments, continuation: continuation)
    }
    #else
    return (-1, nil)
    #endif
  }

  #if os(macOS)
  private static func launch(
    _ arguments: [String],
    continuation: CheckedContinuation<(Int32, String?), Never>
  ) {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
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
  #endif
}

/// Root structure decoded from SourceKitten JSON.
public struct SourceKittenStructure: Codable, Sendable {
  public let diagnosticStage: String?
  public let substructure: [SourceKittenItem]

  init(
    diagnosticStage: String?,
    substructure: [SourceKittenItem]
  ) {
    self.diagnosticStage = diagnosticStage
    self.substructure = substructure
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    diagnosticStage = try values.decodeIfPresent(
      String.self,
      forKey: .diagnosticStage
    )
    substructure =
      try values.decodeIfPresent(
        [SourceKittenItem].self,
        forKey: .substructure
      ) ?? []
  }

  private enum CodingKeys: String, CodingKey {
    case diagnosticStage = "key.diagnostic_stage"
    case substructure = "key.substructure"
  }
}

/// One item decoded from SourceKitten JSON.
public struct SourceKittenItem: Codable, Sendable {
  public let kind: String?
  public let name: String?
  public let nameOffset: Int?
  public let nameLength: Int?
  public let accessibility: String?
  public let inheritedtypes: [InheritedType]
  public let substructure: [Self]

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    kind = try values.decodeIfPresent(String.self, forKey: .kind)
    name = try values.decodeIfPresent(String.self, forKey: .name)
    nameOffset = try values.decodeIfPresent(Int.self, forKey: .nameOffset)
    nameLength = try values.decodeIfPresent(Int.self, forKey: .nameLength)
    accessibility = try values.decodeIfPresent(
      String.self,
      forKey: .accessibility
    )
    inheritedtypes =
      try values.decodeIfPresent(
        [InheritedType].self,
        forKey: .inheritedtypes
      ) ?? []
    substructure =
      try values.decodeIfPresent(
        [Self].self,
        forKey: .substructure
      ) ?? []
  }

  /// Whether this item declares a type.
  public var isTypeDeclaration: Bool {
    guard let kind else { return false }
    let typeKinds = [
      "decl.struct",
      "decl.class",
      "decl.enum",
      "decl.actor",
      "decl.protocol",
    ]
    return typeKinds.contains { kind.contains($0) }
  }

  private enum CodingKeys: String, CodingKey {
    case kind = "key.kind"
    case name = "key.name"
    case nameOffset = "key.nameoffset"
    case nameLength = "key.namelength"
    case accessibility = "key.accessibility"
    case inheritedtypes = "key.inheritedtypes"
    case substructure = "key.substructure"
  }
}

/// One inherited type decoded from SourceKitten JSON.
public struct InheritedType: Codable, Sendable {
  public let name: String?

  private enum CodingKeys: String, CodingKey {
    case name = "key.name"
  }
}
