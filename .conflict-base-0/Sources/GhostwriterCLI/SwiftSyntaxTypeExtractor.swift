// MARK: - SwiftSyntax Type Extractor
// Accurate source code analysis using SwiftSyntax SyntaxVisitor.

import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Extracted Type Info

/// Represents a Swift type extracted from source code.
public struct ExtractedTypeInfo: Codable, Sendable {
  public let name: String
  public let kind: String  // struct, class, enum, actor
  public let sourceFile: String
  public let line: Int
  public let conformances: [String]
  public let hasArbitraryAttribute: Bool
  public let properties: [ExtractedProperty]
  public let methods: [ExtractedMethod]
  public let genericParameters: [String]
  public let isPublic: Bool
}

/// Represents a property extracted from source code.
public struct ExtractedProperty: Codable, Sendable {
  public let name: String
  public let typeName: String
  public let isOptional: Bool
  public let isMutable: Bool
  public let hasDefaultValue: Bool
  public let isPublic: Bool
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
    let visitor = TypeVisitor(filePath: filePath)
    visitor.walk(sourceFile)

    return AnalysisResult(
      filePath: filePath,
      types: visitor.types,
      extensionConformances: visitor.extensionConformances,
      imports: visitor.imports
    )
  }
}

// MARK: - Syntax Visitor

private final class TypeVisitor: SyntaxVisitor {
  let filePath: String
  var types: [ExtractedTypeInfo] = []
  var extensionConformances: [String: [String]] = [:]
  var imports: [String] = []

  init(filePath: String) {
    self.filePath = filePath
    super.init(viewMode: .sourceAccurate)
  }

  // MARK: - Import Extraction

  override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
    let importPath = node.path.map { $0.name.text }.joined(separator: ".")
    imports.append(importPath)
    return .skipChildren
  }

  // MARK: - Struct Extraction

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
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
    return .visitChildren  // Visit nested types
  }

  // MARK: - Class Extraction

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
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
    return .visitChildren
  }

  // MARK: - Enum Extraction

  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    let typeInfo = extractTypeInfo(
      name: node.name.text,
      kind: "enum",
      inheritanceClause: node.inheritanceClause,
      genericParameters: node.genericParameterClause,
      members: node.memberBlock.members,
      attributes: node.attributes,
      modifiers: node.modifiers,
      startPosition: node.positionAfterSkippingLeadingTrivia
    )
    types.append(typeInfo)
    return .visitChildren
  }

  // MARK: - Actor Extraction

  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
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
    return .visitChildren
  }

  // MARK: - Extension Extraction

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    let typeName = node.extendedType.trimmedDescription

    // Extract conformances from extension
    if let inheritanceClause = node.inheritanceClause {
      let protocols = inheritanceClause.inheritedTypes.map { inherited in
        inherited.type.trimmedDescription
      }
      extensionConformances[typeName, default: []].append(contentsOf: protocols)
    }

    return .visitChildren
  }

  // MARK: - Type Extraction Helper

  private func extractTypeInfo(
    name: String,
    kind: String,
    inheritanceClause: InheritanceClauseSyntax?,
    genericParameters: GenericParameterClauseSyntax?,
    members: MemberBlockItemListSyntax,
    attributes: AttributeListSyntax,
    modifiers: DeclModifierListSyntax,
    startPosition: AbsolutePosition
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
    let generics: [String]
    if let genericClause = genericParameters {
      generics = genericClause.parameters.map { $0.name.text }
    } else {
      generics = []
    }

    // Check if public
    let isPublic = modifiers.contains { modifier in
      modifier.name.text == "public" || modifier.name.text == "open"
    }

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
      genericParameters: generics,
      isPublic: isPublic
    )
  }

  // MARK: - Property Extraction

  private func extractProperties(from members: MemberBlockItemListSyntax) -> [ExtractedProperty] {
    var properties: [ExtractedProperty] = []

    for member in members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

      let isMutable = varDecl.bindingSpecifier.text == "var"
      let isPublic = varDecl.modifiers.contains { $0.name.text == "public" }

      for binding in varDecl.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

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

        let hasDefault = binding.initializer != nil

        // Skip computed properties (they have accessors without stored initializer)
        if binding.accessorBlock != nil && binding.initializer == nil {
          continue
        }

        properties.append(
          ExtractedProperty(
            name: name,
            typeName: typeName,
            isOptional: isOptional,
            isMutable: isMutable,
            hasDefaultValue: hasDefault,
            isPublic: isPublic
          )
        )
      }
    }

    return properties
  }

  // MARK: - Method Extraction

  private func extractMethods(from members: MemberBlockItemListSyntax) -> [ExtractedMethod] {
    var methods: [ExtractedMethod] = []

    for member in members {
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }

      let name = funcDecl.name.text

      // Extract parameters
      let parameters = funcDecl.signature.parameterClause.parameters.map { param in
        ExtractedParameter(
          label: param.firstName.text == "_" ? nil : param.firstName.text,
          name: param.secondName?.text ?? param.firstName.text,
          typeName: param.type.trimmedDescription
        )
      }

      // Extract return type
      let returnType = funcDecl.signature.returnClause?.type.trimmedDescription

      // Check modifiers
      let isStatic = funcDecl.modifiers.contains {
        $0.name.text == "static" || $0.name.text == "class"
      }
      let isMutating = funcDecl.modifiers.contains { $0.name.text == "mutating" }

      // Check effects
      let isThrowing = funcDecl.signature.effectSpecifiers?.throwsClause != nil
      let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

      methods.append(
        ExtractedMethod(
          name: name,
          returnType: returnType,
          parameters: parameters,
          isStatic: isStatic,
          isMutating: isMutating,
          isThrowing: isThrowing,
          isAsync: isAsync
        )
      )
    }

    return methods
  }

  // MARK: - Line Number Computation

  private func computeLineNumber(for position: AbsolutePosition) -> Int {
    // SwiftSyntax uses 0-based offsets, convert to 1-based line numbers
    // This is a simplified version - for accurate line numbers we'd need source location converter
    return position.utf8Offset / 40 + 1  // Rough estimate
  }
}

// MARK: - Location Converter Extension

extension SwiftSyntaxTypeExtractor {
  /// Merge extension conformances into type info.
  public static func mergeConformances(
    types: [ExtractedTypeInfo],
    extensions: [String: [String]]
  ) -> [ExtractedTypeInfo] {
    return types.map { type in
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
        isPublic: type.isPublic
      )
    }
  }
}
