import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import SwiftParser
import Foundation

/// **@BusinessRule macro for generating business-friendly property-based tests**
///
/// This macro transforms business rule functions into property-based tests that integrate
/// seamlessly with Swift Testing while hiding mathematical complexity behind business-friendly APIs.
///
/// **Usage Example:**
/// ```swift
/// @BusinessRule("Discount should never exceed product price")
/// func validateDiscount(product: Product, discount: Discount) -> Bool {
///     return discount.amount <= product.price
/// }
/// ```
///
/// **Generated Code:**
/// The macro generates a corresponding `@Test` function that:
/// 1. Creates appropriate generators for the function parameters using smart inference
/// 2. Runs the property test with business-appropriate configuration
/// 3. Provides clear, actionable error messages for business stakeholders
/// 4. Integrates with Swift Testing's assertion system
///
/// **Mathematical Foundation:**
/// While hidden from users, the implementation leverages property-based testing theory:
/// - ∀ x ∈ Domain, P(x) = true (universal quantification over generated inputs)
/// - Generator composition via functor laws: Gen<T>.map(f) • Gen<T>.map(g) = Gen<T>.map(g • f)
/// - Shrinking via tree traversal for minimal counterexample discovery
///
/// **External References:**
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Software_testing#Property_testing)
/// - [QuickCheck: A Lightweight Tool for Random Testing](https://dl.acm.org/doi/10.1145/351240.351266)
/// - [Shrinking and showing functions](https://dl.acm.org/doi/10.1145/2364527.2364529)
public struct BusinessRuleMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    // Extract function declaration
    let funcDecl: FunctionDeclSyntax
    if let directFunc = declaration as? FunctionDeclSyntax {
      funcDecl = directFunc
    } else if let declSyntax = declaration as? DeclSyntax,
      let wrappedFunc = declSyntax.as(FunctionDeclSyntax.self)
    {
      funcDecl = wrappedFunc
    } else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: MacroExpansionErrorMessage("@BusinessRule can only be applied to functions")
        )
      )
      return []
    }

    // Validate function signature
    guard funcDecl.signature.returnClause?.type.trimmed.description == "Bool" else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: MacroExpansionErrorMessage("@BusinessRule functions must return Bool")
        )
      )
      return []
    }

    guard !funcDecl.signature.parameterClause.parameters.isEmpty else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: MacroExpansionErrorMessage(
            "@BusinessRule requires functions to have at least one parameter"
          )
        )
      )
      return []
    }

    // Extract macro arguments
    let config = try extractBusinessRuleConfig(from: node)

    // Extract function details
    let functionName = funcDecl.name.text
    let parameters = funcDecl.signature.parameterClause.parameters

    // Generate property test function name
    let propertyTestName = "\(functionName)_PropertyTest"

    // Generate generator expressions for parameters
    let generatorExpressions = try generateGeneratorExpressions(for: parameters)

    // Generate the property test function
    let testFunction = try generatePropertyTestFunction(
      functionName: functionName,
      propertyTestName: propertyTestName,
      parameters: parameters,
      generatorExpressions: generatorExpressions,
      config: config
    )

    return [DeclSyntax(testFunction)]
  }
}

// MARK: - Configuration and Error Types

/// **Configuration for BusinessRule macro**
private struct BusinessRuleConfig {
  let description: String
  let iterations: String  // Expression that evaluates to Int (.smart or specific number)
  let timeout: TimeInterval

  init(
    description: String,
    iterations: String = ".smart",
    timeout: TimeInterval = 30.0
  ) {
    self.description = description
    self.iterations = iterations
    self.timeout = timeout
  }
}

/// **Errors that can occur during BusinessRule macro expansion**
public enum BusinessRuleError: Error, CustomStringConvertible {
  case cannotInferParameterType(String)
  case invalidConfiguration(String)
  case invalidDescription

  public var description: String {
    switch self {
    case .cannotInferParameterType(let paramName):
      return
        "Cannot infer generator type for parameter '\(paramName)'. Ensure the parameter type has a smartGen generator available."

    case .invalidConfiguration(let message):
      return "Invalid @BusinessRule configuration: \(message)"

    case .invalidDescription:
      return "@BusinessRule requires a description string as the first argument"
    }
  }
}

/// **Error message type for macro diagnostics**
public struct MacroExpansionErrorMessage: DiagnosticMessage {
  public let message: String
  public let diagnosticID: MessageID
  public let severity: DiagnosticSeverity

  public init(_ message: String) {
    self.message = message
    self.diagnosticID = MessageID(domain: "BusinessRuleMacro", id: "error")
    self.severity = .error
  }
}

// MARK: - Configuration Extraction

/// **Extract BusinessRule configuration from macro arguments**
private func extractBusinessRuleConfig(from node: AttributeSyntax) throws -> BusinessRuleConfig {
  guard case .argumentList(let arguments) = node.arguments else {
    throw BusinessRuleError.invalidDescription
  }

  let args = Array(arguments)
  guard !args.isEmpty else {
    throw BusinessRuleError.invalidDescription
  }

  // Extract description (first argument, required)
  guard let firstArg = args.first,
    let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self)
  else {
    throw BusinessRuleError.invalidDescription
  }

  // Extract the string content (remove quotes)
  let description = stringLiteral.segments.compactMap { segment in
    if case .stringSegment(let content) = segment {
      return content.content.text
    }
    return nil
  }.joined()

  var config = BusinessRuleConfig(description: description)

  // Process remaining labeled arguments
  for argument in args.dropFirst() {
    guard let label = argument.label?.text else { continue }

    switch label {
    case "iterations":
      if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
        config = BusinessRuleConfig(
          description: config.description,
          iterations: memberAccess.declName.baseName.text,
          timeout: config.timeout
        )
      } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
        config = BusinessRuleConfig(
          description: config.description,
          iterations: intLiteral.literal.text,
          timeout: config.timeout
        )
      }

    case "timeout":
      if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
        if let timeout = TimeInterval(floatLiteral.literal.text) {
          config = BusinessRuleConfig(
            description: config.description,
            iterations: config.iterations,
            timeout: timeout
          )
        }
      }

    default:
      break
    }
  }

  return config
}

// MARK: - Generator Expression Generation

/// **Generate generator expressions for function parameters**
private func generateGeneratorExpressions(
  for parameters: FunctionParameterListSyntax
) throws -> [String] {
  return try parameters.map { param in
    let paramName = param.firstName.text
    let paramType = param.type.trimmed.description

    // Try to infer generator from parameter name and type
    let generator = try inferGenerator(for: paramName, type: paramType)
    return generator
  }
}

/// **Infer appropriate generator for parameter based on name and type**
private func inferGenerator(for paramName: String, type: String) throws -> String {
  // Smart generator inference based on parameter names and types

  // If the type has .smartGen available, use it
  if !isBuiltInType(type) {
    return "\(type).smartGen"
  }

  // Built-in type generators based on parameter names
  switch paramName.lowercased() {
  case let name where name.contains("email"):
    return "Gen.email"
  case let name where name.contains("age"):
    return "Gen.age"
  case let name where name.contains("price"), let name where name.contains("amount"):
    return "Gen.currency"
  case let name where name.contains("name"):
    return "Gen.firstName"
  case let name where name.contains("id"):
    return "Gen.uuid.map { $0.uuidString }"
  default:
    break
  }

  // Fallback to type-based generators
  switch type {
  case "Int":
    return "Gen.int"
  case "String":
    return "Gen.string"
  case "Bool":
    return "Gen.bool"
  case "Double":
    return "Gen.double"
  case "UUID":
    return "Gen.uuid"
  case let arrayType where arrayType.hasPrefix("[") && arrayType.hasSuffix("]"):
    let elementType = String(arrayType.dropFirst().dropLast())
    let elementGenerator = try inferGenerator(for: "element", type: elementType)
    return "Gen.array(\(elementGenerator))"
  default:
    throw BusinessRuleError.cannotInferParameterType(paramName)
  }
}

/// **Check if type is a built-in Swift type**
private func isBuiltInType(_ type: String) -> Bool {
  let builtInTypes = ["Int", "String", "Bool", "Double", "Float", "UUID", "Date"]
  return builtInTypes.contains(type) || type.hasPrefix("[") || type.hasPrefix("Optional<")
}

// MARK: - Test Function Generation

/// **Generate the complete property test function**
private func generatePropertyTestFunction(
  functionName: String,
  propertyTestName: String,
  parameters: FunctionParameterListSyntax,
  generatorExpressions: [String],
  config: BusinessRuleConfig
) throws -> FunctionDeclSyntax {

  // Create parameter list for the property predicate
  let parameterNames = parameters.map { $0.firstName.text }
  let parameterTypes = parameters.map { $0.type.trimmed.description }

  // Generate the combined generator expression
  let combinedGenerator: String
  if generatorExpressions.count == 1 {
    combinedGenerator = generatorExpressions[0]
  } else if generatorExpressions.count == 2 {
    combinedGenerator = "Gen.zip(\(generatorExpressions[0]), \(generatorExpressions[1]))"
  } else if generatorExpressions.count == 3 {
    combinedGenerator =
      "Gen.zip(\(generatorExpressions[0]), \(generatorExpressions[1]), \(generatorExpressions[2]))"
  } else {
    // For more than 3 parameters, use nested zip
    var result = "Gen.zip(\(generatorExpressions[0]), \(generatorExpressions[1]))"
    for i in 2..<generatorExpressions.count {
      result = "Gen.zip(\(result), \(generatorExpressions[i]))"
    }
    combinedGenerator = result
  }

  // Generate the predicate expression
  let predicateCall: String
  if parameterNames.count == 1 {
    predicateCall = "\(functionName)(\(parameterNames[0]): value)"
  } else {
    let args = parameterNames.enumerated().map { index, name in
      "\(name): value.\(index)"
    }.joined(separator: ", ")
    predicateCall = "\(functionName)(\(args))"
  }

  // Generate iterations expression
  let iterationsExpr =
    config.iterations == ".smart" ? "PropertyConfig.smartIterations" : config.iterations

  // Generate the complete test function code
  let testCode = """
    @Test("\(config.description)")
    func \(propertyTestName)() async throws {
        let property = Property<\(generatePropertyType(from: parameterTypes))>(
            generator: \(combinedGenerator),
            predicate: { value in
                \(predicateCall)
            }
        )
        
        let config = PropertyConfig(
            iterations: \(iterationsExpr),
            maxShrinks: 1000,
            maxDiscarded: 1000,
            seed: nil
        )
        
        let runner = PropertyRunner()
        let result = await runner.runProperty(property, config: config)
        
        switch result {
        case .success:
            break // Test passes
            
        case .failure(let counterexample, let iterations, let shrunk):
            throw BusinessRuleViolation(
                rule: "\(config.description)",
                counterexample: String(describing: counterexample),
                shrunk: String(describing: shrunk),
                iterations: iterations,
                businessImpact: "Business rule validation failed - this may indicate a logical error in business constraints"
            )
            
        case .gaveUp(let discarded, let iterations):
            throw BusinessRuleGaveUp(
                rule: "\(config.description)",
                discarded: discarded,
                iterations: iterations,
                suggestion: "Consider relaxing generator constraints or providing more specific generators"
            )
        }
    }
    """

  // Parse and return the function
  let sourceFile = Parser.parse(source: testCode)
  guard
    let functionDecl = sourceFile.statements.first?.item.as(DeclSyntax.self)?.as(
      FunctionDeclSyntax.self
    )
  else {
    throw BusinessRuleError.invalidConfiguration("Failed to generate test function")
  }

  return functionDecl
}

/// **Generate the property type for the generator**
private func generatePropertyType(from parameterTypes: [String]) -> String {
  if parameterTypes.count == 1 {
    return parameterTypes[0]
  } else {
    return "(\(parameterTypes.joined(separator: ", ")))"
  }
}
