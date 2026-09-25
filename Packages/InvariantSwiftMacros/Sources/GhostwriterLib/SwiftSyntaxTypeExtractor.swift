// MARK: - SwiftSyntax Type Extractor
// Accurate source code analysis using SwiftSyntax SyntaxVisitor.

import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Access Level

/// Swift access level modifiers.
public enum AccessLevel: String, Codable, Sendable, Comparable {
  case `private`
  case `fileprivate`
  case `internal`
  case `public`
  case `open`

  /// Whether this access level is accessible from test target.
  public var isPubliclyAccessible: Bool {
    self == .public || self == .open
  }

  /// Comparable implementation: private < fileprivate < internal < public < open
  public static func < (lhs: Self, rhs: Self) -> Bool {
    let order: [Self] = [.private, .fileprivate, .internal, .public, .open]
    guard let lhsIndex = order.firstIndex(of: lhs),
      let rhsIndex = order.firstIndex(of: rhs)
    else { return false }
    return lhsIndex < rhsIndex
  }
}

// MARK: - Extracted Type Info

/// Represents a Swift type extracted from source code.
public struct ExtractedTypeInfo: Codable, Sendable {
  public let name: String
  /// Lexically qualified source name, such as `Outer.Inner`.
  public let qualifiedName: String?
  public let kind: String  // struct, class, enum, actor
  public let sourceFile: String
  public let line: Int
  public let conformances: [String]
  public let hasArbitraryAttribute: Bool
  public let properties: [ExtractedProperty]
  public let methods: [ExtractedMethod]
  public let genericParameters: [String]
  public let accessLevel: AccessLevel
  public let enumCases: [String]

  public init(
    name: String,
    kind: String,
    sourceFile: String,
    line: Int,
    conformances: [String],
    hasArbitraryAttribute: Bool,
    properties: [ExtractedProperty],
    methods: [ExtractedMethod],
    genericParameters: [String],
    accessLevel: AccessLevel,
    enumCases: [String] = [],
    qualifiedName: String? = nil
  ) {
    self.name = name
    self.qualifiedName = qualifiedName
    self.kind = kind
    self.sourceFile = sourceFile
    self.line = line
    self.conformances = conformances
    self.hasArbitraryAttribute = hasArbitraryAttribute
    self.properties = properties
    self.methods = methods
    self.genericParameters = genericParameters
    self.accessLevel = accessLevel
    self.enumCases = enumCases
  }

  /// Backward compatible computed property
  public var isPublic: Bool {
    accessLevel.isPubliclyAccessible
  }

  var sourceQualifiedName: String {
    qualifiedName ?? name
  }

  var conformanceLookupName: String {
    SwiftSyntaxTypeExtractor.conformanceLookupName(
      typeName: sourceQualifiedName,
      sourceFile: sourceFile
    )
  }
}

/// Represents a property extracted from source code.
public struct ExtractedProperty: Codable, Sendable {
  public let name: String
  public let typeName: String
  public let isOptional: Bool
  public let isMutable: Bool
  public let hasDefaultValue: Bool
  public let accessLevel: AccessLevel

  /// Backward compatible computed property
  public var isPublic: Bool {
    accessLevel.isPubliclyAccessible
  }
}

/// Represents a method extracted from source code.
public struct ExtractedMethod: Codable, Sendable {
  public let name: String
  public let returnType: String?
  public let parameters: [ExtractedParameter]
  public let accessLevel: AccessLevel
  public let isStatic: Bool
  public let isMutating: Bool
  public let isThrowing: Bool
  public let isAsync: Bool
}

/// Represents a method parameter.
public struct ExtractedParameter: Codable, Sendable {
  public let label: String?
  public let name: String
  public let typeName: String
}

/// Result of analyzing a source file.
public struct AnalysisResult: Codable, Sendable {
  public let filePath: String
  public let types: [ExtractedTypeInfo]
  public let extensionConformances: [String: [String]]  // TypeName -> [Protocol]
  public let imports: [String]
}

// MARK: - Type Extractor

/// SwiftSyntax-based type extractor using SyntaxVisitor pattern.
public final class SwiftSyntaxTypeExtractor {

  public init() {}

  /// Analyze a Swift source file.
  public func analyze(filePath: String) throws -> AnalysisResult {
    let url = URL(fileURLWithPath: filePath)
    let source = try String(contentsOf: url, encoding: .utf8)
    return analyze(source: source, filePath: filePath)
  }

  /// Analyze Swift source code.
  public func analyze(source: String, filePath: String) -> AnalysisResult {
    let sourceFile = Parser.parse(source: source)
    var visitor = TypeVisitor(filePath: filePath)
    visitor.walk(sourceFile)

    return AnalysisResult(
      filePath: filePath,
      types: visitor.types,
      extensionConformances: visitor.extensionConformances,
      imports: visitor.imports
    )
  }

  static func conformanceLookupName(typeName: String, sourceFile: String) -> String {
    guard let moduleName = moduleName(for: sourceFile) else { return typeName }
    guard typeName != moduleName, !typeName.hasPrefix("\(moduleName).") else {
      return typeName
    }
    return "\(moduleName).\(typeName)"
  }

  static func moduleName(for sourceFile: String) -> String? {
    let components = URL(fileURLWithPath: sourceFile).standardizedFileURL.pathComponents
    guard let sourcesIndex = components.lastIndex(of: "Sources") else { return nil }
    let moduleIndex = components.index(after: sourcesIndex)
    guard moduleIndex < components.endIndex,
      components.index(after: moduleIndex) < components.endIndex
    else { return nil }
    return components[moduleIndex].replacingOccurrences(of: "-", with: "_")
  }
}

// MARK: - Syntax Visitor (Manual Traversal)
// Uses manual traversal to avoid SyntaxVisitor subclassing ABI issues with swift-syntax 602

struct TypeVisitor {
  let filePath: String
  var types: [ExtractedTypeInfo] = []
  var extensionConformances: [String: [String]] = [:]
  var imports: [String] = []
  var enclosingTypeNames: [String] = []
  var enclosingGenericParameters: [String] = []

  init(filePath: String) {
    self.filePath = filePath
  }

  /// Walk a syntax node and all its children
  mutating func walk(_ node: some SyntaxProtocol) {
    if let importDecl = node.as(ImportDeclSyntax.self) {
      visitImport(importDecl)
    }
    if let structDecl = node.as(StructDeclSyntax.self) {
      visitStruct(structDecl)
      walkChildren(
        of: structDecl,
        enclosing: structDecl.name.text,
        genericParameters: structDecl.genericParameterClause
      )
      return
    }
    if let classDecl = node.as(ClassDeclSyntax.self) {
      visitClass(classDecl)
      walkChildren(
        of: classDecl,
        enclosing: classDecl.name.text,
        genericParameters: classDecl.genericParameterClause
      )
      return
    }
    if let enumDecl = node.as(EnumDeclSyntax.self) {
      visitEnum(enumDecl)
      walkChildren(
        of: enumDecl,
        enclosing: enumDecl.name.text,
        genericParameters: enumDecl.genericParameterClause
      )
      return
    }
    if let actorDecl = node.as(ActorDeclSyntax.self) {
      visitActor(actorDecl)
      walkChildren(
        of: actorDecl,
        enclosing: actorDecl.name.text,
        genericParameters: actorDecl.genericParameterClause
      )
      return
    }
    if let extensionDecl = node.as(ExtensionDeclSyntax.self) {
      visitExtension(extensionDecl)
      walkExtensionChildren(of: extensionDecl)
      return
    }

    for child in node.children(viewMode: .sourceAccurate) {
      walk(child)
    }
  }

  private mutating func walkChildren(
    of node: some SyntaxProtocol,
    enclosing typeName: String,
    genericParameters: GenericParameterClauseSyntax?
  ) {
    let typeCount = enclosingTypeNames.count
    let genericCount = enclosingGenericParameters.count
    enclosingTypeNames.append(typeName)
    enclosingGenericParameters.append(
      contentsOf: genericParameters?.parameters.map { $0.name.text } ?? []
    )

    for child in node.children(viewMode: .sourceAccurate) {
      walk(child)
    }

    enclosingTypeNames.removeLast(enclosingTypeNames.count - typeCount)
    enclosingGenericParameters.removeLast(enclosingGenericParameters.count - genericCount)
  }

  private mutating func walkExtensionChildren(of node: ExtensionDeclSyntax) {
    let originalCount = enclosingTypeNames.count
    var extendedNames = node.extendedType.trimmedDescription.split(separator: ".").map(String.init)
    if extendedNames.first == SwiftSyntaxTypeExtractor.moduleName(for: filePath) {
      extendedNames.removeFirst()
    }
    enclosingTypeNames.append(contentsOf: extendedNames)

    for child in node.children(viewMode: .sourceAccurate) {
      walk(child)
    }

    enclosingTypeNames.removeLast(enclosingTypeNames.count - originalCount)
  }

  // MARK: - Import Extraction

  private mutating func visitImport(_ node: ImportDeclSyntax) {
    let importPath = node.path.map { $0.name.text }.joined(separator: ".")
    imports.append(importPath)
  }

  // MARK: - Struct Extraction

  private mutating func visitStruct(_ node: StructDeclSyntax) {
    let typeInfo = extractTypeInfo(
      name: node.name.text,
      kind: "struct",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia
    )
    types.append(typeInfo)
  }

  // MARK: - Class Extraction

  private mutating func visitClass(_ node: ClassDeclSyntax) {
    let typeInfo = extractTypeInfo(
      name: node.name.text,
      kind: "class",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia
    )
    types.append(typeInfo)
  }

  // MARK: - Enum Extraction

  private mutating func visitEnum(_ node: EnumDeclSyntax) {
    let cases = node.memberBlock.members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
      .flatMap(\.elements)
    let typeInfo = extractTypeInfo(
      name: node.name.text,
      kind: "enum",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia,
      enumCases: cases.allSatisfy({ $0.parameterClause == nil })
        ? cases.map { $0.name.text } : []
    )
    types.append(typeInfo)
  }

  // MARK: - Actor Extraction

  private mutating func visitActor(_ node: ActorDeclSyntax) {
    let typeInfo = extractTypeInfo(
      name: node.name.text,
      kind: "actor",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia
    )
    types.append(typeInfo)
  }

  // MARK: - Extension Extraction

  private mutating func visitExtension(_ node: ExtensionDeclSyntax) {
    let typeName = node.extendedType.trimmedDescription

    // Extract conformances from extension
    if let inheritanceClause = node.inheritanceClause {
      let protocols = inheritanceClause.inheritedTypes.map { inherited in
        inherited.type.trimmedDescription
      }
      let lookupName = SwiftSyntaxTypeExtractor.conformanceLookupName(
        typeName: typeName,
        sourceFile: filePath
      )
      extensionConformances[lookupName, default: []].append(contentsOf: protocols)
    }
  }

  // MARK: - Type Extraction Helper

  // swiftlint:disable:next function_parameter_count
  private func extractTypeInfo(
    name: String,
    kind: String,
    inheritanceClause: InheritanceClauseSyntax?,
    genericParameters: GenericParameterClauseSyntax?,
    members: MemberBlockItemListSyntax,
    attributes: AttributeListSyntax,
    modifiers: DeclModifierListSyntax,
    startPosition: AbsolutePosition,
    enumCases: [String] = []
  ) -> ExtractedTypeInfo {
    // Extract conformances
    let conformances: [String]
    if let clause = inheritanceClause {
      conformances = clause.inheritedTypes.map { $0.type.trimmedDescription }
    } else {
      conformances = []
    }

    // Check for @Arbitrary attribute
    let hasArbitrary = attributes.contains { attr in
      if case .attribute(let attrSyntax) = attr {
        return attrSyntax.attributeName.trimmedDescription == "Arbitrary"
      }
      return false
    }

    // Extract generic parameters
    let declaredGenerics: [String]
    if let genericClause = genericParameters {
      declaredGenerics = genericClause.parameters.map { $0.name.text }
    } else {
      declaredGenerics = []
    }

    // Extract access level
    let accessLevel = extractAccessLevel(from: modifiers)

    // Extract properties and methods
    let properties = extractProperties(from: members)
    let methods = extractMethods(from: members)

    // Calculate line number
    let lineNumber = computeLineNumber(for: startPosition)

    return ExtractedTypeInfo(
      name: name,
      kind: kind,
      sourceFile: filePath,
      line: lineNumber,
      conformances: conformances,
      hasArbitraryAttribute: hasArbitrary,
      properties: properties,
      methods: methods,
      genericParameters: enclosingGenericParameters + declaredGenerics,
      accessLevel: accessLevel,
      enumCases: enumCases,
      qualifiedName: (enclosingTypeNames + [name]).joined(separator: ".")
    )
  }

}
