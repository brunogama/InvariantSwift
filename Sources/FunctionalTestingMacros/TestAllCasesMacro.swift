/// **@TestAllCases Macro Implementation**
///
/// SwiftSyntax-based macro that generates comprehensive test suites systematically
/// exploring boundary conditions, edge cases, and equivalence partitions. This macro
/// implements systematic testing methodologies without requiring deep testing expertise.
///
/// **Mathematical Foundation:**
/// Based on boundary value analysis and equivalence partitioning theory,
/// applying formal testing methodologies through automated test case generation.
/// Uses category-partition methods for systematic input domain coverage.
///
/// **AST Transformation:**
/// ```swift
/// // Input:
/// @TestAllCases(focus: .comprehensive)
/// struct Product {
///     let price: Decimal
///     let quantity: Int
/// }
///
/// // Generated:
/// extension Product: AutoTestable {
///     static var comprehensiveTests: [Gen<Product>] {
///         [
///             // Boundary tests
///             Gen.constant(Product(price: 0, quantity: 0)),
///             Gen.constant(Product(price: Decimal.greatestFiniteMagnitude, quantity: Int.max)),
///             // Edge cases
///             Gen.constant(Product(price: -1, quantity: -1)),
///             // Realistic generators
///             Gen.zip(Gen.decimal(in: 0...10000), Gen.int(in: 1...1000))
///                 .map(Product.init)
///         ]
///     }
/// }
/// ```
///
/// **External References:**
/// - [Boundary Value Analysis](https://en.wikipedia.org/wiki/Boundary_value_analysis)
/// - [Equivalence Partitioning](https://en.wikipedia.org/wiki/Equivalence_partitioning)
/// - [SwiftSyntax AST Guide](https://github.com/apple/swift-syntax)

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftParser
import Foundation

// MARK: - Macro Declaration

/// **@TestAllCases macro for comprehensive boundary testing**
///
/// Automatically generates systematic test case coverage including boundary values,
/// edge cases, and equivalence partitions. Implements formal testing methodologies
/// through type analysis and intelligent test case generation.
///
/// **Usage:**
/// ```swift
/// @TestAllCases(focus: .comprehensive)
/// struct OrderAmount {
///     let subtotal: Decimal
///     let tax: Decimal
///     let total: Decimal
/// }
///
/// @TestAllCases(focus: .boundary)
/// enum PaymentStatus {
///     case pending, authorized, captured, failed, refunded
/// }
/// ```
///
/// **Test Focus Strategies:**
/// - **Comprehensive**: Maximum coverage (boundary + edge + typical cases)
/// - **Boundary**: Focus on boundary value analysis
/// - **Edges**: Minimal testing of known problematic values
public struct TestAllCasesMacro: ExtensionMacro {

  // MARK: - Extension Macro Implementation

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {

    // Extract macro arguments
    let arguments = try extractMacroArguments(from: node)

    // Extract type name
    let typeName: String
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      typeName = structDecl.name.text
    } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
      typeName = classDecl.name.text
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      typeName = enumDecl.name.text
    } else {
      throw TestAllCasesMacroError.unsupportedType
    }

    // Generate appropriate extension based on type
    let extensionDecl: ExtensionDeclSyntax

    if let structDecl = declaration.as(StructDeclSyntax.self) {
      let properties = try extractProperties(from: structDecl)
      extensionDecl = try generateStructExtension(
        for: typeName,
        properties: properties,
        focus: arguments.focus
      )
    } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
      let properties = try extractProperties(from: classDecl)
      extensionDecl = try generateStructExtension(
        for: typeName,
        properties: properties,
        focus: arguments.focus
      )
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      extensionDecl = try generateEnumExtension(
        for: enumDecl,
        typeName: typeName,
        focus: arguments.focus
      )
    } else {
      throw TestAllCasesMacroError.unsupportedType
    }

    return [extensionDecl]
  }
}

// MARK: - Supporting Types

/// Arguments extracted from @TestAllCases macro
private struct TestAllCasesMacroArguments {
  let focus: TestFocus

  static let defaultArguments = Self(focus: .comprehensive)
}

/// Test focus for comprehensive testing strategies
public enum TestFocus: String, Sendable {
  /// **Comprehensive testing** - Maximum coverage including edge cases, boundaries, and equivalence partitions
  case comprehensive = "comprehensive"

  /// **Boundary focus** - Concentrates on boundary value analysis and limit conditions
  case boundary = "boundary"

  /// **Edge cases only** - Minimal testing focusing on known problematic values
  case edges = "edges"
}

/// Property information for test case generation
private struct TestPropertyInfo {
  let name: String
  let type: String
  let isOptional: Bool

  /// Generate boundary test cases for this property type
  func boundaryTestCases() -> [String] {
    let baseType = isOptional ? String(type.dropLast()) : type

    switch baseType {
    case "Int":
      return [
        "Int.min",
        "Int.max",
        "0",
        "-1",
        "1",
      ]

    case "Double":
      return [
        "Double.leastNormalMagnitude",
        "Double.greatestFiniteMagnitude",
        "0.0",
        "-0.0",
        "1.0",
        "-1.0",
      ]

    case "Float":
      return [
        "Float.leastNormalMagnitude",
        "Float.greatestFiniteMagnitude",
        "0.0",
        "1.0",
        "-1.0",
      ]

    case "String":
      return [
        "\"\"",
        "\" \"",
        "\"a\"",
        "\"\\u{0000}\"",  // Null character
        "String(repeating: \"x\", count: 10000)",  // Long string
      ]

    case "Decimal":
      return [
        "Decimal.leastNormalMagnitude",
        "Decimal.greatestFiniteMagnitude",
        "Decimal.zero",
        "Decimal(1)",
        "Decimal(-1)",
      ]

    case "Bool":
      return ["true", "false"]

    case "UUID":
      return [
        "UUID()",
        "UUID(uuidString: \"00000000-0000-0000-0000-000000000000\")!",
      ]

    case "Date":
      return [
        "Date.distantPast",
        "Date.distantFuture",
        "Date()",
        "Date(timeIntervalSince1970: 0)",
      ]

    default:
      // For custom types, assume they have boundary values
      if type.hasPrefix("[") {
        // Array type
        return ["[]", "[\(baseType)()]"]
      } else {
        // Custom type - try to use boundary methods
        return ["\(baseType)()"]
      }
    }
  }

  /// Generate edge case test values
  func edgeCaseTestCases() -> [String] {
    let baseType = isOptional ? String(type.dropLast()) : type

    switch baseType {
    case "Int":
      return [
        "Int.min + 1",
        "Int.max - 1",
      ]

    case "Double":
      return [
        "Double.nan",
        "Double.infinity",
        "-Double.infinity",
        "Double.ulpOfOne",
      ]

    case "Float":
      return [
        "Float.nan",
        "Float.infinity",
        "-Float.infinity",
      ]

    case "String":
      return [
        "\"\\n\"",  // Newline
        "\"\\t\"",  // Tab
        "\"\\u{1F600}\"",  // Emoji
        "\"测试\"",  // Non-ASCII
        "String(repeating: \" \", count: 100)",  // Whitespace only
      ]

    case "Decimal":
      return [
        "Decimal.leastNonzeroMagnitude",
        "Decimal(sign: .minus, exponent: -128, significand: 1)",
      ]

    default:
      return []
    }
  }

  /// Generate typical value generators
  func typicalValueGenerator() -> String {
    let baseType = isOptional ? String(type.dropLast()) : type

    switch baseType {
    case "Int":
      return "Gen.int(in: 1...1000)"

    case "Double":
      return "Gen.double(in: 0.1...1000.0)"

    case "Float":
      return "Gen.float(in: 0.1...1000.0)"

    case "String":
      return "Gen.string(ofLength: 1...50)"

    case "Decimal":
      return "Gen.decimal(in: 0.01...10000.00)"

    case "Bool":
      return "Gen.bool"

    case "UUID":
      return "Gen.uuid"

    case "Date":
      return "Gen.date"

    default:
      // For custom types, try SmartGeneratable or fallback
      return "\(baseType).smartGen"
    }
  }
}

/// Errors specific to @TestAllCases macro
enum TestAllCasesMacroError: Error, CustomStringConvertible {
  case unsupportedType
  case noStoredProperties
  case generationFailed(String)

  var description: String {
    switch self {
    case .unsupportedType:
      return "@TestAllCases can only be applied to structs, classes, and enums"

    case .noStoredProperties:
      return "@TestAllCases requires at least one stored property or enum case"

    case .generationFailed(let reason):
      return "Failed to generate test cases: \(reason)"
    }
  }
}

// MARK: - Implementation Helpers

private extension TestAllCasesMacro {

  /// Extract macro arguments from AttributeSyntax
  static func extractMacroArguments(from node: AttributeSyntax) throws -> TestAllCasesMacroArguments
  {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return .defaultArguments
    }

    var focus: TestFocus = .comprehensive

    for argument in arguments {
      if let label = argument.label?.text {
        switch label {
        case "focus":
          if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
            let focusValue = memberAccess.declName.baseName.text
            focus = TestFocus(rawValue: focusValue) ?? .comprehensive
          }

        default:
          break
        }
      }
    }

    return TestAllCasesMacroArguments(focus: focus)
  }

  /// Extract properties from a struct/class declaration
  static func extractProperties(from structDecl: StructDeclSyntax) throws -> [TestPropertyInfo] {
    var properties: [TestPropertyInfo] = []

    for member in structDecl.memberBlock.members {
      if let varDecl = member.decl.as(VariableDeclSyntax.self) {
        // Only process stored properties
        guard varDecl.bindings.first?.accessorBlock == nil else { continue }

        for binding in varDecl.bindings {
          guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
            let typeAnnotation = binding.typeAnnotation?.type
          else {
            continue
          }

          let typeString = typeAnnotation.description.trimmingCharacters(in: .whitespaces)
          let isOptional = typeString.hasSuffix("?")

          properties.append(
            TestPropertyInfo(
              name: pattern.identifier.text,
              type: typeString,
              isOptional: isOptional
            )
          )
        }
      }
    }

    guard !properties.isEmpty else {
      throw TestAllCasesMacroError.noStoredProperties
    }

    return properties
  }

  /// Extract properties from a class declaration
  static func extractProperties(from classDecl: ClassDeclSyntax) throws -> [TestPropertyInfo] {
    var properties: [TestPropertyInfo] = []

    for member in classDecl.memberBlock.members {
      if let varDecl = member.decl.as(VariableDeclSyntax.self) {
        // Only process stored properties
        guard varDecl.bindings.first?.accessorBlock == nil else { continue }

        for binding in varDecl.bindings {
          guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
            let typeAnnotation = binding.typeAnnotation?.type
          else {
            continue
          }

          let typeString = typeAnnotation.description.trimmingCharacters(in: .whitespaces)
          let isOptional = typeString.hasSuffix("?")

          properties.append(
            TestPropertyInfo(
              name: pattern.identifier.text,
              type: typeString,
              isOptional: isOptional
            )
          )
        }
      }
    }

    guard !properties.isEmpty else {
      throw TestAllCasesMacroError.noStoredProperties
    }

    return properties
  }

  /// Generate extension for struct/class types
  static func generateStructExtension(
    for typeName: String,
    properties: [TestPropertyInfo],
    focus: TestFocus
  ) throws -> ExtensionDeclSyntax {

    let boundaryTests = try generateBoundaryTests(for: typeName, properties: properties)
    let edgeCaseTests = try generateEdgeCaseTests(for: typeName, properties: properties)
    let typicalTests = try generateTypicalTests(for: typeName, properties: properties)

    let comprehensiveTests = boundaryTests + edgeCaseTests + typicalTests

    let selectedTests: String
    switch focus {
    case .comprehensive:
      selectedTests = "[\(comprehensiveTests.joined(separator: ",\n            "))]"

    case .boundary:
      selectedTests = "[\(boundaryTests.joined(separator: ",\n            "))]"

    case .edges:
      selectedTests = "[\(edgeCaseTests.joined(separator: ",\n            "))]"
    }

    let extensionCode = """
      extension \(typeName): AutoTestable {
          static var comprehensiveTests: [Gen<\(typeName)>] {
              \(selectedTests)
          }
          
          static var boundaryTests: [Gen<\(typeName)>] {
              [\(boundaryTests.joined(separator: ",\n                "))]
          }
          
          static var edgeCaseTests: [Gen<\(typeName)>] {
              [\(edgeCaseTests.joined(separator: ",\n                "))]
          }
      }
      """

    let sourceFile = Parser.parse(source: extensionCode)
    guard let extensionDecl = sourceFile.statements.first?.item.as(ExtensionDeclSyntax.self) else {
      throw TestAllCasesMacroError.generationFailed("Failed to parse generated extension")
    }

    return extensionDecl
  }

  /// Generate extension for enum types
  static func generateEnumExtension(
    for enumDecl: EnumDeclSyntax,
    typeName: String,
    focus: TestFocus
  ) throws -> ExtensionDeclSyntax {

    var cases: [String] = []

    for member in enumDecl.memberBlock.members {
      if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
        for element in caseDecl.elements {
          cases.append(".\(element.name.text)")
        }
      }
    }

    guard !cases.isEmpty else {
      throw TestAllCasesMacroError.noStoredProperties
    }

    let allCasesGenerator =
      "Gen.oneOf([\(cases.map { "Gen.constant(\($0))" }.joined(separator: ", "))])"

    let extensionCode = """
      extension \(typeName): AutoTestable {
          static var comprehensiveTests: [Gen<\(typeName)>] {
              [\(allCasesGenerator)]
          }
          
          static var boundaryTests: [Gen<\(typeName)>] {
              [Gen.constant(\(cases.first!)), Gen.constant(\(cases.last!))]
          }
          
          static var edgeCaseTests: [Gen<\(typeName)>] {
              [\(allCasesGenerator)]
          }
      }
      """

    let sourceFile = Parser.parse(source: extensionCode)
    guard let extensionDecl = sourceFile.statements.first?.item.as(ExtensionDeclSyntax.self) else {
      throw TestAllCasesMacroError.generationFailed("Failed to parse enum extension")
    }

    return extensionDecl
  }

  /// Generate boundary test cases
  static func generateBoundaryTests(
    for typeName: String,
    properties: [TestPropertyInfo]
  ) throws -> [String] {

    var tests: [String] = []

    // Generate tests for each property's boundary values
    for property in properties {
      let boundaryValues = property.boundaryTestCases()

      for value in boundaryValues.prefix(3) {  // Limit to avoid explosion
        let otherValues = properties.filter { $0.name != property.name }
          .map { otherProp in
            let defaultValue = otherProp.boundaryTestCases().first ?? "nil"
            return "\(otherProp.name): \(defaultValue)"
          }

        let allParams = ["\(property.name): \(value)"] + otherValues
        tests.append("Gen.constant(\(typeName)(\(allParams.joined(separator: ", "))))")
      }
    }

    return Array(tests.prefix(10))  // Reasonable limit
  }

  /// Generate edge case test scenarios
  static func generateEdgeCaseTests(
    for typeName: String,
    properties: [TestPropertyInfo]
  ) throws -> [String] {

    var tests: [String] = []

    // Generate edge case combinations
    for property in properties {
      let edgeCases = property.edgeCaseTestCases()

      for edgeCase in edgeCases.prefix(2) {
        let otherValues = properties.filter { $0.name != property.name }
          .map { otherProp in
            let defaultValue = otherProp.boundaryTestCases().first ?? "nil"
            return "\(otherProp.name): \(defaultValue)"
          }

        let allParams = ["\(property.name): \(edgeCase)"] + otherValues
        tests.append("Gen.constant(\(typeName)(\(allParams.joined(separator: ", "))))")
      }
    }

    return Array(tests.prefix(8))  // Reasonable limit
  }

  /// Generate typical value test generators
  static func generateTypicalTests(
    for typeName: String,
    properties: [TestPropertyInfo]
  ) throws -> [String] {

    // Generate combined generator for typical values
    let generators = properties.map { $0.typicalValueGenerator() }

    let zipFunction: String
    let generatorParams = generators.joined(separator: ", ")

    switch properties.count {
    case 1:
      return ["\(generators[0]).map(\(typeName).init)"]

    case 2:
      zipFunction = "Gen.zip"

    case 3:
      zipFunction = "Gen.zip3"

    case 4:
      zipFunction = "Gen.zip4"

    case 5:
      zipFunction = "Gen.zip5"

    default:
      // For more parameters, use chained zip
      var result = "Gen.zip(\(generators[0]), \(generators[1]))"
      for i in 2..<generators.count {
        result = "\(result).zip(\(generators[i]))"
      }
      return [
        "\(result).map { tuple in \(typeName)(\(generators.indices.map { "tuple.\($0)" }.joined(separator: ", "))) }"
      ]
    }

    return ["\(zipFunction)(\(generatorParams)).map(\(typeName).init)"]
  }
}
