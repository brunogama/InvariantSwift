import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

public struct BusinessRuleMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    let ctx = MacroContext(context: context)

    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      ctx.error(BusinessRuleDiagnostic.mustBeFunction, at: node)
      return []
    }

    guard funcDecl.signature.returnClause?.type.trimmed.description == "Bool" else {
      ctx.error(BusinessRuleDiagnostic.mustReturnBool, at: node)
      return []
    }

    guard !funcDecl.signature.parameterClause.parameters.isEmpty else {
      ctx.error(BusinessRuleDiagnostic.noParameters, at: node)
      return []
    }

    guard let config = extractBusinessRuleConfig(from: node, context: ctx) else {
      // Diagnostic already emitted by extractBusinessRuleConfig
      return []
    }

    let functionName = funcDecl.name.text
    let parameters = funcDecl.signature.parameterClause.parameters

    let propertyTestName = "\(functionName)_PropertyTest"

    guard
      let generatorExpressions = generateGeneratorExpressions(
        for: parameters,
        context: ctx,
        node: node
      )
    else {
      // Diagnostic already emitted by generateGeneratorExpressions
      return []
    }

    let testFunction = generatePropertyTestFunction(
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

public enum BusinessRuleDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.BusinessRuleMacro"

  case mustBeFunction = "must_be_function"
  case mustReturnBool = "must_return_bool"
  case noParameters = "no_parameters"
  case missingDescription = "missing_description"
  case invalidDescription = "invalid_description"
  case cannotInferGenerator = "cannot_infer_generator"

  public var severity: DiagnosticSeverity { .error }

  public var message: String {
    switch self {
    case .mustBeFunction:
      return "@BusinessRule can only be applied to functions"

    case .mustReturnBool:
      return "@BusinessRule functions must return Bool"

    case .noParameters:
      return "@BusinessRule requires at least one parameter to generate test values"

    case .missingDescription:
      return "@BusinessRule requires a description string as the first argument"

    case .invalidDescription:
      return "@BusinessRule description must be a string literal"

    case .cannotInferGenerator:
      return
        // swiftlint:disable:next line_length
        "Cannot infer generator for parameter type. Ensure the type conforms to Generatable or use a built-in type."
    }
  }
}

// Legacy error type for backward compatibility
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

// swiftlint:disable:next cyclomatic_complexity
private func extractBusinessRuleConfig(
  from node: AttributeSyntax,
  context: MacroContext
) -> BusinessRuleConfig? {
  guard case .argumentList(let arguments) = node.arguments else {
    context.error(BusinessRuleDiagnostic.missingDescription, at: node)
    return nil
  }

  let args = Array(arguments)
  guard !args.isEmpty else {
    context.error(BusinessRuleDiagnostic.missingDescription, at: node)
    return nil
  }

  guard let firstArg = args.first,
    let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self)
  else {
    context.error(BusinessRuleDiagnostic.invalidDescription, at: node)
    return nil
  }

  let description = stringLiteral.segments.compactMap { segment in
    if case .stringSegment(let content) = segment {
      return content.content.text
    }
    return nil
    // swiftlint:disable:next multiline_function_chains
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
  for parameters: FunctionParameterListSyntax,
  context: MacroContext,
  node: AttributeSyntax
) -> [String]? {
  var expressions: [String] = []

  for param in parameters {
    let paramName = param.firstName.text
    let paramType = param.type.trimmed.description

    // Try to infer generator from parameter name and type
    if let generator = inferGenerator(for: paramName, type: paramType) {
      expressions.append(generator)
    } else {
      context.error(BusinessRuleDiagnostic.cannotInferGenerator, at: node)
      return nil
    }
  }

  return expressions
}

// swiftlint:disable:next cyclomatic_complexity
private func inferGenerator(for paramName: String, type: String) -> String? {
  // Custom types use Generatable.arbitrary (from @Arbitrary macro)
  if !isBuiltInType(type) {
    return "\(type).arbitrary"
  }

  // Built-in type generators based on parameter names
  switch paramName.lowercased() {
  case let name where name.contains("email"):
    return "Gen<String>.email"

  case let name where name.contains("age"):
    return "Gen<Int>.age"

  case let name where name.contains("price"), let name where name.contains("amount"):
    return "Gen<Decimal>.currency"

  case let name where name.contains("name"):
    return "Gen<String>.firstName"

  case let name where name.contains("id"):
    return "Gen<UUID>.uuid.map { $0.uuidString }"

  default:
    break
  }

  // Fallback to type-based generators
  switch type {
  case "Int":
    return "Gen<Int>.int"

  case "String":
    return "Gen<String>.string"

  case "Bool":
    return "Gen<Bool>.bool"

  case "Double":
    return "Gen<Double>.double"

  case "Float":
    return "Gen<Float>.float"

  case "UUID":
    return "Gen<UUID>.uuid"

  case "Decimal":
    return "Gen<Decimal>.currency"

  case let arrayType where arrayType.hasPrefix("[") && arrayType.hasSuffix("]"):
    let elementType = String(arrayType.dropFirst().dropLast())
    if let elementGenerator = inferGenerator(for: "element", type: elementType) {
      return "Gen.array(\(elementGenerator))"
    }
    return nil

  case let optionalType where optionalType.hasPrefix("Optional<"):
    let innerType = String(optionalType.dropFirst(9).dropLast())
    if let innerGenerator = inferGenerator(for: paramName, type: innerType) {
      return "Gen.optional(\(innerGenerator))"
    }
    return nil

  default:
    return nil
  }
}

/// **Check if type is a built-in Swift type**
private func isBuiltInType(_ type: String) -> Bool {
  let builtInTypes = ["Int", "String", "Bool", "Double", "Float", "UUID", "Date"]
  return builtInTypes.contains(type) || type.hasPrefix("[") || type.hasPrefix("Optional<")
}

// MARK: - Test Function Generation (SwiftSyntax Builders)

// swiftlint:disable:next function_parameter_count
private func generatePropertyTestFunction(
  functionName: String,
  propertyTestName: String,
  parameters: FunctionParameterListSyntax,
  generatorExpressions: [String],
  config: BusinessRuleConfig
) -> FunctionDeclSyntax {

  let parameterNames = parameters.map { $0.firstName.text }
  let parameterTypes = parameters.map { $0.type.trimmed.description }

  return FunctionDeclSyntax(
    attributes: buildTestAttribute(description: config.description),
    funcKeyword: .keyword(.func),
    name: .identifier(propertyTestName),
    signature: FunctionSignatureSyntax(
      parameterClause: FunctionParameterClauseSyntax(parameters: []),
      effectSpecifiers: FunctionEffectSpecifiersSyntax(
        asyncSpecifier: .keyword(.async),
        throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
      )
    ),
    body: buildTestBody(
      functionName: functionName,
      parameterNames: parameterNames,
      parameterTypes: parameterTypes,
      generatorExpressions: generatorExpressions,
      config: config
    )
  )
}

private func buildTestAttribute(description: String) -> AttributeListSyntax {
  AttributeListSyntax {
    AttributeSyntax(
      attributeName: IdentifierTypeSyntax(name: .identifier("Test")),
      leftParen: .leftParenToken(),
      arguments: .argumentList(
        LabeledExprListSyntax {
          LabeledExprSyntax(expression: StringLiteralExprSyntax(content: description))
        }
      ),
      rightParen: .rightParenToken()
    )
    .with(\.trailingTrivia, .newline)
  }
}

// swiftlint:disable:next function_parameter_count
private func buildTestBody(
  functionName: String,
  parameterNames: [String],
  parameterTypes: [String],
  generatorExpressions: [String],
  config: BusinessRuleConfig
) -> CodeBlockSyntax {
  CodeBlockSyntax {
    buildPropertyDecl(
      parameterTypes: parameterTypes,
      generatorExpressions: generatorExpressions,
      functionName: functionName,
      parameterNames: parameterNames
    )
    buildConfigDecl(config: config)
    buildRunnerDecl()
    buildResultDecl()
    buildResultSwitch(config: config)
  }
}

private func buildPropertyDecl(
  parameterTypes: [String],
  generatorExpressions: [String],
  functionName: String,
  parameterNames: [String]
) -> VariableDeclSyntax {
  let propertyType =
    parameterTypes.count == 1
    ? parameterTypes[0]
    : "(\(parameterTypes.joined(separator: ", ")))"

  let generatorExpr = buildCombinedGenerator(generatorExpressions)
  let predicateClosure = buildPredicateClosure(
    functionName: functionName,
    parameterNames: parameterNames
  )

  return VariableDeclSyntax(
    bindingSpecifier: .keyword(.let),
    bindings: PatternBindingListSyntax {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier("property")),
        initializer: InitializerClauseSyntax(
          value: FunctionCallExprSyntax(
            calledExpression: GenericSpecializationExprSyntax(
              expression: DeclReferenceExprSyntax(baseName: .identifier("Property")),
              genericArgumentClause: GenericArgumentClauseSyntax {
                GenericArgumentSyntax(
                  argument: .init(IdentifierTypeSyntax(name: .identifier(propertyType)))
                )
              }
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
              LabeledExprSyntax(
                label: .identifier("generator"),
                colon: .colonToken(),
                expression: generatorExpr
              )
              LabeledExprSyntax(
                label: .identifier("predicate"),
                colon: .colonToken(),
                expression: predicateClosure
              )
            },
            rightParen: .rightParenToken()
          )
        )
      )
    }
  )
}

private func buildCombinedGenerator(_ expressions: [String]) -> ExprSyntax {
  if expressions.count == 1 {
    return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(expressions[0])))
  }

  var args = LabeledExprListSyntax()
  for (index, expr) in expressions.enumerated() {
    let isLast = index == expressions.count - 1
    args.append(
      LabeledExprSyntax(
        expression: DeclReferenceExprSyntax(baseName: .identifier(expr)),
        trailingComma: isLast ? nil : .commaToken()
      )
    )
  }

  return ExprSyntax(
    FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("zip"))
      ),
      leftParen: .leftParenToken(),
      arguments: args,
      rightParen: .rightParenToken()
    )
  )
}

private func buildPredicateClosure(
  functionName: String,
  parameterNames: [String]
) -> ClosureExprSyntax {
  let callArgs: LabeledExprListSyntax
  if parameterNames.count == 1 {
    callArgs = LabeledExprListSyntax {
      LabeledExprSyntax(
        label: .identifier(parameterNames[0]),
        colon: .colonToken(),
        expression: DeclReferenceExprSyntax(baseName: .identifier("value"))
      )
    }
  } else {
    var args = LabeledExprListSyntax()
    for (index, name) in parameterNames.enumerated() {
      let isLast = index == parameterNames.count - 1
      args.append(
        LabeledExprSyntax(
          label: .identifier(name),
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("value")),
            declName: DeclReferenceExprSyntax(baseName: .identifier("\(index)"))
          ),
          trailingComma: isLast ? nil : .commaToken()
        )
      )
    }
    callArgs = args
  }

  return ClosureExprSyntax(
    signature: ClosureSignatureSyntax(
      parameterClause: .simpleInput(
        ClosureShorthandParameterListSyntax {
          ClosureShorthandParameterSyntax(name: .identifier("value"))
        }
      )
    ),
    statements: CodeBlockItemListSyntax {
      FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: .identifier(functionName)),
        leftParen: .leftParenToken(),
        arguments: callArgs,
        rightParen: .rightParenToken()
      )
    }
  )
}

private func buildConfigDecl(config: BusinessRuleConfig) -> VariableDeclSyntax {
  let iterationsExpr: ExprSyntax =
    config.iterations == ".smart"
    ? ExprSyntax(
      MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("PropertyConfig")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("smartIterations"))
      )
    )
    : ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral(config.iterations)))

  return VariableDeclSyntax(
    bindingSpecifier: .keyword(.let),
    bindings: PatternBindingListSyntax {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier("config")),
        initializer: InitializerClauseSyntax(
          value: FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("PropertyConfig")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
              LabeledExprSyntax(
                label: .identifier("iterations"),
                colon: .colonToken(),
                expression: iterationsExpr
              )
              LabeledExprSyntax(
                label: .identifier("maxShrinks"),
                colon: .colonToken(),
                expression: IntegerLiteralExprSyntax(literal: .integerLiteral("1000"))
              )
              LabeledExprSyntax(
                label: .identifier("maxDiscarded"),
                colon: .colonToken(),
                expression: IntegerLiteralExprSyntax(literal: .integerLiteral("1000"))
              )
              LabeledExprSyntax(
                label: .identifier("seed"),
                colon: .colonToken(),
                expression: NilLiteralExprSyntax()
              )
            },
            rightParen: .rightParenToken()
          )
        )
      )
    }
  )
}

private func buildRunnerDecl() -> VariableDeclSyntax {
  VariableDeclSyntax(
    bindingSpecifier: .keyword(.let),
    bindings: PatternBindingListSyntax {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier("runner")),
        initializer: InitializerClauseSyntax(
          value: FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("PropertyRunner")),
            leftParen: .leftParenToken(),
            arguments: [],
            rightParen: .rightParenToken()
          )
        )
      )
    }
  )
}

private func buildResultDecl() -> VariableDeclSyntax {
  VariableDeclSyntax(
    bindingSpecifier: .keyword(.let),
    bindings: PatternBindingListSyntax {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
        initializer: InitializerClauseSyntax(
          value: AwaitExprSyntax(
            expression: FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("runner")),
                declName: DeclReferenceExprSyntax(baseName: .identifier("runProperty"))
              ),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                  expression: DeclReferenceExprSyntax(baseName: .identifier("property"))
                )
                LabeledExprSyntax(
                  label: .identifier("config"),
                  colon: .colonToken(),
                  expression: DeclReferenceExprSyntax(baseName: .identifier("config"))
                )
              },
              rightParen: .rightParenToken()
            )
          )
        )
      )
    }
  )
}

private func buildResultSwitch(config: BusinessRuleConfig) -> SwitchExprSyntax {
  SwitchExprSyntax(
    subject: DeclReferenceExprSyntax(baseName: .identifier("result")),
    cases: SwitchCaseListSyntax {
      buildSuccessCase()
      buildFailureCase(config: config).with(\.leadingTrivia, .newlines(2))
      buildGaveUpCase(config: config).with(\.leadingTrivia, .newlines(2))
    }
  )
}

private func buildSuccessCase() -> SwitchCaseSyntax {
  SwitchCaseSyntax(
    label: .case(
      SwitchCaseLabelSyntax(
        caseItems: SwitchCaseItemListSyntax {
          SwitchCaseItemSyntax(
            pattern: ExpressionPatternSyntax(
              expression: MemberAccessExprSyntax(
                period: .periodToken(),
                declName: DeclReferenceExprSyntax(baseName: .identifier("success"))
              )
            )
          )
        }
      )
    ),
    statements: CodeBlockItemListSyntax {
      BreakStmtSyntax()
    }
  )
}

// swiftlint:disable:next function_body_length
private func buildFailureCase(config: BusinessRuleConfig) -> SwitchCaseSyntax {
  SwitchCaseSyntax(
    label: .case(
      SwitchCaseLabelSyntax(
        caseItems: SwitchCaseItemListSyntax {
          SwitchCaseItemSyntax(
            pattern: ExpressionPatternSyntax(
              expression: FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                  period: .periodToken(),
                  declName: DeclReferenceExprSyntax(baseName: .identifier("failure"))
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                  LabeledExprSyntax(
                    label: .identifier("counterexample"),
                    colon: .colonToken(),
                    expression: PatternExprSyntax(
                      pattern: ValueBindingPatternSyntax(
                        bindingSpecifier: .keyword(.let),
                        pattern: IdentifierPatternSyntax(identifier: .identifier("counterexample"))
                      )
                    )
                  )
                  LabeledExprSyntax(
                    label: .identifier("iterations"),
                    colon: .colonToken(),
                    expression: PatternExprSyntax(
                      pattern: ValueBindingPatternSyntax(
                        bindingSpecifier: .keyword(.let),
                        pattern: IdentifierPatternSyntax(identifier: .identifier("iterations"))
                      )
                    )
                  )
                  LabeledExprSyntax(
                    label: .identifier("shrunk"),
                    colon: .colonToken(),
                    expression: PatternExprSyntax(
                      pattern: ValueBindingPatternSyntax(
                        bindingSpecifier: .keyword(.let),
                        pattern: IdentifierPatternSyntax(identifier: .identifier("shrunk"))
                      )
                    )
                  )
                  LabeledExprSyntax(
                    label: .identifier("_"),
                    colon: .colonToken(),
                    expression: DiscardAssignmentExprSyntax()
                  )
                  LabeledExprSyntax(
                    label: .identifier("_"),
                    colon: .colonToken(),
                    expression: DiscardAssignmentExprSyntax()
                  )
                },
                rightParen: .rightParenToken()
              )
            )
          )
        }
      )
    ),
    statements: CodeBlockItemListSyntax {
      ThrowStmtSyntax(
        expression: FunctionCallExprSyntax(
          calledExpression: DeclReferenceExprSyntax(baseName: .identifier("BusinessRuleViolation")),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              label: .identifier("rule"),
              colon: .colonToken(),
              expression: StringLiteralExprSyntax(content: config.description)
            )
            LabeledExprSyntax(
              label: .identifier("counterexample"),
              colon: .colonToken(),
              expression: FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("String")),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                  LabeledExprSyntax(
                    label: .identifier("describing"),
                    colon: .colonToken(),
                    expression: DeclReferenceExprSyntax(baseName: .identifier("counterexample"))
                  )
                },
                rightParen: .rightParenToken()
              )
            )
            LabeledExprSyntax(
              label: .identifier("shrunk"),
              colon: .colonToken(),
              expression: FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("String")),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                  LabeledExprSyntax(
                    label: .identifier("describing"),
                    colon: .colonToken(),
                    expression: DeclReferenceExprSyntax(baseName: .identifier("shrunk"))
                  )
                },
                rightParen: .rightParenToken()
              )
            )
            LabeledExprSyntax(
              label: .identifier("iterations"),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .identifier("iterations"))
            )
            LabeledExprSyntax(
              label: .identifier("businessImpact"),
              colon: .colonToken(),
              expression: StringLiteralExprSyntax(
                content:
                  // swiftlint:disable:next line_length
                  "Business rule validation failed - this may indicate a logical error in business constraints"
              )
            )
          },
          rightParen: .rightParenToken()
        )
      )
    }
  )
}

// swiftlint:disable:next function_body_length
private func buildGaveUpCase(config: BusinessRuleConfig) -> SwitchCaseSyntax {
  SwitchCaseSyntax(
    label: .case(
      SwitchCaseLabelSyntax(
        caseItems: SwitchCaseItemListSyntax {
          SwitchCaseItemSyntax(
            pattern: ExpressionPatternSyntax(
              expression: FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                  period: .periodToken(),
                  declName: DeclReferenceExprSyntax(baseName: .identifier("gaveUp"))
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                  LabeledExprSyntax(
                    label: .identifier("discarded"),
                    colon: .colonToken(),
                    expression: PatternExprSyntax(
                      pattern: ValueBindingPatternSyntax(
                        bindingSpecifier: .keyword(.let),
                        pattern: IdentifierPatternSyntax(identifier: .identifier("discarded"))
                      )
                    )
                  )
                  LabeledExprSyntax(
                    label: .identifier("iterations"),
                    colon: .colonToken(),
                    expression: PatternExprSyntax(
                      pattern: ValueBindingPatternSyntax(
                        bindingSpecifier: .keyword(.let),
                        pattern: IdentifierPatternSyntax(identifier: .identifier("iterations"))
                      )
                    )
                  )
                },
                rightParen: .rightParenToken()
              )
            )
          )
        }
      )
    ),
    statements: CodeBlockItemListSyntax {
      ThrowStmtSyntax(
        expression: FunctionCallExprSyntax(
          calledExpression: DeclReferenceExprSyntax(baseName: .identifier("BusinessRuleGaveUp")),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              label: .identifier("rule"),
              colon: .colonToken(),
              expression: StringLiteralExprSyntax(content: config.description)
            )
            LabeledExprSyntax(
              label: .identifier("discarded"),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .identifier("discarded"))
            )
            LabeledExprSyntax(
              label: .identifier("iterations"),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .identifier("iterations"))
            )
            LabeledExprSyntax(
              label: .identifier("suggestion"),
              colon: .colonToken(),
              expression: StringLiteralExprSyntax(
                content:
                  "Consider relaxing generator constraints or providing more specific generators"
              )
            )
          },
          rightParen: .rightParenToken()
        )
      )
    }
  )
}

private func generatePropertyType(from parameterTypes: [String]) -> String {
  if parameterTypes.count == 1 {
    return parameterTypes[0]
  } else {
    return "(\(parameterTypes.joined(separator: ", ")))"
  }
  // swiftlint:disable:next file_length
}
