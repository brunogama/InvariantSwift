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

  public var isPubliclyAccessible: Bool {
    self == .public || self == .open
  }

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
  public let kind: String
  public let sourceFile: String
  public let line: Int
  public let conformances: [String]
  public let hasArbitraryAttribute: Bool
  public let properties: [ExtractedProperty]
  public let methods: [ExtractedMethod]
  public let genericParameters: [String]
  public let accessLevel: AccessLevel

  public var isPublic: Bool {
    accessLevel.isPubliclyAccessible
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

  public var isPublic: Bool {
    accessLevel.isPubliclyAccessible
  }
}

/// Represents a method extracted from source code.
public struct ExtractedMethod: Codable, Sendable {
  public let name: String
  public let returnType: String?
  public let parameters: [ExtractedParameter]
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
  public let extensionConformances: [String: [String]]
  public let imports: [String]
}

// MARK: - Type Extractor

/// SwiftSyntax-based type extractor using SyntaxVisitor pattern.
public final class SwiftSyntaxTypeExtractor {
  public init() {}

  public func analyze(filePath: String) throws -> AnalysisResult {
    let url = URL(fileURLWithPath: filePath)
    let source = try String(contentsOf: url, encoding: .utf8)
    return analyze(source: source, filePath: filePath)
  }

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
}

// MARK: - Type Declaration Context

/// Parameter object for type extraction to reduce function parameter count.
struct TypeDeclContext {
  let name: String
  let kind: String
  let inheritanceClause: InheritanceClauseSyntax?
  let genericParameters: GenericParameterClauseSyntax?
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax
  let modifiers: DeclModifierListSyntax
  let startPosition: AbsolutePosition
}

// MARK: - Syntax Visitor

private struct TypeVisitor {
  let filePath: String
  var types: [ExtractedTypeInfo] = []
  var extensionConformances: [String: [String]] = [:]
  var imports: [String] = []

  init(filePath: String) {
    self.filePath = filePath
  }

  mutating func walk(_ node: some SyntaxProtocol) {
    handleNode(node)
    for child in node.children(viewMode: .sourceAccurate) {
      walk(child)
    }
  }

  private mutating func handleNode(_ node: some SyntaxProtocol) {
    if let importDecl = node.as(ImportDeclSyntax.self) {
      visitImport(importDecl)
    } else if let structDecl = node.as(StructDeclSyntax.self) {
      visitStruct(structDecl)
    } else if let classDecl = node.as(ClassDeclSyntax.self) {
      visitClass(classDecl)
    } else if let enumDecl = node.as(EnumDeclSyntax.self) {
      visitEnum(enumDecl)
    } else if let actorDecl = node.as(ActorDeclSyntax.self) {
      visitActor(actorDecl)
    } else if let extensionDecl = node.as(ExtensionDeclSyntax.self) {
      visitExtension(extensionDecl)
    }
  }

  private mutating func visitImport(_ node: ImportDeclSyntax) {
    let importPath = node.path.map { $0.name.text }.joined(separator: ".")
    imports.append(importPath)
  }

  private mutating func visitStruct(_ node: StructDeclSyntax) {
    let context = TypeDeclContext(
      name: node.name.text,
      kind: "struct",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia
    )
    types.append(extractTypeInfo(from: context))
  }

  private mutating func visitClass(_ node: ClassDeclSyntax) {
    let context = TypeDeclContext(
      name: node.name.text,
      kind: "class",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia
    )
    types.append(extractTypeInfo(from: context))
  }

  private mutating func visitEnum(_ node: EnumDeclSyntax) {
    let context = TypeDeclContext(
      name: node.name.text,
      kind: "enum",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia
    )
    types.append(extractTypeInfo(from: context))
  }

  private mutating func visitActor(_ node: ActorDeclSyntax) {
    let context = TypeDeclContext(
      name: node.name.text,
      kind: "actor",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia
    )
    types.append(extractTypeInfo(from: context))
  }

  private mutating func visitExtension(_ node: ExtensionDeclSyntax) {
    let typeName = node.extendedType.trimmedDescription
    if let inheritanceClause = node.inheritanceClause {
      let protocols = inheritanceClause.inheritedTypes.map { $0.type.trimmedDescription }
      extensionConformances[typeName, default: []].append(contentsOf: protocols)
    }
  }

  private func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> AccessLevel {
    for modifier in modifiers {
      if case .keyword(let keyword) = modifier.name.tokenKind {
        switch keyword {
        case .private: return .private
        case .fileprivate: return .fileprivate
        case .internal: return .internal
        case .public: return .public
        case .open: return .open
        default: continue
        }
      }
    }
    return .internal
  }

  private func extractTypeInfo(from ctx: TypeDeclContext) -> ExtractedTypeInfo {
    let conformances =
      ctx.inheritanceClause?.inheritedTypes.map {
        $0.type.trimmedDescription
      } ?? []

    let hasArbitrary = ctx.attributes.contains { attr in
      if case .attribute(let attrSyntax) = attr {
        return attrSyntax.attributeName.trimmedDescription == "Arbitrary"
      }
      return false
    }

    let generics = ctx.genericParameters?.parameters.map { $0.name.text } ?? []
    let accessLevel = extractAccessLevel(from: ctx.modifiers)
    let properties = extractProperties(from: ctx.members)
    let methods = extractMethods(from: ctx.members)
    let lineNumber = computeLineNumber(for: ctx.startPosition)

    return ExtractedTypeInfo(
      name: ctx.name,
      kind: ctx.kind,
      sourceFile: filePath,
      line: lineNumber,
      conformances: conformances,
      hasArbitraryAttribute: hasArbitrary,
      properties: properties,
      methods: methods,
      genericParameters: generics,
      accessLevel: accessLevel
    )
  }

  private func extractProperties(from members: MemberBlockItemListSyntax) -> [ExtractedProperty] {
    var properties: [ExtractedProperty] = []

    for member in members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
      let isMutable = varDecl.bindingSpecifier.text == "var"
      let accessLevel = extractAccessLevel(from: varDecl.modifiers)

      for binding in varDecl.bindings {
        let prop = extractProperty(
          from: binding,
          isMutable: isMutable,
          accessLevel: accessLevel
        )
        if let prop {
          properties.append(prop)
        }
      }
    }

    return properties
  }

  private func extractProperty(
    from binding: PatternBindingSyntax,
    isMutable: Bool,
    accessLevel: AccessLevel
  ) -> ExtractedProperty? {
    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
      return nil
    }

    // Skip computed properties
    if binding.accessorBlock != nil && binding.initializer == nil {
      return nil
    }

    let name = pattern.identifier.text
    let typeName: String
    let isOptional: Bool

    if let typeAnnotation = binding.typeAnnotation {
      typeName = typeAnnotation.type.trimmedDescription
      isOptional =
        typeAnnotation.type.is(OptionalTypeSyntax.self)
        || typeAnnotation.type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
    } else {
      typeName = "Unknown"
      isOptional = false
    }

    return ExtractedProperty(
      name: name,
      typeName: typeName,
      isOptional: isOptional,
      isMutable: isMutable,
      hasDefaultValue: binding.initializer != nil,
      accessLevel: accessLevel
    )
  }

  private func extractMethods(from members: MemberBlockItemListSyntax) -> [ExtractedMethod] {
    members.compactMap { member -> ExtractedMethod? in
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else {
        return nil
      }
      return extractMethod(from: funcDecl)
    }
  }

  private func extractMethod(from funcDecl: FunctionDeclSyntax) -> ExtractedMethod {
    let parameters = funcDecl.signature.parameterClause.parameters.map { param in
      ExtractedParameter(
        label: param.firstName.text == "_" ? nil : param.firstName.text,
        name: param.secondName?.text ?? param.firstName.text,
        typeName: param.type.trimmedDescription
      )
    }

    let isStatic = funcDecl.modifiers.contains {
      $0.name.text == "static" || $0.name.text == "class"
    }
    let isMutating = funcDecl.modifiers.contains { $0.name.text == "mutating" }

    return ExtractedMethod(
      name: funcDecl.name.text,
      returnType: funcDecl.signature.returnClause?.type.trimmedDescription,
      parameters: parameters,
      isStatic: isStatic,
      isMutating: isMutating,
      isThrowing: funcDecl.signature.effectSpecifiers?.throwsClause != nil,
      isAsync: funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
    )
  }

  private func computeLineNumber(for position: AbsolutePosition) -> Int {
    position.utf8Offset / 40 + 1
  }
}

// MARK: - Merge Conformances

extension SwiftSyntaxTypeExtractor {
  public static func mergeConformances(
    types: [ExtractedTypeInfo],
    extensions: [String: [String]]
  ) -> [ExtractedTypeInfo] {
    types.map { type in
      let additionalConformances = extensions[type.name] ?? []
      let mergedConformances = Array(Set(type.conformances + additionalConformances))

      return ExtractedTypeInfo(
        name: type.name,
        kind: type.kind,
        sourceFile: type.sourceFile,
        line: type.line,
        conformances: mergedConformances,
        hasArbitraryAttribute: type.hasArbitraryAttribute,
        properties: type.properties,
        methods: type.methods,
        genericParameters: type.genericParameters,
        accessLevel: type.accessLevel
      )
    }
  }
}
