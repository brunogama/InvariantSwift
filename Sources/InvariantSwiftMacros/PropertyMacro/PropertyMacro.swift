import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// swiftlint:disable:next type_body_length
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

    // Generate a wrapper enum containing the @Test function
    // This provides proper scope for @Test's internal symbol generation,
    // avoiding the peer+peer macro conflict
    let wrapperEnum = buildWrapperEnum(
      original: funcDecl,
      parameters: parameters,
      originalBody: originalBody,
      config: config,
      isAsync: isAsync
    )

    return [DeclSyntax(wrapperEnum)]
  }

  /// Builds a wrapper enum containing the @Test function
  /// The enum provides proper scope for @Test's internal symbols
  private static func buildWrapperEnum(
    original funcDecl: FunctionDeclSyntax,
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: PropertyMacroConfig,
    isAsync: Bool
  ) -> EnumDeclSyntax {
    let enumName = "\(funcDecl.name.text)_PropertyTest"
    let testName = funcDecl.name.text

    let testBody = buildPropertyTestBody(
      parameters: parameters,
      originalBody: originalBody,
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

    // Preserve original modifiers (do not auto-add static to support file-scope tests)
    let modifiers = funcDecl.modifiers

    return FunctionDeclSyntax(
      attributes: buildTestAttribute(),
      modifiers: modifiers,
      funcKeyword: .keyword(.func),
      name: .identifier(newName),
      signature: isAsync ? buildAsyncThrowsSignature() : buildThrowsSignature(),
      body: newBody
    )
  }

  private static func buildTestAttribute() -> AttributeListSyntax {
    // NOTE: We do NOT generate @Test here because combining peer macros
    // (PropertyMacro generates peer + @Test generates peer) causes
    // Swift symbol resolution failures.
    // Users should wrap calls to the generated function with @Test manually:
    //   @Test func myTest() throws { try myProperty_PropertyTest() }
    AttributeListSyntax {}
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
      let paramNames = parameters.map { $0.name }
      generatorExpr = buildFlatMapChain(generators, parameterNames: paramNames)
    }

    // Build explicit type annotation: Gen<(T1, T2, ...)> or Gen<T>
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

  /// Builds a flatMap chain for multiple generators.
  /// For 2 generators: gen1.flatMap { a in gen2.map { b in (a, b) } }
  /// For 3 generators: gen1.flatMap { a in gen2.flatMap { b in gen3.map { c in (a, b, c) } } }
  private static func buildFlatMapChain(
    _ generators: [ExprSyntax],
    parameterNames: [String]
  ) -> ExprSyntax {
    guard generators.count >= 2 else {
      return generators.first ?? ExprSyntax(stringLiteral: "Gen.pure(())")
    }

    // Build from right to left
    // Start with innermost map
    let lastGen = generators.last!
    let lastName = parameterNames.last!
    let tupleExpr = "(\(parameterNames.joined(separator: ", ")))"

    // Build innermost: lastGen.map { lastName in tupleExpr }
    var result = ExprSyntax(stringLiteral: "\(lastGen).map { \(lastName) in \(tupleExpr) }")

    // Build outward with flatMaps
    for i in stride(from: generators.count - 2, through: 0, by: -1) {
      let gen = generators[i]
      let name = parameterNames[i]
      result = ExprSyntax(stringLiteral: "\(gen).flatMap { \(name) in \(result) }")
    }

    return result
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
    // Use explicit parameter types for proper type inference
    let closureParams = ClosureParameterListSyntax {
      for param in parameters {
        ClosureParameterSyntax(
          firstName: .identifier(param.name),
          colon: .colonToken(),
          type: param.type
        )
      }
    }

    return ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .parameterClause(
          ClosureParameterClauseSyntax(parameters: closureParams)
        )
      ),
      statements: CodeBlockItemListSyntax {
        for statement in body.statements {
          statement
        }
        ReturnStmtSyntax(expression: BooleanLiteralExprSyntax(booleanLiteral: true))
      }
    )
  }

  // swiftlint:disable:next function_body_length
  private static func buildConfigDeclaration(config: PropertyMacroConfig) -> VariableDeclSyntax {
    var arguments: [LabeledExprSyntax] = []

    // Add iterations argument
    arguments.append(
      LabeledExprSyntax(
        label: .identifier("iterations"),
        colon: .colonToken(),
        expression: IntegerLiteralExprSyntax(literal: .integerLiteral("\(config.iterations)"))
      )
    )

    // Add maxShrinks argument
    arguments.append(
      LabeledExprSyntax(
        label: .identifier("maxShrinks"),
        colon: .colonToken(),
        expression: IntegerLiteralExprSyntax(literal: .integerLiteral("\(config.maxShrinks)"))
      )
    )

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

    // Add trailing commas to all but the last argument
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

  // swiftlint:disable:next function_body_length
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
// swiftlint:disable:next file_length
}
