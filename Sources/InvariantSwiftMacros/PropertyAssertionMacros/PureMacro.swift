import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro implementation for @Pure.
///
/// Generates a property test verifying f(x) == f(x) across multiple calls.
/// This tests determinism, which is necessary but not sufficient for purity.
///
/// CRITICAL: @Pure cannot detect side effects in Swift. It only verifies
/// determinism. True purity requires manual code review.
///
/// See PureMacroDeclaration.swift for public API documentation.
// swiftlint:disable:next type_body_length
public struct PureMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    let ctx = MacroContext(context: context)

    // Validate declaration is a function
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      ctx.error(PropertyAssertionDiagnostic.mustBeFunction, at: node)
      return []
    }

    // Extract parameters
    let parameters = ParameterExtractor.extract(from: funcDecl)

    guard !parameters.isEmpty else {
      ctx.error(PropertyAssertionDiagnostic.mustHaveParameters, at: funcDecl.signature)
      return []
    }

    // Validate return type is not Void
    guard let returnClause = funcDecl.signature.returnClause else {
      ctx.error(PropertyAssertionDiagnostic.voidReturnNotAllowed, at: funcDecl.signature)
      return []
    }

    // Extract config from macro arguments
    let config = extractConfig(from: node)

    // Check for async
    let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

    // Generate wrapper enum containing the @Test function
    let wrapperEnum = buildWrapperEnum(
      original: funcDecl,
      parameters: parameters,
      returnType: returnClause.type,
      config: config,
      isAsync: isAsync
    )

    return [DeclSyntax(wrapperEnum)]
  }

  // MARK: - Configuration Extraction

  private static func extractConfig(from node: AttributeSyntax) -> PureConfig {
    var iterations = 100
    var callCount = 2

    guard case .argumentList(let args) = node.arguments else {
      return PureConfig(iterations: iterations, callCount: callCount)
    }

    for arg in args {
      if let label = arg.label?.text {
        if label == "iterations",
          let intLiteral = arg.expression.as(IntegerLiteralExprSyntax.self)
        {
          iterations = Int(intLiteral.literal.text) ?? 100
        } else if label == "callCount",
          let intLiteral = arg.expression.as(IntegerLiteralExprSyntax.self)
        {
          callCount = Int(intLiteral.literal.text) ?? 2
        }
      }
    }

    return PureConfig(iterations: iterations, callCount: callCount)
  }

  // MARK: - Wrapper Enum Builder

  // swiftlint:disable:next function_parameter_count
  private static func buildWrapperEnum(
    original funcDecl: FunctionDeclSyntax,
    parameters: [ExtractedParameter],
    returnType: TypeSyntax,
    config: PureConfig,
    isAsync: Bool
  ) -> EnumDeclSyntax {
    let enumName = "\(funcDecl.name.text)_PureTest"
    let testName = funcDecl.name.text

    let testBody = buildPropertyTestBody(
      functionName: funcDecl.name.text,
      parameters: parameters,
      returnType: returnType,
      config: config,
      isAsync: isAsync
    )

    let testFunc = FunctionDeclSyntax(
      attributes: AttributeListSyntax {
        AttributeSyntax(
          attributeName: IdentifierTypeSyntax(name: .identifier("Test")),
          leftParen: .leftParenToken(),
          arguments: .argumentList(
            LabeledExprListSyntax {
              LabeledExprSyntax(expression: StringLiteralExprSyntax(content: testName))
            }
          ),
          rightParen: .rightParenToken()
        )
      },
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.static))
      },
      funcKeyword: .keyword(.func),
      name: .identifier("run"),
      signature: isAsync ? buildAsyncThrowsSignature() : buildThrowsSignature(),
      body: testBody
    )

    return EnumDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.private))
      },
      name: .identifier(enumName),
      memberBlock: MemberBlockSyntax(
        members: MemberBlockItemListSyntax {
          MemberBlockItemSyntax(decl: testFunc)
        }
      )
    )
  }

  // MARK: - Signature Builders

  private static func buildThrowsSignature() -> FunctionSignatureSyntax {
    FunctionSignatureSyntax(
      parameterClause: FunctionParameterClauseSyntax(
        parameters: FunctionParameterListSyntax {}
      ),
      effectSpecifiers: FunctionEffectSpecifiersSyntax(
        throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
      )
    )
  }

  private static func buildAsyncThrowsSignature() -> FunctionSignatureSyntax {
    FunctionSignatureSyntax(
      parameterClause: FunctionParameterClauseSyntax(
        parameters: FunctionParameterListSyntax {}
      ),
      effectSpecifiers: FunctionEffectSpecifiersSyntax(
        asyncSpecifier: .keyword(.async),
        throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
      )
    )
  }

  // MARK: - Property Test Body Builder

  // swiftlint:disable:next function_parameter_count
  private static func buildPropertyTestBody(
    functionName: String,
    parameters: [ExtractedParameter],
    returnType: TypeSyntax,
    config: PureConfig,
    isAsync: Bool
  ) -> CodeBlockSyntax {
    CodeBlockSyntax {
      buildGeneratorDeclaration(parameters: parameters)
      buildPropertyDeclaration(
        functionName: functionName,
        parameters: parameters,
        returnType: returnType,
        config: config,
        isAsync: isAsync
      )
      buildConfigDeclaration(config: config)
      if isAsync {
        buildAsyncResultDeclaration()
      } else {
        buildResultDeclaration()
      }
      buildResultHandling()
    }
  }

  // MARK: - Generator Declaration

  private static func buildGeneratorDeclaration(
    parameters: [ExtractedParameter]
  ) -> VariableDeclSyntax {
    let generators = parameters.map { param in
      GeneratorInference.infer(for: param.type)
    }

    let generatorExpr: ExprSyntax
    if generators.count == 1 {
      generatorExpr = generators[0]
    } else {
      let paramNames = parameters.map { $0.name }
      generatorExpr = buildFlatMapChain(generators, parameterNames: paramNames)
    }

    let typeAnnotation: TypeAnnotationSyntax
    if parameters.count == 1 {
      let genType = "Gen<\(parameters[0].type.description)>"
      typeAnnotation = TypeAnnotationSyntax(
        type: TypeSyntax(stringLiteral: genType)
      )
    } else {
      let tupleTypes = parameters.map { $0.type.description }.joined(separator: ", ")
      let genType = "Gen<(\(tupleTypes))>"
      typeAnnotation = TypeAnnotationSyntax(
        type: TypeSyntax(stringLiteral: genType)
      )
    }

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("generator")),
          typeAnnotation: typeAnnotation,
          initializer: InitializerClauseSyntax(value: generatorExpr)
        )
      }
    )
  }

  private static func buildFlatMapChain(
    _ generators: [ExprSyntax],
    parameterNames: [String]
  ) -> ExprSyntax {
    guard generators.count >= 2 else {
      return generators.first ?? ExprSyntax(stringLiteral: "Gen.pure(())")
    }

    let lastGen = generators.last!
    let lastName = parameterNames.last!
    let tupleExpr = "(\(parameterNames.joined(separator: ", ")))"

    var result = ExprSyntax(stringLiteral: "\(lastGen).map { \(lastName) in \(tupleExpr) }")

    for i in stride(from: generators.count - 2, through: 0, by: -1) {
      let gen = generators[i]
      let name = parameterNames[i]
      result = ExprSyntax(stringLiteral: "\(gen).flatMap { \(name) in \(result) }")
    }

    return result
  }

  // MARK: - Property Declaration

  // swiftlint:disable:next function_parameter_count
  private static func buildPropertyDeclaration(
    functionName: String,
    parameters: [ExtractedParameter],
    returnType: TypeSyntax,
    config: PureConfig,
    isAsync: Bool
  ) -> VariableDeclSyntax {
    let testClosure = buildTestClosure(
      functionName: functionName,
      parameters: parameters,
      config: config,
      isAsync: isAsync
    )

    let propertyInit = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Property")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("generator"),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: .identifier("generator"))
        )
      },
      rightParen: .rightParenToken(),
      trailingClosure: testClosure
    )

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("property")),
          initializer: InitializerClauseSyntax(value: ExprSyntax(propertyInit))
        )
      }
    )
  }

  private static func buildTestClosure(
    functionName: String,
    parameters: [ExtractedParameter],
    config: PureConfig,
    isAsync: Bool
  ) -> ClosureExprSyntax {
    let closureParams = ClosureParameterListSyntax {
      for param in parameters {
        ClosureParameterSyntax(
          firstName: .identifier(param.name),
          colon: .colonToken(),
          type: param.type
        )
      }
    }

    // Build function call arguments
    let funcArgs = parameters.map { $0.name }.joined(separator: ", ")

    // Generate test body: call function multiple times, verify all results match
    let awaitKeyword = isAsync ? "await " : ""

    // For callCount=2 (determinism check):
    // let call1 = f(input)
    // let call2 = f(input)
    // return call1 == call2
    let statements: [String] = [
      "let call1 = \(awaitKeyword)\(functionName)(\(funcArgs))",
      "let call2 = \(awaitKeyword)\(functionName)(\(funcArgs))",
      "return call1 == call2",
    ]

    let bodyCode = statements.joined(separator: "\n")

    return ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .parameterClause(
          ClosureParameterClauseSyntax(parameters: closureParams)
        )
      ),
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(
          item: .expr(ExprSyntax(stringLiteral: bodyCode))
        )
      }
    )
  }

  // MARK: - Config Declaration

  private static func buildConfigDeclaration(config: PureConfig) -> VariableDeclSyntax {
    var arguments: [LabeledExprSyntax] = []

    arguments.append(
      LabeledExprSyntax(
        label: .identifier("iterations"),
        colon: .colonToken(),
        expression: IntegerLiteralExprSyntax(literal: .integerLiteral("\(config.iterations)"))
      )
    )

    arguments.append(
      LabeledExprSyntax(
        label: .identifier("maxShrinks"),
        colon: .colonToken(),
        expression: IntegerLiteralExprSyntax(literal: .integerLiteral("1000"))
      )
    )

    for i in 0..<(arguments.count - 1) {
      arguments[i] = arguments[i].with(\.trailingComma, .commaToken())
    }

    let configCall = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("PropertyConfig")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(arguments),
      rightParen: .rightParenToken()
    )

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("config")),
          initializer: InitializerClauseSyntax(value: ExprSyntax(configCall))
        )
      }
    )
  }

  // MARK: - Result Declaration

  private static func buildResultDeclaration() -> VariableDeclSyntax {
    let checkCall = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("runPropertySynchronously")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          expression: DeclReferenceExprSyntax(baseName: .identifier("property"))
        )
        .with(\.trailingComma, .commaToken())
        LabeledExprSyntax(
          label: .identifier("config"),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: .identifier("config"))
        )
      },
      rightParen: .rightParenToken()
    )

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
          initializer: InitializerClauseSyntax(value: ExprSyntax(checkCall))
        )
      }
    )
  }

  private static func buildAsyncResultDeclaration() -> VariableDeclSyntax {
    let awaitExpr = AwaitExprSyntax(
      expression: FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(
          baseName: .identifier("runPropertyAsync")
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            expression: DeclReferenceExprSyntax(baseName: .identifier("property"))
          )
          .with(\.trailingComma, .commaToken())
          LabeledExprSyntax(
            label: .identifier("config"),
            colon: .colonToken(),
            expression: DeclReferenceExprSyntax(baseName: .identifier("config"))
          )
        },
        rightParen: .rightParenToken()
      )
    )

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
          initializer: InitializerClauseSyntax(value: ExprSyntax(awaitExpr))
        )
      }
    )
  }

  // MARK: - Result Handling

  private static func buildResultHandling() -> SwitchExprSyntax {
    SwitchExprSyntax(
      subject: DeclReferenceExprSyntax(baseName: .identifier("result")),
      cases: SwitchCaseListSyntax {
        buildSuccessCase()
        buildFailureCase()
        buildGaveUpCase()
      }
    )
  }

  private static func buildSuccessCase() -> SwitchCaseSyntax {
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

  private static func buildFailureCase() -> SwitchCaseSyntax {
    let patternExpr = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        period: .periodToken(),
        declName: DeclReferenceExprSyntax(baseName: .identifier("failure"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("counterexample"),
          colon: .colonToken(),
          expression: DiscardAssignmentExprSyntax()
        )
        LabeledExprSyntax(
          label: .identifier("iterations"),
          colon: .colonToken(),
          expression: DiscardAssignmentExprSyntax()
        )
        LabeledExprSyntax(
          label: .identifier("shrunk"),
          colon: .colonToken(),
          expression: DiscardAssignmentExprSyntax()
        )
        LabeledExprSyntax(
          label: .identifier("reason"),
          colon: .colonToken(),
          expression: DiscardAssignmentExprSyntax()
        )
        LabeledExprSyntax(
          label: .identifier("seed"),
          colon: .colonToken(),
          expression: DiscardAssignmentExprSyntax()
        )
      },
      rightParen: .rightParenToken()
    )

    let issueRecord = buildIssueRecordCall("Purity property violated (non-deterministic)")

    return SwitchCaseSyntax(
      label: .case(
        SwitchCaseLabelSyntax(
          caseItems: SwitchCaseItemListSyntax {
            SwitchCaseItemSyntax(
              pattern: ExpressionPatternSyntax(expression: ExprSyntax(patternExpr))
            )
          }
        )
      ),
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(issueRecord))
      }
    )
  }

  private static func buildGaveUpCase() -> SwitchCaseSyntax {
    let patternExpr = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        period: .periodToken(),
        declName: DeclReferenceExprSyntax(baseName: .identifier("gaveUp"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("discarded"),
          colon: .colonToken(),
          expression: DiscardAssignmentExprSyntax()
        )
        LabeledExprSyntax(
          label: .identifier("iterations"),
          colon: .colonToken(),
          expression: DiscardAssignmentExprSyntax()
        )
      },
      rightParen: .rightParenToken()
    )

    let issueRecord = buildIssueRecordCall("Property test gave up")

    return SwitchCaseSyntax(
      label: .case(
        SwitchCaseLabelSyntax(
          caseItems: SwitchCaseItemListSyntax {
            SwitchCaseItemSyntax(
              pattern: ExpressionPatternSyntax(expression: ExprSyntax(patternExpr))
            )
          }
        )
      ),
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(issueRecord))
      }
    )
  }

  private static func buildIssueRecordCall(_ message: String) -> ExprSyntax {
    let commentInit = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Comment")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("stringLiteral"),
          colon: .colonToken(),
          expression: StringLiteralExprSyntax(content: message)
        )
      },
      rightParen: .rightParenToken()
    )

    let issueRecordCall = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("Issue")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("record"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(expression: ExprSyntax(commentInit))
      },
      rightParen: .rightParenToken()
    )

    return ExprSyntax(issueRecordCall)
  }
}

// MARK: - Configuration

private struct PureConfig {
  let iterations: Int
  let callCount: Int
}

// swiftlint:disable:this file_length
