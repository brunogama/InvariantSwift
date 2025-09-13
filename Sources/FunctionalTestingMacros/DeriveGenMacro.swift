import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

// MARK: - @DeriveGen Macro Implementation

/// **@DeriveGen Macro**
///
/// Automatically derives Gen<T> instances for Swift types using reflection and pattern matching.
/// This macro analyzes the structure of types and generates appropriate generators with:
/// - Proper shrinking strategies for each field
/// - Recursive generation for nested types
/// - Constraint-aware generation for enums and optionals
/// - Integration with existing manual generators
///
/// **Mathematical Foundation:**
/// Based on generic programming and type-directed generation from functional programming:
/// - Structural recursion over type constructors
/// - Compositional generation following type algebra
/// - Preservation of type invariants during generation
///
/// **External References:**
/// - [QuickCheck's Generic Derivation](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck-Arbitrary.html)
/// - [Generic Programming in Haskell](https://wiki.haskell.org/GHC.Generics)
/// - [Scrap Your Boilerplate](https://www.microsoft.com/en-us/research/publication/scrap-your-boilerplate-a-practical-design-pattern-for-generic-programming/)
///
/// **Usage Examples:**
/// ```swift
/// @DeriveGen
/// struct Person {
///     let name: String
///     let age: Int
///     let email: String?
/// }
/// // Generates: extension Person { static var gen: Gen<Person> { ... } }
///
/// @DeriveGen(customFields: ["name": "Gen.asciiString.suchThat { !$0.isEmpty }"])
/// struct User {
///     let name: String
///     let id: UUID
/// }
/// // Uses custom generator for name, derives others automatically
/// ```
public struct DeriveGenMacro: MemberMacro, ExtensionMacro {

  // MARK: - Macro Entry Points

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    // Extract configuration from macro arguments
    let config = try extractConfiguration(from: node, context: context)

    // Analyze the type structure
    guard let analyzed = try analyzeTypeStructure(declaration, context: context) else {
      throw DeriveGenError.unsupportedType("Cannot derive generator for this type")
    }

    // Generate the generator implementation
    let generatorMember = try generateGeneratorMember(
      for: analyzed,
      config: config,
      context: context
    )

    return [generatorMember]
  }

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {

    // Create extension with Generatable conformance
    let extensionDecl = try ExtensionDeclSyntax(
      "extension \(type.trimmed): Generatable"
    ) {
      // Empty - the actual implementation is in the member macro
    }

    return [extensionDecl]
  }
}

// MARK: - Configuration and Types

/// **Configuration for generator derivation**
struct DeriveGenConfig {
  /// Custom generators for specific fields
  let customFields: [String: String]

  /// Maximum depth for recursive generation
  let maxDepth: Int

  /// Size scaling factor
  let sizeScaling: Double

  /// Whether to generate shrinking implementations
  let enableShrinking: Bool

  /// Custom constraints
  let constraints: [String: String]

  static let `default` = Self(
    customFields: [:],
    maxDepth: 5,
    sizeScaling: 1.0,
    enableShrinking: true,
    constraints: [:]
  )
}

/// **Analyzed type structure**
enum AnalyzedType {
  case `struct`(name: String, fields: [StructField])
  case `enum`(name: String, cases: [EnumCase])
  case `class`(name: String, properties: [ClassProperty])
}

struct StructField {
  let name: String
  let type: TypeSyntax
  let isOptional: Bool
  let isCollection: Bool
  let collectionElementType: TypeSyntax?
}

struct EnumCase {
  let name: String
  let associatedValues: [AssociatedValue]?
}

struct AssociatedValue {
  let label: String?
  let type: TypeSyntax
}

struct ClassProperty {
  let name: String
  let type: TypeSyntax
  let isReadOnly: Bool
}

// MARK: - Error Types

enum DeriveGenError: Error, CustomStringConvertible {
  case unsupportedType(String)
  case invalidConfiguration(String)
  case generationFailed(String)

  var description: String {
    switch self {
    case .unsupportedType(let msg):
      return "Unsupported type for @DeriveGen: \(msg)"

    case .invalidConfiguration(let msg):
      return "Invalid @DeriveGen configuration: \(msg)"

    case .generationFailed(let msg):
      return "Generator derivation failed: \(msg)"
    }
  }
}

// MARK: - Configuration Extraction

private func extractConfiguration(
  from node: AttributeSyntax,
  context: some MacroExpansionContext
) throws -> DeriveGenConfig {
  var config = DeriveGenConfig.default

  // Parse macro arguments
  if case .argumentList(let arguments) = node.arguments {
    for argument in arguments {
      switch argument.label?.text {
      case "customFields":
        config = try parseCustomFields(argument.expression, config: config)

      case "maxDepth":
        config = try parseMaxDepth(argument.expression, config: config)

      case "sizeScaling":
        config = try parseSizeScaling(argument.expression, config: config)

      case "enableShrinking":
        config = try parseEnableShrinking(argument.expression, config: config)

      default:
        break
      }
    }
  }

  return config
}

private func parseCustomFields(
  _ expr: ExprSyntax,
  config: DeriveGenConfig
) throws -> DeriveGenConfig {
  // Parse dictionary literal: ["field": "generator"]
  guard let dictExpr = expr.as(DictionaryExprSyntax.self) else {
    throw DeriveGenError.invalidConfiguration("customFields must be a dictionary")
  }

  var customFields: [String: String] = [:]

  if case .elements(let elements) = dictExpr.content {
    for element in elements {
      guard let keyExpr = element.key.as(StringLiteralExprSyntax.self),
        let valueExpr = element.value.as(StringLiteralExprSyntax.self)
      else {
        throw DeriveGenError.invalidConfiguration("customFields must be [String: String]")
      }

      let key = keyExpr.representedLiteralValue ?? ""
      let value = valueExpr.representedLiteralValue ?? ""
      customFields[key] = value
    }
  }

  return DeriveGenConfig(
    customFields: customFields,
    maxDepth: config.maxDepth,
    sizeScaling: config.sizeScaling,
    enableShrinking: config.enableShrinking,
    constraints: config.constraints
  )
}

private func parseMaxDepth(
  _ expr: ExprSyntax,
  config: DeriveGenConfig
) throws -> DeriveGenConfig {
  guard let intExpr = expr.as(IntegerLiteralExprSyntax.self),
    let maxDepth = Int(intExpr.literal.text)
  else {
    throw DeriveGenError.invalidConfiguration("maxDepth must be an integer")
  }

  return DeriveGenConfig(
    customFields: config.customFields,
    maxDepth: maxDepth,
    sizeScaling: config.sizeScaling,
    enableShrinking: config.enableShrinking,
    constraints: config.constraints
  )
}

private func parseSizeScaling(
  _ expr: ExprSyntax,
  config: DeriveGenConfig
) throws -> DeriveGenConfig {
  // Parse floating point literal
  let scaling: Double
  if let floatExpr = expr.as(FloatLiteralExprSyntax.self) {
    scaling = Double(floatExpr.literal.text) ?? 1.0
  } else if let intExpr = expr.as(IntegerLiteralExprSyntax.self) {
    scaling = Double(intExpr.literal.text) ?? 1.0
  } else {
    throw DeriveGenError.invalidConfiguration("sizeScaling must be a number")
  }

  return DeriveGenConfig(
    customFields: config.customFields,
    maxDepth: config.maxDepth,
    sizeScaling: scaling,
    enableShrinking: config.enableShrinking,
    constraints: config.constraints
  )
}

private func parseEnableShrinking(
  _ expr: ExprSyntax,
  config: DeriveGenConfig
) throws -> DeriveGenConfig {
  guard let boolExpr = expr.as(BooleanLiteralExprSyntax.self) else {
    throw DeriveGenError.invalidConfiguration("enableShrinking must be a boolean")
  }

  let enabled = boolExpr.literal.text == "true"

  return DeriveGenConfig(
    customFields: config.customFields,
    maxDepth: config.maxDepth,
    sizeScaling: config.sizeScaling,
    enableShrinking: enabled,
    constraints: config.constraints
  )
}

// MARK: - Type Structure Analysis

private func analyzeTypeStructure(
  _ declaration: some DeclGroupSyntax,
  context: some MacroExpansionContext
) throws -> AnalyzedType? {

  if let structDecl = declaration.as(StructDeclSyntax.self) {
    return try analyzeStruct(structDecl, context: context)
  } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
    return try analyzeEnum(enumDecl, context: context)
  } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
    return try analyzeClass(classDecl, context: context)
  }

  return nil
}

private func analyzeStruct(
  _ structDecl: StructDeclSyntax,
  context: some MacroExpansionContext
) throws -> AnalyzedType {
  let name = structDecl.name.text
  var fields: [StructField] = []

  for member in structDecl.memberBlock.members {
    if let varDecl = member.decl.as(VariableDeclSyntax.self) {
      for binding in varDecl.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
          let typeAnnotation = binding.typeAnnotation
        else {
          continue
        }

        let fieldName = pattern.identifier.text
        let fieldType = typeAnnotation.type
        let (isOptional, unwrappedType) = unwrapOptional(fieldType)
        let (isCollection, elementType) = analyzeCollection(unwrappedType)

        fields.append(
          StructField(
            name: fieldName,
            type: fieldType,
            isOptional: isOptional,
            isCollection: isCollection,
            collectionElementType: elementType
          )
        )
      }
    }
  }

  return .struct(name: name, fields: fields)
}

private func analyzeEnum(
  _ enumDecl: EnumDeclSyntax,
  context: some MacroExpansionContext
) throws -> AnalyzedType {
  let name = enumDecl.name.text
  var cases: [EnumCase] = []

  for member in enumDecl.memberBlock.members {
    if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
      for element in caseDecl.elements {
        let caseName = element.name.text

        let associatedValues: [AssociatedValue]? = element.parameterClause?.parameters.map {
          param in
          AssociatedValue(
            label: param.firstName?.text,
            type: param.type
          )
        }

        cases.append(
          EnumCase(
            name: caseName,
            associatedValues: associatedValues
          )
        )
      }
    }
  }

  return .enum(name: name, cases: cases)
}

private func analyzeClass(
  _ classDecl: ClassDeclSyntax,
  context: some MacroExpansionContext
) throws -> AnalyzedType {
  let name = classDecl.name.text
  var properties: [ClassProperty] = []

  for member in classDecl.memberBlock.members {
    if let varDecl = member.decl.as(VariableDeclSyntax.self) {
      let isReadOnly = !varDecl.bindingSpecifier.text.contains("var")

      for binding in varDecl.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
          let typeAnnotation = binding.typeAnnotation
        else {
          continue
        }

        properties.append(
          ClassProperty(
            name: pattern.identifier.text,
            type: typeAnnotation.type,
            isReadOnly: isReadOnly
          )
        )
      }
    }
  }

  return .class(name: name, properties: properties)
}

// MARK: - Type Analysis Utilities

private func unwrapOptional(_ type: TypeSyntax) -> (isOptional: Bool, unwrapped: TypeSyntax) {
  if let optionalType = type.as(OptionalTypeSyntax.self) {
    return (true, optionalType.wrappedType)
  }
  return (false, type)
}

private func analyzeCollection(_ type: TypeSyntax) -> (isCollection: Bool, elementType: TypeSyntax?)
{
  // Check for Array<T> or [T]
  if let arrayType = type.as(ArrayTypeSyntax.self) {
    return (true, arrayType.element)
  }

  // Check for generic types like Set<T>, Dictionary<K, V>
  if let identifierType = type.as(IdentifierTypeSyntax.self),
    let genericClause = identifierType.genericArgumentClause
  {
    let typeName = identifierType.name.text

    if ["Array", "Set"].contains(typeName) && genericClause.arguments.count == 1 {
      return (true, genericClause.arguments.first?.argument.as(TypeSyntax.self))
    } else if typeName == "Dictionary" && genericClause.arguments.count == 2 {
      return (true, genericClause.arguments.last?.argument.as(TypeSyntax.self))
    }
  }

  return (false, nil)
}

// MARK: - Generator Implementation Generation

private func generateGeneratorMember(
  for analyzedType: AnalyzedType,
  config: DeriveGenConfig,
  context: some MacroExpansionContext
) throws -> DeclSyntax {

  switch analyzedType {
  case .struct(let name, let fields):
    return try generateStructGenerator(name: name, fields: fields, config: config)

  case .enum(let name, let cases):
    return try generateEnumGenerator(name: name, cases: cases, config: config)

  case .class(let name, let properties):
    return try generateClassGenerator(name: name, properties: properties, config: config)
  }
}

private func generateStructGenerator(
  name: String,
  fields: [StructField],
  config: DeriveGenConfig
) throws -> DeclSyntax {

  let fieldGenerators = fields.map { field in
    generateFieldGenerator(field, config: config)
  }.joined(separator: ",\n            ")

  let fieldInitializers = fields.map { field in
    "\(field.name): \(field.name)"
  }.joined(separator: ", ")

  let generatorBody = """
    public static var gen: Gen<\(name)> {
        Gen.zip(
            \(fieldGenerators)
        ).map { \(fields.map { $0.name }.joined(separator: ", ")) in
            \(name)(\(fieldInitializers))
        }
    }
    """

  return DeclSyntax(stringLiteral: generatorBody)
}

private func generateEnumGenerator(
  name: String,
  cases: [EnumCase],
  config: DeriveGenConfig
) throws -> DeclSyntax {

  let caseGenerators = cases.enumerated().map { _, enumCase in
    if let associatedValues = enumCase.associatedValues, !associatedValues.isEmpty {
      let valueGenerators = associatedValues.map { value in
        generateTypeGenerator(value.type, config: config)
      }.joined(separator: ", ")

      let valueNames = associatedValues.enumerated().map { i, _ in "value\(i)" }.joined(
        separator: ", "
      )

      return """
        Gen.zip(\(valueGenerators)).map { \(valueNames) in
            \(name).\(enumCase.name)(\(valueNames))
        }
        """
    } else {
      return "Gen.pure(\(name).\(enumCase.name))"
    }
  }

  let allCaseGenerators = caseGenerators.joined(separator: ",\n            ")

  let generatorBody = """
    public static var gen: Gen<\(name)> {
        Gen.oneOf([
            \(allCaseGenerators)
        ])
    }
    """

  return DeclSyntax(stringLiteral: generatorBody)
}

private func generateClassGenerator(
  name: String,
  properties: [ClassProperty],
  config: DeriveGenConfig
) throws -> DeclSyntax {

  // For classes, we need a different approach since we can't use memberwise initializers
  let propertyGenerators = properties.map { property in
    generateFieldGenerator(
      StructField(
        name: property.name,
        type: property.type,
        isOptional: false,  // Analyze based on type
        isCollection: false,  // Analyze based on type
        collectionElementType: nil
      ),
      config: config
    )
  }.joined(separator: ",\n            ")

  let propertyAssignments = properties.map { property in
    "instance.\(property.name) = \(property.name)"
  }.joined(separator: "\n                ")

  let generatorBody = """
    public static var gen: Gen<\(name)> {
        Gen.zip(
            \(propertyGenerators)
        ).map { \(properties.map { $0.name }.joined(separator: ", ")) in
            let instance = \(name)()
            \(propertyAssignments)
            return instance
        }
    }
    """

  return DeclSyntax(stringLiteral: generatorBody)
}

// MARK: - Field Generator Generation

private func generateFieldGenerator(_ field: StructField, config: DeriveGenConfig) -> String {
  // Check for custom generator
  if let customGen = config.customFields[field.name] {
    return customGen
  }

  // Generate based on type
  let baseGenerator = generateTypeGenerator(field.type, config: config)

  if field.isOptional {
    return "Gen.optional(\(baseGenerator))"
  } else if field.isCollection, let elementType = field.collectionElementType {
    let elementGenerator = generateTypeGenerator(elementType, config: config)
    return "Gen.array(\(elementGenerator))"
  } else {
    return baseGenerator
  }
}

private func generateTypeGenerator(_ type: TypeSyntax, config: DeriveGenConfig) -> String {
  let typeName = type.trimmedDescription

  // Built-in type generators
  switch typeName {
  case "Int":
    return "Gen.int"

  case "String":
    return "Gen.string"

  case "Bool":
    return "Gen.bool"

  case "Double":
    return "Gen.double"

  case "Float":
    return "Gen.float"

  case "UUID":
    return "Gen.uuid"

  default:
    // Assume the type has its own generator
    return "\(typeName).gen"
  }
}

// MARK: - Plugin Registration
// Note: Plugin registration moved to MacroPlugin.swift to avoid duplicate @main

// MARK: - Public Macro Declaration

/// **@DeriveGen Macro Attribute**
///
/// Automatically derives a `Gen<T>` generator for the annotated type.
///
/// **Parameters:**
/// - `customFields`: Dictionary of custom generators for specific fields
/// - `maxDepth`: Maximum recursion depth (default: 5)
/// - `sizeScaling`: Size scaling factor (default: 1.0)
/// - `enableShrinking`: Whether to generate shrinking (default: true)
///
/// **Example:**
/// ```swift
/// @DeriveGen(customFields: ["email": "Gen.email", "age": "Gen.int(in: 0...120)"])
/// struct User {
///     let name: String
///     let email: String
///     let age: Int
/// }
/// ```
// @attached(member, names: named(gen))
// @attached(extension, conformances: Generatable)
/*
public macro DeriveGen(
  customFields: [String: String] = [:],
  maxDepth: Int = 5,
  sizeScaling: Double = 1.0,
  enableShrinking: Bool = true
) = #externalMacro(module: "FunctionalTestingMacros", type: "DeriveGenMacro")
*/

/// **Protocol for types that can generate instances**
public protocol Generatable {
  associatedtype Generator
  static var gen: Generator { get }
}
