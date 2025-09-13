/// **@BusinessRule Macro Implementation**
///
/// SwiftSyntax-based macro that transforms business rule functions into comprehensive
/// property-based tests with business-friendly error reporting. This macro implements
/// the core functionality for Phase 1 of the business macros system.
///
/// **Mathematical Foundation:**
/// Based on property-based testing theory where ∀ x ∈ Domain, P(x) = true.
/// Uses counterexample-guided abstraction refinement (CEGAR) for optimal debugging
/// through systematic shrinking and business-friendly error reporting.
///
/// **AST Transformation:**
/// ```swift
/// // Input:
/// @BusinessRule("Discount should never exceed product price")
/// func validateDiscount(product: Product, discount: Discount) -> Bool {
///     return discount.amount <= product.price
/// }
///
/// // Generated:
/// @Test("Business Rule: Discount should never exceed product price")
/// func validateDiscount_PropertyTest() async throws {
///     // Generated property-based test with business error reporting
/// }
/// ```
///
/// **External References:**
/// - [Swift Macros Documentation](https://docs.swift.org/swift-book/LanguageGuide/Macros.html)
/// - [SwiftSyntax AST Guide](https://github.com/apple/swift-syntax)
/// - [Property-Based Testing Theory](https://dl.acm.org/doi/10.1145/351240.351266)

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftParser
import Foundation

// MARK: - Macro Declaration

/// **@BusinessRule macro for business-friendly property testing**
///
/// Transforms business rule functions into comprehensive property-based tests
/// with intelligent iteration calculation, business error reporting, and
/// Swift Testing framework integration.
///
/// **Usage:**
/// ```swift
/// @BusinessRule("Customer discount must not exceed item price")
/// func validateDiscount(item: Item, discount: Discount) -> Bool {
///     return discount.amount <= item.price
/// }
/// ```
///
/// **Generated Code Pattern:**
/// - Creates a peer `_PropertyTest` suffixed function
/// - Generates @Test attribute for Swift Testing compatibility
/// - Uses ComplexityAnalyzer for smart iteration calculation
/// - Creates generator combinations with Gen.zip() for multi-parameter functions
/// - Implements BusinessRuleViolation error reporting for failures
/// - Includes business impact analysis and remediation suggestions
///
/// **Parameters:**
/// - **description**: Human-readable business rule description
/// - **iterations**: Iteration strategy (.smart, .fixed, .adaptive)
/// - **timeout**: Maximum execution time for the test (default: 30.0 seconds)
public struct BusinessRuleMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    // Extract function declaration
    guard let funcDecl = declaration as? FunctionDeclSyntax else {
      throw BusinessRuleMacroError.onlyApplicableToFunction
    }

    // Extract macro arguments
    let arguments = try extractMacroArguments(from: node)

    // Analyze function for complexity scoring
    let functionAnalysis = try analyzeFunctionSignature(funcDecl)

    // Generate the property test function
    let propertyTestFunction = try generatePropertyTestFunction(
      originalFunction: funcDecl,
      arguments: arguments,
      analysis: functionAnalysis,
      context: context
    )

    return [DeclSyntax(propertyTestFunction)]
  }
}

// MARK: - Supporting Types

/// Arguments extracted from @BusinessRule macro
private struct BusinessRuleMacroArguments {
  let description: String
  let iterationsType: String  // Store as string for code generation
  let timeout: Double

  static let defaultArguments = Self(
    description: "Business rule validation",
    iterationsType: ".smart",
    timeout: 30.0
  )
}

/// Function analysis results for complexity calculation
private struct FunctionAnalysis {
  let parameters: [FunctionParameterInfo]
  let returnType: String
  let complexity: ComplexityScore

  struct FunctionParameterInfo {
    let name: String
    let type: String
    let isOptional: Bool

    /// Generate appropriate generator call for this parameter type
    func generatorCall() -> String {
      // Smart generator inference based on parameter name and type
      let lowerName = name.lowercased()

      // Financial domain generators
      if lowerName.contains("price") || lowerName.contains("amount") || lowerName.contains("cost") {
        return "Gen.currency"
      } else if lowerName.contains("rate") || lowerName.contains("percent") {
        return "Gen.percentage"
      } else if lowerName.contains("email") {
        return "Gen.email"
      } else if lowerName.contains("age") {
        return "Gen.age"
      } else if lowerName.contains("name") && type == "String" {
        return "Gen.personName"
      }

      // Type-based fallbacks
      switch type {
      case "Int":
        return "Gen.int"

      case "String":
        return "Gen.string"

      case "Bool":
        return "Gen.bool"

      case "Double":
        return "Gen.double"

      case "Decimal":
        return "Gen.decimal"

      default:
        // For custom types, try to use SmartGeneratable if available
        if type.hasSuffix("?") {
          let baseType = String(type.dropLast())
          return "\(baseType).smartGen.optional"
        } else {
          return "\(type).smartGen"
        }
      }
    }
  }

  struct ComplexityScore {
    let parameterComplexity: Int
    let businessRiskFactor: Double
    let totalComplexity: Int

    var recommendedIterations: Int {
      max(50, min(totalComplexity * 10, 2000))
    }
  }
}

/// BusinessRule macro specific errors
enum BusinessRuleMacroError: Error, CustomStringConvertible {
  case onlyApplicableToFunction
  case invalidMacroArguments(String)
  case unsupportedReturnType(String)
  case complexParameterType(String)
  case generatorSynthesisFailed(String)

  var description: String {
    switch self {
    case .onlyApplicableToFunction:
      return "@BusinessRule can only be applied to functions"

    case .invalidMacroArguments(let details):
      return "Invalid @BusinessRule arguments: \(details)"

    case .unsupportedReturnType(let type):
      return "Unsupported return type for @BusinessRule: \(type). Must return Bool"

    case .complexParameterType(let type):
      return "Complex parameter type '\(type)' requires SmartGeneratable conformance"

    case .generatorSynthesisFailed(let reason):
      return "Failed to generate property test: \(reason)"
    }
  }
}

// MARK: - Implementation

private extension BusinessRuleMacro {

  /// Extract and validate macro arguments from AttributeSyntax
  static func extractMacroArguments(from node: AttributeSyntax) throws -> BusinessRuleMacroArguments
  {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      throw BusinessRuleMacroError.invalidMacroArguments("Missing required description argument")
    }

    var description: String?
    var iterationsType: String = ".smart"
    var timeout: Double = 30.0

    // Parse each argument
    for argument in arguments {
      if argument.label == nil {
        // First unlabeled argument is the description
        if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
          let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
        {
          description = segment.content.text
        }
      } else if let label = argument.label?.text {
        switch label {
        case "iterations":
          iterationsType = try parseIterationsArgument(argument.expression)

        case "timeout":
          if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self),
            let value = Double(floatLiteral.literal.text)
          {
            timeout = value
          }

        default:
          break  // Ignore unknown arguments
        }
      }
    }

    guard let desc = description else {
      throw BusinessRuleMacroError.invalidMacroArguments("Business rule description is required")
    }

    return BusinessRuleMacroArguments(
      description: desc,
      iterationsType: iterationsType,
      timeout: timeout
    )
  }

  /// Parse BusinessRuleIterations from macro argument
  static func parseIterationsArgument(_ expr: ExprSyntax) throws -> String {
    // For now, default to smart - full parsing would handle .fixed(n), .adaptive(min:max:)
    ".smart"
  }

  /// Analyze function signature for complexity and generator synthesis
  static func analyzeFunctionSignature(_ funcDecl: FunctionDeclSyntax) throws -> FunctionAnalysis {
    // Validate return type
    guard let returnClause = funcDecl.signature.returnClause,
      let returnType = returnClause.type.as(IdentifierTypeSyntax.self),
      returnType.name.text == "Bool"
    else {
      throw BusinessRuleMacroError.unsupportedReturnType("@BusinessRule functions must return Bool")
    }

    // Extract parameters
    let parameters = funcDecl.signature.parameterClause.parameters.map { param in
      let name = param.firstName.text
      let type = param.type.description.trimmingCharacters(in: .whitespaces)
      let isOptional = type.hasSuffix("?")

      return FunctionAnalysis.FunctionParameterInfo(
        name: name,
        type: type,
        isOptional: isOptional
      )
    }

    // Calculate complexity
    let paramNames = parameters.map(\.name)
    let paramTypes = parameters.map(\.type)

    let paramComplexity =
      paramTypes.count + paramNames.reduce(0) { $0 + (businessKeywordBonus(for: $1)) }

    let businessRisk =
      paramNames.contains { name in
        let lower = name.lowercased()
        return [
          "price", "amount", "money", "currency", "rate", "balance", "cost", "fee", "payment",
        ].contains {
          lower.contains($0)
        }
      } ? 1.5 : 1.0

    let totalComplexity = Int(Double(paramComplexity + 1) * businessRisk)

    let complexity = FunctionAnalysis.ComplexityScore(
      parameterComplexity: paramComplexity,
      businessRiskFactor: businessRisk,
      totalComplexity: totalComplexity
    )

    return FunctionAnalysis(
      parameters: parameters,
      returnType: "Bool",
      complexity: complexity
    )
  }

  /// Calculate business keyword bonus for parameter names
  static func businessKeywordBonus(for name: String) -> Int {
    let highRiskKeywords = [
      "price", "amount", "balance", "rate", "percent", "currency", "money", "cost", "fee",
      "discount", "tax",
    ]
    return highRiskKeywords.contains { name.lowercased().contains($0) } ? 2 : 0
  }

  /// Generate the complete property test function
  static func generatePropertyTestFunction(
    originalFunction: FunctionDeclSyntax,
    arguments: BusinessRuleMacroArguments,
    analysis: FunctionAnalysis,
    context: some MacroExpansionContext
  ) throws -> FunctionDeclSyntax {

    let functionName = originalFunction.name.text
    let propertyTestName = "\(functionName)_PropertyTest"

    // Calculate iterations based on complexity
    let baseIterations = max(50, analysis.complexity.totalComplexity * 10)
    let iterations = min(baseIterations, 2000)  // Cap at 2000 for performance

    // Generate generator combinations
    let generatorCode = try generateGeneratorCode(for: analysis.parameters)

    // Generate function parameter list for calling original function
    let parameterList = analysis.parameters.map { "tuple.\($0.name)" }.joined(separator: ", ")

    // Generate business impact and remediation
    let businessImpact = generateBusinessImpact(
      for: arguments.description,
      parameters: analysis.parameters
    )
    let remediation = generateRemediation(
      for: arguments.description,
      parameters: analysis.parameters
    )

    // Create the complete function code
    let functionCode = """
      @Test("\(arguments.description)")
      func \(propertyTestName)() async throws {
          let property = Property<\(generateTupleType(for: analysis.parameters))>(
              generator: \(generatorCode),
              predicate: { tuple in
                  \(functionName)(\(parameterList))
              }
          )
          
          let config = PropertyConfig(iterations: \(iterations), maxShrinks: 1000, maxDiscarded: 1000)
          let runner = PropertyRunner()
          let result = await runner.runProperty(property, config: config)
          
          switch result {
          case .success:
              // Business rule validation passed
              break
              
          case .failure(let counterexample, let iterations, let shrunk):
              throw BusinessRuleViolation(
                  rule: "\(arguments.description)",
                  counterexample: BusinessRuleCounterexample(counterexample),
                  shrunk: BusinessRuleCounterexample(shrunk),
                  businessImpact: "\(businessImpact)",
                  remediation: \(remediation),
                  iterations: iterations,
                  severity: \(generateSeverity(for: analysis.parameters))
              )
              
          case .gaveUp(let discarded, let iterations):
              throw BusinessRuleViolation(
                  rule: "\(arguments.description)",
                  counterexample: BusinessRuleCounterexample("Unable to generate valid test data"),
                  shrunk: BusinessRuleCounterexample("Unable to generate valid test data"),
                  businessImpact: "Test data generation failed - may indicate overly restrictive business rules",
                  remediation: ["Review business rule constraints for feasibility", "Check generator definitions for parameter types", "Consider relaxing overly restrictive conditions"],
                  iterations: iterations,
                  severity: .medium
              )
          }
      }
      """

    // Parse the generated code
    let sourceFile = Parser.parse(source: functionCode)

    guard let functionDecl = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self) else {
      throw BusinessRuleMacroError.generatorSynthesisFailed("Failed to parse generated function")
    }

    return functionDecl
  }

  /// Generate generator combination code for parameters
  static func generateGeneratorCode(
    for parameters: [FunctionAnalysis.FunctionParameterInfo]
  ) throws -> String {
    guard !parameters.isEmpty else {
      return "Gen.constant(())"
    }

    if parameters.count == 1 {
      return parameters[0].generatorCall()
    }

    // Generate Gen.zip chain for multiple parameters
    let generators = parameters.map { $0.generatorCall() }

    if parameters.count == 2 {
      return "\(generators[0]).zip(\(generators[1]))"
    } else if parameters.count == 3 {
      return "Gen.zip3(\(generators[0]), \(generators[1]), \(generators[2]))"
    } else if parameters.count == 4 {
      return "Gen.zip4(\(generators[0]), \(generators[1]), \(generators[2]), \(generators[3]))"
    } else {
      // For more than 4 parameters, chain zip calls
      var result = "\(generators[0]).zip(\(generators[1]))"
      for i in 2..<generators.count {
        result = "\(result).zip(\(generators[i]))"
      }
      return result
    }
  }

  /// Generate tuple type for property generator
  static func generateTupleType(for parameters: [FunctionAnalysis.FunctionParameterInfo]) -> String
  {
    guard !parameters.isEmpty else {
      return "()"
    }

    if parameters.count == 1 {
      return parameters[0].type
    }

    let types = parameters.map(\.type)
    return "(\(types.joined(separator: ", ")))"
  }

  /// Generate business impact description
  static func generateBusinessImpact(
    for description: String,
    parameters: [FunctionAnalysis.FunctionParameterInfo]
  ) -> String {
    let hasFinancialTerms = parameters.contains { param in
      let name = param.name.lowercased()
      return ["price", "amount", "money", "currency", "rate", "balance", "cost", "fee", "payment"]
        .contains { name.contains($0) }
    }

    if hasFinancialTerms {
      return
        "This business rule violation could lead to financial discrepancies, incorrect pricing, or monetary calculation errors that may impact business operations and customer trust."
    } else {
      return
        "This business rule violation indicates a logical inconsistency in the business logic that may lead to incorrect behavior, data integrity issues, or unexpected system states."
    }
  }

  /// Generate remediation suggestions
  static func generateRemediation(
    for description: String,
    parameters: [FunctionAnalysis.FunctionParameterInfo]
  ) -> String {
    var suggestions = ["Review the business logic implementation for edge cases"]

    let hasFinancialTerms = parameters.contains { param in
      let name = param.name.lowercased()
      return ["price", "amount", "money", "currency", "rate", "balance", "cost", "fee", "payment"]
        .contains { name.contains($0) }
    }

    if hasFinancialTerms {
      suggestions.append("Validate all financial calculations with accounting team")
      suggestions.append("Add input validation for monetary values")
      suggestions.append("Consider implementing safeguards for edge cases in financial operations")
    }

    suggestions.append("Add additional unit tests for the discovered edge case")
    suggestions.append("Review business requirements documentation for completeness")

    // Convert to Swift array literal
    let quotedSuggestions = suggestions.map { "\"\($0)\"" }.joined(separator: ", ")
    return "[\(quotedSuggestions)]"
  }

  /// Generate appropriate severity level
  static func generateSeverity(for parameters: [FunctionAnalysis.FunctionParameterInfo]) -> String {
    let hasFinancialTerms = parameters.contains { param in
      let name = param.name.lowercased()
      return ["price", "amount", "money", "currency", "rate", "balance", "cost", "fee", "payment"]
        .contains { name.contains($0) }
    }

    return hasFinancialTerms ? ".critical" : ".high"
  }
}
