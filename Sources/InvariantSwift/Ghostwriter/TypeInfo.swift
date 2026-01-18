// MARK: - ISP-0009: Type Information
// Extracted type information from source code analysis.

import Foundation

// MARK: - Protocol Conformance

/// Known protocol conformances that trigger test generation.
public enum ProtocolConformance: String, CaseIterable, Sendable {
  case codable = "Codable"
  case decodable = "Decodable"
  case encodable = "Encodable"
  case equatable = "Equatable"
  case hashable = "Hashable"
  case comparable = "Comparable"
  case collection = "Collection"
  case bidirectionalCollection = "BidirectionalCollection"
  case randomAccessCollection = "RandomAccessCollection"
  case rangeReplaceableCollection = "RangeReplaceableCollection"
  case mutableCollection = "MutableCollection"
  case sequence = "Sequence"
  case identifiable = "Identifiable"
  case rawRepresentable = "RawRepresentable"
  case numeric = "Numeric"
  case signedNumeric = "SignedNumeric"
  case additiveArithmetic = "AdditiveArithmetic"
  case strideable = "Strideable"
  case sendable = "Sendable"

  /// Test patterns applicable to this protocol
  public var applicablePatterns: [TestPattern] {
    switch self {
    case .codable:
      return [.codableRoundtrip]
    case .decodable:
      return []
    case .encodable:
      return []
    case .equatable:
      return TestPattern.equatableLaws
    case .hashable:
      return [.hashableConsistency] + TestPattern.equatableLaws
    case .comparable:
      return TestPattern.comparableLaws
    case .collection:
      return TestPattern.collectionLaws
    case .bidirectionalCollection:
      return TestPattern.collectionLaws + [.bidirectionalSymmetry]
    case .randomAccessCollection:
      return TestPattern.collectionLaws
    case .rangeReplaceableCollection:
      return TestPattern.collectionLaws
    case .mutableCollection:
      return TestPattern.collectionLaws
    case .sequence:
      return [.sequenceIteration]
    case .identifiable:
      return [.identifiableStability]
    case .rawRepresentable:
      return [.rawRepresentableRoundtrip]
    case .numeric:
      return TestPattern.numericLaws
    case .signedNumeric:
      return TestPattern.numericLaws
    case .additiveArithmetic:
      return [.additiveArithmeticZero, .numericCommutativity, .numericAssociativity]
    case .strideable:
      return []
    case .sendable:
      return []  // Sendable is checked by compiler
    }
  }
}

// MARK: - Type Kind

/// The kind of Swift type.
public enum TypeKind: String, Sendable {
  case structType = "struct"
  case classType = "class"
  case enumType = "enum"
  case actorType = "actor"
  case protocolType = "protocol"
}

// MARK: - Property Info

/// Information about a type's property.
public struct PropertyInfo: Sendable {
  /// Property name
  public let name: String

  /// Property type as string
  public let typeName: String

  /// Whether the property is optional
  public let isOptional: Bool

  /// Whether the property is mutable (var vs let)
  public let isMutable: Bool

  /// Whether the property has a default value
  public let hasDefaultValue: Bool

  public init(
    name: String,
    typeName: String,
    isOptional: Bool = false,
    isMutable: Bool = false,
    hasDefaultValue: Bool = false
  ) {
    self.name = name
    self.typeName = typeName
    self.isOptional = isOptional
    self.isMutable = isMutable
    self.hasDefaultValue = hasDefaultValue
  }
}

// MARK: - Method Info

/// Information about a type's method.
public struct MethodInfo: Sendable {
  /// Method name
  public let name: String

  /// Parameter types
  public let parameters: [(label: String?, type: String)]

  /// Return type (nil for Void)
  public let returnType: String?

  /// Whether the method is static
  public let isStatic: Bool

  /// Whether the method is mutating
  public let isMutating: Bool

  /// Whether the method throws
  public let isThrowing: Bool

  /// Whether the method is async
  public let isAsync: Bool

  public init(
    name: String,
    parameters: [(label: String?, type: String)] = [],
    returnType: String? = nil,
    isStatic: Bool = false,
    isMutating: Bool = false,
    isThrowing: Bool = false,
    isAsync: Bool = false
  ) {
    self.name = name
    self.parameters = parameters
    self.returnType = returnType
    self.isStatic = isStatic
    self.isMutating = isMutating
    self.isThrowing = isThrowing
    self.isAsync = isAsync
  }

  /// Check if this method might be idempotent based on naming
  public var looksIdempotent: Bool {
    let idempotentNames = [
      "normalize", "normalized",
      "clean", "cleaned",
      "trim", "trimmed",
      "sanitize", "sanitized",
      "format", "formatted",
      "compact", "compacted",
      "canonical", "canonicalized",
    ]
    return idempotentNames.contains { name.lowercased().contains($0) }
  }

  /// Check if this method might be an encoder
  public var looksLikeEncoder: Bool {
    let encoderNames = ["encode", "encrypt", "compress", "serialize", "pack"]
    return encoderNames.contains { name.lowercased().contains($0) }
  }

  /// Check if this method might be a decoder
  public var looksLikeDecoder: Bool {
    let decoderNames = ["decode", "decrypt", "decompress", "deserialize", "unpack"]
    return decoderNames.contains { name.lowercased().contains($0) }
  }
}

// MARK: - Type Info

/// Complete information about a Swift type extracted from source code.
public struct TypeInfo: Sendable {
  /// Name of the type
  public let name: String

  /// Kind of type (struct, class, enum, etc.)
  public let kind: TypeKind

  /// Source file path
  public let sourceFile: String

  /// Line number where type is declared
  public let line: Int

  /// Protocol conformances
  public let conformances: [ProtocolConformance]

  /// Generic parameters (e.g., ["T", "U"])
  public let genericParameters: [String]

  /// Properties of the type
  public let properties: [PropertyInfo]

  /// Methods of the type
  public let methods: [MethodInfo]

  /// Whether the type has a failable initializer
  public let hasFailableInit: Bool

  /// Whether the type has a public initializer
  public let hasPublicInit: Bool

  public init(
    name: String,
    kind: TypeKind,
    sourceFile: String,
    line: Int,
    conformances: [ProtocolConformance] = [],
    genericParameters: [String] = [],
    properties: [PropertyInfo] = [],
    methods: [MethodInfo] = [],
    hasFailableInit: Bool = false,
    hasPublicInit: Bool = true
  ) {
    self.name = name
    self.kind = kind
    self.sourceFile = sourceFile
    self.line = line
    self.conformances = conformances
    self.genericParameters = genericParameters
    self.properties = properties
    self.methods = methods
    self.hasFailableInit = hasFailableInit
    self.hasPublicInit = hasPublicInit
  }

  /// Full type name including generic parameters
  public var fullName: String {
    if genericParameters.isEmpty {
      return name
    }
    return "\(name)<\(genericParameters.joined(separator: ", "))>"
  }

  /// Whether the type is generic
  public var isGeneric: Bool {
    !genericParameters.isEmpty
  }

  /// Get all applicable test patterns for this type
  public var applicablePatterns: [TestPattern] {
    var patterns = Set<TestPattern>()

    for conformance in conformances {
      for pattern in conformance.applicablePatterns {
        patterns.insert(pattern)
      }
    }

    // Check for idempotent methods
    for method in methods where method.looksIdempotent {
      patterns.insert(.idempotent)
    }

    // Check for inverse function pairs
    let hasEncoder = methods.contains { $0.looksLikeEncoder }
    let hasDecoder = methods.contains { $0.looksLikeDecoder }
    if hasEncoder && hasDecoder {
      patterns.insert(.inverseFunctions)
    }

    return Array(patterns).sorted { $0.rawValue < $1.rawValue }
  }

  /// Whether this type can be used with Arbitrary/Gen
  public var canGenerateArbitrary: Bool {
    // Can generate if it's a simple type with properties we can generate
    // or if it conforms to protocols we know how to handle
    !conformances.isEmpty || !properties.isEmpty
  }
}

// MARK: - Source File Info

/// Information about a parsed source file.
public struct SourceFileInfo: Sendable {
  /// File path
  public let path: String

  /// Types defined in the file
  public let types: [TypeInfo]

  /// Import statements
  public let imports: [String]

  /// File hash for change detection
  public let hash: String

  public init(
    path: String,
    types: [TypeInfo],
    imports: [String] = [],
    hash: String = ""
  ) {
    self.path = path
    self.types = types
    self.imports = imports
    self.hash = hash
  }

  /// Total number of types
  public var typeCount: Int {
    types.count
  }

  /// Types that have applicable test patterns
  public var testableTypes: [TypeInfo] {
    types.filter { !$0.applicablePatterns.isEmpty }
  }
}
