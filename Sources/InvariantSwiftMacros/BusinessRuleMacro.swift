import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import SwiftParser
import Foundation

public struct BusinessRuleMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    let ctx = MacroContext(context: context)

    guard
      let funcDecl = DeclarationAnalyzer.requireFunction(
        from: declaration,
        context: ctx,
        macroName: "BusinessRule"
      )
    else {
      return []
    }

    guard funcDecl.signature.returnClause?.type.trimmed.description == "Bool" else {
      ctx.error("@BusinessRule functions must return Bool", at: node)
      return []
    }

    guard !funcDecl.signature.parameterClause.parameters.isEmpty else {
      ctx.error(
        "@BusinessRule requires functions to have at least one parameter",
        at: node
      )
      return []
    }

    let config = try extractBusinessRuleConfig(from: node)

    let functionName = funcDecl.name.text
    let parameters = funcDecl.signature.parameterClause.parameters

    let propertyTestName = "\(functionName)_PropertyTest"

    let generatorExpressions = try generateGeneratorExpressions(for: parameters)

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

private struct BusinessRuleConfig {
  let description: String
  let iterations: String
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

private func extractBusinessRuleConfig(from node: AttributeSyntax) throws -> BusinessRuleConfig {
  guard case .argumentList(let arguments) = node.arguments else {
    throw BusinessRuleError.invalidDescription
  }

  let args = Array(arguments)
  guard !args.isEmpty else {
    throw BusinessRuleError.invalidDescription
  }

  guard let firstArg = args.first,
    let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self)
  else {
    throw BusinessRuleError.invalidDescription
  }

  let description = stringLiteral.segments.compactMap { segment in
    if case .stringSegment(let content) = segment {
      return content.content.text
    }
    return nil
  }.joined()

  var config = BusinessRuleConfig(description: description)

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
  try parameters.map { param in
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

        case .failure(let counterexample, let iterations, let shrunk, _, _):
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
