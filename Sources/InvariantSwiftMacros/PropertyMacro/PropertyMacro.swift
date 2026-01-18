import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct PropertyMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    let ctx = MacroContext(context: context)

    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      ctx.error(PropertyMacroDiagnostic.mustBeFunction, at: node)
      return []
    }

    let parameters = ParameterExtractor.extract(from: funcDecl)

    guard !parameters.isEmpty else {
      ctx.error(PropertyMacroDiagnostic.noParameters, at: funcDecl.signature)
      return []
    }

    let config = PropertyConfigExtractor.extract(from: node)

    guard let originalBody = funcDecl.body else {
      return []
    }

    let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

    let transformedFunc = buildTransformedFunction(
      original: funcDecl,
      parameters: parameters,
      originalBody: originalBody,
      config: config,
      isAsync: isAsync
    )

    return [DeclSyntax(transformedFunc)]
  }

  private static func buildTransformedFunction(
    original funcDecl: FunctionDeclSyntax,
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: PropertyMacroConfig,
    isAsync: Bool
  ) -> FunctionDeclSyntax {

    let newName = "\(funcDecl.name.text)_PropertyTest"

    let newBody = buildPropertyTestBody(
      parameters: parameters,
      originalBody: originalBody,
      config: config,
      isAsync: isAsync
    )

    return FunctionDeclSyntax(
      attributes: buildTestAttribute(),
      modifiers: funcDecl.modifiers,
      funcKeyword: .keyword(.func),
      name: .identifier(newName),
      signature: isAsync ? buildAsyncThrowsSignature() : buildThrowsSignature(),
      body: newBody
    )
  }

  private static func buildTestAttribute() -> AttributeListSyntax {
    AttributeListSyntax {
      AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("Test"))
      )
      .with(\.trailingTrivia, .newline)
    }
  }

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

  private static func buildPropertyTestBody(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: PropertyMacroConfig,
    isAsync: Bool
  ) -> CodeBlockSyntax {
    let labels = PropertyFailureFormatter.extractLabels(from: parameters)
    let hasSeed = config.seed != nil

    return CodeBlockSyntax {
      buildGeneratorDeclaration(parameters: parameters)
      buildPropertyDeclaration(parameters: parameters, originalBody: originalBody)
      buildConfigDeclaration(config: config)
      if isAsync {
        buildAsyncResultDeclaration()
      } else {
        buildResultDeclaration()
      }
      buildResultHandling(labels: labels, includeSeed: hasSeed)
    }
  }

  private static func buildGeneratorDeclaration(
    parameters: [ExtractedParameter]
  ) -> VariableDeclSyntax {
    let generators = parameters.map { param -> ExprSyntax in
      if let genAttr = ParameterExtractor.extractGenAttribute(param),
        let parsed = GeneratorDSL.parse(from: genAttr)
      {
        return GeneratorDSL.generateCode(for: parsed)
      }
      return GeneratorInference.infer(for: param.type)
    }

    let generatorExpr: ExprSyntax
    if generators.count == 1 {
      generatorExpr = generators[0]
    } else {
      generatorExpr = buildZipExpression(generators)
    }

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("generator")),
          initializer: InitializerClauseSyntax(value: generatorExpr)
        )
      }
    )
  }

  private static func buildZipExpression(_ generators: [ExprSyntax]) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("zip"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          for gen in generators {
            LabeledExprSyntax(expression: gen)
          }
        },
        rightParen: .rightParenToken()
      )
    )
  }

  private static func buildPropertyDeclaration(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax
  ) -> VariableDeclSyntax {
    let testClosure = buildTestClosure(parameters: parameters, body: originalBody)

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
    parameters: [ExtractedParameter],
    body: CodeBlockSyntax
  ) -> ClosureExprSyntax {
    let paramNames = parameters.map(\.name)

    let closureParam: ClosureSignatureSyntax.ParameterClause
    if paramNames.count == 1 {
      closureParam = .simpleInput(
        ClosureShorthandParameterListSyntax {
          ClosureShorthandParameterSyntax(name: .identifier(paramNames[0]))
        }
      )
    } else {
      closureParam = .simpleInput(
        ClosureShorthandParameterListSyntax {
          for name in paramNames {
            ClosureShorthandParameterSyntax(name: .identifier(name))
          }
        }
      )
    }

    return ClosureExprSyntax(
      signature: ClosureSignatureSyntax(parameterClause: closureParam),
      statements: CodeBlockItemListSyntax {
        for statement in body.statements {
          statement
        }
        ReturnStmtSyntax(expression: BooleanLiteralExprSyntax(booleanLiteral: true))
      }
    )
  }

  private static func buildConfigDeclaration(config: PropertyMacroConfig) -> VariableDeclSyntax {
    var arguments: [LabeledExprSyntax] = [
      LabeledExprSyntax(
        label: .identifier("iterations"),
        colon: .colonToken(),
        expression: IntegerLiteralExprSyntax(literal: .integerLiteral("\(config.iterations)"))
      ),
      LabeledExprSyntax(
        label: .identifier("maxShrinks"),
        colon: .colonToken(),
        expression: IntegerLiteralExprSyntax(literal: .integerLiteral("\(config.maxShrinks)"))
      ),
    ]

    if let seed = config.seed {
      let seedExpr = FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Seed")),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            label: .identifier("value"),
            colon: .colonToken(),
            expression: IntegerLiteralExprSyntax(literal: .integerLiteral("\(seed)"))
          )
        },
        rightParen: .rightParenToken()
      )
      arguments.append(
        LabeledExprSyntax(
          label: .identifier("seed"),
          colon: .colonToken(),
          expression: ExprSyntax(seedExpr)
        )
      )
    }

    if config.verbose {
      arguments.append(
        LabeledExprSyntax(
          label: .identifier("verbose"),
          colon: .colonToken(),
          expression: BooleanLiteralExprSyntax(booleanLiteral: true)
        )
      )
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

  private static func buildResultDeclaration() -> VariableDeclSyntax {
    let checkCall = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("runPropertySynchronously")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("property")))
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
          LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("property")))
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

  private static func buildResultHandling(labels: [String], includeSeed: Bool) -> SwitchExprSyntax {
    SwitchExprSyntax(
      subject: DeclReferenceExprSyntax(baseName: .identifier("result")),
      cases: SwitchCaseListSyntax {
        buildSuccessCase()
        buildFailureCase(labels: labels, includeSeed: includeSeed)
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

  private static func buildFailureCase(labels: [String], includeSeed: Bool) -> SwitchCaseSyntax {
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
          label: .identifier("reason"),
          colon: .colonToken(),
          expression: PatternExprSyntax(
            pattern: ValueBindingPatternSyntax(
              bindingSpecifier: .keyword(.let),
              pattern: IdentifierPatternSyntax(identifier: .identifier("reason"))
            )
          )
        )
        LabeledExprSyntax(
          label: .identifier("seed"),
          colon: .colonToken(),
          expression: PatternExprSyntax(
            pattern: ValueBindingPatternSyntax(
              bindingSpecifier: .keyword(.let),
              pattern: IdentifierPatternSyntax(identifier: .identifier("seed"))
            )
          )
        )
      },
      rightParen: .rightParenToken()
    )

    let issueRecord = PropertyFailureFormatter.buildFormattedIssueRecord(
      labels: labels,
      includeSeed: includeSeed
    )

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

    let issueRecord = buildIssueRecordCall("gaveUp", includeCounterexample: false)

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

  private static func buildIssueRecordCall(
    _ messageType: String,
    includeCounterexample: Bool
  ) -> ExprSyntax {
    let commentInit = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Comment")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("stringLiteral"),
          colon: .colonToken(),
          expression: StringLiteralExprSyntax(content: "Property test \(messageType)")
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

public struct PropertyTestMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try PropertyMacro.expansion(of: node, providingPeersOf: declaration, in: context)
  }
}

public enum PropertyTestError: Error, CustomStringConvertible {
  case onlyApplicableToFunction
  case noParameters
  case cannotInferParameterType(String)
  case invalidConfiguration(String)

  public var description: String {
    switch self {
    case .onlyApplicableToFunction:
      return "@PropertyTest can only be applied to functions"

    case .noParameters:
      return "@PropertyTest requires functions to have at least one parameter"

    case .cannotInferParameterType(let paramName):
      return "Cannot infer generator type for parameter '\(paramName)'"

    case .invalidConfiguration(let message):
      return "Invalid @PropertyTest configuration: \(message)"
    }
  }
}
