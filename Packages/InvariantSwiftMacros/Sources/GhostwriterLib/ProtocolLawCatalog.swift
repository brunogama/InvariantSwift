// MARK: - Protocol Law Catalog

/// A stable identifier for a law independent of its human-readable statement.
public struct ProtocolLawID: RawRepresentable, Hashable, Codable, Sendable,
  ExpressibleByStringLiteral
{
  /// The stable catalog key.
  public let rawValue: String

  /// Creates an identifier from its stable catalog key.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Creates an identifier from a string literal.
  public init(stringLiteral value: String) {
    self.init(rawValue: value)
  }
}

/// The identifier used by the test generator for an implemented law pattern.
public struct ProtocolLawPatternID: RawRepresentable, Hashable, Codable, Sendable,
  ExpressibleByStringLiteral
{
  /// The matching `GhostwriterTestPattern` raw value.
  public let rawValue: String

  /// Creates a pattern identifier from its raw value.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Creates a pattern identifier from a string literal.
  public init(stringLiteral value: String) {
    self.init(rawValue: value)
  }
}

/// A test capability needed to express or evaluate a law.
public struct ProtocolLawCapability: RawRepresentable, Hashable, Codable, Sendable,
  ExpressibleByStringLiteral
{
  /// The capability description.
  public let rawValue: String

  /// Creates a capability from its description.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Creates a capability from a string literal.
  public init(stringLiteral value: String) {
    self.init(rawValue: value)
  }
}

/// The module that declares a cataloged protocol or protocol-like surface.
public struct ProtocolLawModule: RawRepresentable, Hashable, Codable, Sendable,
  ExpressibleByStringLiteral
{
  /// The declaring module name.
  public let rawValue: String

  /// Creates a module value from its name.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Creates a module value from a string literal.
  public init(stringLiteral value: String) {
    self.init(rawValue: value)
  }
}

/// The catalog priority supplied for a protocol law suite.
public enum ProtocolLawTier: Int, CaseIterable, Codable, Sendable {
  case one = 1
  case two = 2
  case three = 3
}

/// One law and its optional implemented Ghostwriter pattern.
public struct ProtocolLawCatalogLaw: Hashable, Codable, Sendable {
  /// The law's stable identifier.
  public let id: ProtocolLawID
  /// The human-readable law statement.
  public let statement: String
  /// The generator pattern that implements this law, when one exists.
  public let patternIdentifier: ProtocolLawPatternID?

  /// Creates a catalog law.
  public init(
    id: ProtocolLawID,
    statement: String,
    patternIdentifier: ProtocolLawPatternID? = nil
  ) {
    self.id = id
    self.statement = statement
    self.patternIdentifier = patternIdentifier
  }
}

/// The laws and generation requirements associated with one catalog surface.
public struct ProtocolLawCatalogEntry: Hashable, Codable, Sendable {
  /// The display name from the catalog source.
  public let protocolName: String
  /// The exact conformance names that select this entry.
  public let conformanceNames: [String]
  /// The module that declares the surface.
  public let module: ProtocolLawModule
  /// The catalog priority.
  public let tier: ProtocolLawTier
  /// The laws associated with the surface.
  public let laws: [ProtocolLawCatalogLaw]
  /// The harness capabilities needed by the laws.
  public let capabilities: [ProtocolLawCapability]
  /// Constraints and generation guidance for the suite.
  public let notes: String

  /// Creates a catalog entry.
  public init(
    protocolName: String,
    conformanceNames: [String],
    module: ProtocolLawModule,
    tier: ProtocolLawTier,
    laws: [ProtocolLawCatalogLaw],
    capabilities: [ProtocolLawCapability],
    notes: String
  ) {
    self.protocolName = protocolName
    self.conformanceNames = conformanceNames
    self.module = module
    self.tier = tier
    self.laws = laws
    self.capabilities = capabilities
    self.notes = notes
  }
}

/// Discoverable metadata for protocol and protocol-like mathematical laws.
public enum ProtocolLawCatalog {
  /// Every protocol and protocol-like surface in catalog order.
  public static let all: [ProtocolLawCatalogEntry] =
    swiftValueEntries
    + swiftValueRoundtripEntries
    + swiftCollectionEntries
    + swiftRuntimeEntries
    + concurrencyEntries
    + numericsEntries
    + foundationEntries
    + swiftUIEntries
    + appleFrameworkEntries

  /// Returns entries selected by a case-sensitive conformance name.
  public static func entries(forConformance exactName: String) -> [ProtocolLawCatalogEntry] {
    entriesByConformance[exactName] ?? []
  }

  /// Returns the law with the stable identifier, when present.
  public static func law(id: ProtocolLawID) -> ProtocolLawCatalogLaw? {
    all.lazy.flatMap(\.laws).first { $0.id == id }
  }

  private static let entriesByConformance: [String: [ProtocolLawCatalogEntry]] = {
    let pairs = all.flatMap { entry in
      entry.conformanceNames.map { ($0, entry) }
    }
    return Dictionary(grouping: pairs, by: \.0).mapValues { pairs in
      pairs.map(\.1)
    }
  }()
}

extension ProtocolLawCatalog {
  static func entry(
    _ protocolName: String,
    conformances: [String] = [],
    module: ProtocolLawModule = "Swift",
    tier: ProtocolLawTier,
    laws: [ProtocolLawCatalogLaw],
    capabilities: [ProtocolLawCapability],
    notes: String = ""
  ) -> ProtocolLawCatalogEntry {
    ProtocolLawCatalogEntry(
      protocolName: protocolName,
      conformanceNames: conformances.isEmpty ? [protocolName] : conformances,
      module: module,
      tier: tier,
      laws: laws,
      capabilities: capabilities,
      notes: notes
    )
  }

  static func law(
    _ id: ProtocolLawID,
    _ statement: String,
    pattern: ProtocolLawPatternID? = nil
  ) -> ProtocolLawCatalogLaw {
    ProtocolLawCatalogLaw(id: id, statement: statement, patternIdentifier: pattern)
  }
}
