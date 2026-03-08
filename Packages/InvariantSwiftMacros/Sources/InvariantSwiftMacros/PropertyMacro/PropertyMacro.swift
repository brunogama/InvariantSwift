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

    // Extract @Reproduce presence
    let hasReproduce = funcDecl.attributes.contains { attr in
      attr.as(AttributeSyntax.self)?.attributeName.description.contains("Reproduce") == true
    }

    // Extract @Regression config
    let regressionConfig = RegressionExtractor.extractConfig(from: funcDecl)

    // Validate mutual exclusion
    if hasReproduce && regressionConfig != nil {
      ctx.error(
        MutuallyExclusiveMacrosDiagnostic("@Reproduce", "@Regression"),
        at: funcDecl
      )
      return []
    }

    // Extract @Timeout config
    let timeoutConfig = TimeoutExtractor.extractConfig(from: funcDecl)

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
      regressionConfig: regressionConfig,
      timeoutConfig: timeoutConfig,
      isAsync: isAsync
    )

    return [DeclSyntax(wrapperEnum)]
  }

  // swiftlint:disable:next orphaned_doc_comment
  /// Builds a wrapper enum containing the @Test function
  /// The enum provides proper scope for @Test's internal symbols
  // swiftlint:disable:next function_parameter_count
  private static func buildWrapperEnum(
    original funcDecl: FunctionDeclSyntax,
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: PropertyMacroConfig,
    regressionConfig: RegressionConfig?,
    timeoutConfig: TimeoutConfig?,
    isAsync: Bool
  ) -> EnumDeclSyntax {
    let enumName = "\(funcDecl.name.text)_PropertyTest"
    let testName = funcDecl.name.text

    let testBody = buildPropertyTestBody(
      parameters: parameters,
      originalBody: originalBody,
      config: config,
      regressionConfig: regressionConfig,
      timeoutConfig: timeoutConfig,
      isAsync: isAsync
    )

    let testFunc = MacroTemplateAdapter.makeFunction(
      accessLevel: .internal,
      attributes: [.arguments("Test", [.unlabeled("\"\(testName)\"")])],
      isStatic: true,
      name: "run",
      isAsync: isAsync,
      canThrow: true,
      body: testBody
    )

    return MacroTemplateAdapter.makeEnum(
      accessLevel: .private,
      name: enumName,
      members: [DeclSyntax(testFunc)]
    )
  }

  // swiftlint:disable:next function_parameter_count
  private static func buildTransformedFunction(
    original funcDecl: FunctionDeclSyntax,
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: PropertyMacroConfig,
    regressionConfig: RegressionConfig?,
    isAsync: Bool
  ) -> FunctionDeclSyntax {

    let newName = "\(funcDecl.name.text)_PropertyTest"

    let newBody = buildPropertyTestBody(
      parameters: parameters,
      originalBody: originalBody,
      config: config,
      regressionConfig: regressionConfig,
      timeoutConfig: nil,  // Not used in this path
      isAsync: isAsync
    )

    // Preserve original modifiers (do not auto-add static to support file-scope tests)
    let modifiers = funcDecl.modifiers

    return MacroTemplateAdapter.makeFunction(
      accessLevel: accessLevel(from: modifiers),
      attributes: [],
      isStatic: modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }),
      name: newName,
      isAsync: isAsync,
      canThrow: true,
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

  private static func accessLevel(
    from modifiers: DeclModifierListSyntax
  ) -> MacroTemplateAdapter.MTKAccessLevel {
    if modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) }) {
      return .public
    }
    if modifiers.contains(where: { $0.name.tokenKind == .keyword(.fileprivate) }) {
      return .fileprivate
    }
    if modifiers.contains(where: { $0.name.tokenKind == .keyword(.private) }) {
      return .private
    }
    return .internal
  }

  // swiftlint:disable:next function_parameter_count
  private static func buildPropertyTestBody(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: PropertyMacroConfig,
    regressionConfig: RegressionConfig?,
    timeoutConfig: TimeoutConfig?,
    isAsync: Bool
  ) -> CodeBlockSyntax {
    let labels = PropertyFailureFormatter.extractLabels(from: parameters)
    let hasSeed = true

    // If flake detection enabled, generate different code path
    if config.detectFlakiness {
      return buildFlakeDetectionBody(
        parameters: parameters,
        originalBody: originalBody,
        config: config,
        regressionConfig: regressionConfig,
        timeoutConfig: timeoutConfig,
        isAsync: isAsync
      )
    }

    return CodeBlockSyntax {
      buildGeneratorDeclaration(parameters: parameters)
      buildPropertyDeclaration(parameters: parameters, originalBody: originalBody)
      buildConfigDeclaration(config: config, regressionConfig: regressionConfig)
      if isAsync {
        buildAsyncResultDeclaration(timeoutConfig: timeoutConfig)
      } else {
        buildResultDeclaration(timeoutConfig: timeoutConfig)
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

    return MacroTemplateAdapter.makeStoredProperty(
      name: "property",
      type: nil,
      isStatic: false,
      isLet: true,
      initializer: ExprSyntax(propertyInit)
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
  private static func buildConfigDeclaration(
    config: PropertyMacroConfig,
    regressionConfig: RegressionConfig?
  ) -> VariableDeclSyntax {
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

    // Add FailingExampleDatabase and TestIdentifier if @Regression present
    if let regConfig = regressionConfig {
      // failingExampleDatabase: FailingExampleDatabase.shared
      let databaseExpr = MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("FailingExampleDatabase")),
        period: .periodToken(),
        declName: DeclReferenceExprSyntax(baseName: .identifier("shared"))
      )
      arguments.append(
        LabeledExprSyntax(
          label: .identifier("failingExampleDatabase"),
          colon: .colonToken(),
          expression: ExprSyntax(databaseExpr)
        )
      )

      // testIdentifier: TestIdentifier(module: "", file: String(describing: #file), ...)
      let testIDExpr = FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("TestIdentifier")),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            label: .identifier("module"),
            colon: .colonToken(),
            expression: StringLiteralExprSyntax(content: "")
          )
          .with(\.trailingComma, .commaToken())
          LabeledExprSyntax(
            label: .identifier("file"),
            colon: .colonToken(),
            expression: FunctionCallExprSyntax(
              calledExpression: DeclReferenceExprSyntax(baseName: .identifier("String")),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                  label: .identifier("describing"),
                  colon: .colonToken(),
                  expression: MacroExpansionExprSyntax(
                    pound: .poundToken(),
                    macroName: .identifier("file"),
                    arguments: LabeledExprListSyntax([])
                  )
                )
              },
              rightParen: .rightParenToken()
            )
          )
          .with(\.trailingComma, .commaToken())
          LabeledExprSyntax(
            label: .identifier("function"),
            colon: .colonToken(),
            expression: FunctionCallExprSyntax(
              calledExpression: DeclReferenceExprSyntax(baseName: .identifier("String")),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                  label: .identifier("describing"),
                  colon: .colonToken(),
                  expression: MacroExpansionExprSyntax(
                    pound: .poundToken(),
                    macroName: .identifier("function"),
                    arguments: LabeledExprListSyntax([])
                  )
                )
              },
              rightParen: .rightParenToken()
            )
          )
          .with(\.trailingComma, .commaToken())
          LabeledExprSyntax(
            label: .identifier("signature"),
            colon: .colonToken(),
            expression: StringLiteralExprSyntax(content: "")
          )
        },
        rightParen: .rightParenToken()
      )
      arguments.append(
        LabeledExprSyntax(
          label: .identifier("testIdentifier"),
          colon: .colonToken(),
          expression: ExprSyntax(testIDExpr)
        )
      )

      // replayFirst: true/false
      arguments.append(
        LabeledExprSyntax(
          label: .identifier("replayFirst"),
          colon: .colonToken(),
          expression: BooleanLiteralExprSyntax(booleanLiteral: regConfig.replayFirst)
        )
      )

      // maxReplayExamples: N (if specified)
      if let maxExamples = regConfig.maxExamples {
        arguments.append(
          LabeledExprSyntax(
            label: .identifier("maxReplayExamples"),
            colon: .colonToken(),
            expression: IntegerLiteralExprSyntax(literal: .integerLiteral("\(maxExamples)"))
          )
        )
      }
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

    return MacroTemplateAdapter.makeStoredProperty(
      name: "config",
      type: nil,
      isStatic: false,
      isLet: true,
      initializer: ExprSyntax(configCall)
    )
  }

  private static func buildResultDeclaration(timeoutConfig: TimeoutConfig?) -> VariableDeclSyntax {
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

    // Synchronous properties don't support timeout (would block thread)
    // Timeout is only meaningful for async properties
    return MacroTemplateAdapter.makeStoredProperty(
      name: "result",
      type: nil,
      isStatic: false,
      isLet: true,
      initializer: ExprSyntax(checkCall)
    )
  }

  private static func buildAsyncResultDeclaration(
    timeoutConfig: TimeoutConfig?
  ) -> VariableDeclSyntax {
    let runPropertyCall = FunctionCallExprSyntax(
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

    let finalExpr: ExprSyntax
    if let timeout = timeoutConfig, let seconds = timeout.seconds {
      // Wrap with withPropertyTimeout
      let timeoutCall = FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(
          baseName: .identifier("withPropertyTimeout")
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            label: .identifier("seconds"),
            colon: .colonToken(),
            expression: FloatLiteralExprSyntax(literal: .floatLiteral("\(seconds)"))
          )
        },
        rightParen: .rightParenToken(),
        trailingClosure: ClosureExprSyntax(
          statements: CodeBlockItemListSyntax {
            CodeBlockItemSyntax(
              item: .expr(
                ExprSyntax(
                  TryExprSyntax(
                    expression: AwaitExprSyntax(expression: runPropertyCall)
                  )
                )
              )
            )
          }
        )
      )
      finalExpr = ExprSyntax(TryExprSyntax(expression: AwaitExprSyntax(expression: timeoutCall)))
    } else {
      // No timeout - use direct await
      finalExpr = ExprSyntax(AwaitExprSyntax(expression: runPropertyCall))
    }

    return MacroTemplateAdapter.makeStoredProperty(
      name: "result",
      type: nil,
      isStatic: false,
      isLet: true,
      initializer: finalExpr
    )
  }

  // swiftlint:disable:next function_parameter_count
  private static func buildFlakeDetectionBody(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: PropertyMacroConfig,
    regressionConfig: RegressionConfig?,
    timeoutConfig: TimeoutConfig?,
    isAsync: Bool
  ) -> CodeBlockSyntax {
    // TODO: Implement pure SwiftSyntax AST for flake detection
    // Current implementation uses forbidden string interpolation
    // Fallback to standard property test body (manual API available)
    buildPropertyTestBody(
      parameters: parameters,
      originalBody: originalBody,
      config: config,
      regressionConfig: regressionConfig,
      timeoutConfig: timeoutConfig,
      isAsync: isAsync
    )
  }

  private static func buildGeneratorExpression(_ parameters: [ExtractedParameter]) -> String {
    let generators = parameters.map { param -> String in
      "Gen<\(param.type.description)>.arbitrary"
    }

    if generators.count == 1 {
      return generators[0]
    } else {
      // Build flatMap chain
      var result = generators[0]
      for i in 1..<generators.count {
        let paramNames = parameters.prefix(i + 1).map { $0.name }.joined(separator: ", ")
        result =
          "\(result).flatMap { \(parameters[i - 1].name) in \(generators[i]).map { \(parameters[i].name) in (\(paramNames)) } }"
      }
      return result
    }
  }

  private static func buildClosureParameters(_ parameters: [ExtractedParameter]) -> String {
    parameters.map { "\($0.name): \($0.type.description)" }.joined(separator: ", ")
  }

  private static func buildClosureBody(_ body: CodeBlockSyntax) -> String {
    body.statements.map { $0.description }.joined(separator: "\n")
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
