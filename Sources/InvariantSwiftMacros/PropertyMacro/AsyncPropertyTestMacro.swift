/// AsyncPropertyTestMacro - Macro for scheduler-based property testing
///
/// Implements the `@AsyncPropertyTest` macro from ISP-0001 for deterministic
/// testing of concurrent Swift code.
///
/// Uses proper SwiftSyntax AST construction following project patterns.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@AsyncPropertyTest` macro for concurrent property testing with controlled scheduling.
///
/// Expands to a test function that systematically explores interleavings of async operations.
///
/// **Usage:**
/// ```swift
/// @AsyncPropertyTest(scheduler: .exhaustive(depth: 5))
/// func testCacheConcurrency(keys: [String]) async {
///     let cache = Cache()
///     await withTaskGroup(of: Void.self) { group in
///         for key in keys {
///             group.addTask { _ = await cache.get(key) }
///         }
///     }
///     #expect(await cache.isConsistent)
/// }
/// ```
public struct AsyncPropertyTestMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw AsyncPropertyTestError.notAFunction
    }

    // Extract configuration from attribute arguments
    let config = extractConfig(from: node)

    // Extract parameters using existing infrastructure
    let parameters = ParameterExtractor.extract(from: funcDecl)

    // Get original function body
    guard let body = funcDecl.body else {
      throw AsyncPropertyTestError.missingBody
    }

    // Check for @MainActor attribute
    let isMainActor = funcDecl.attributes.contains { attr in
      attr.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "MainActor"
    }

    // Build the expanded test function
    let expandedFunction = buildExpandedFunction(
      original: funcDecl,
      parameters: parameters,
      body: body,
      config: config,
      isMainActor: isMainActor
    )

    return [DeclSyntax(expandedFunction)]
  }

  // MARK: - Configuration Extraction

  private static func extractConfig(from node: AttributeSyntax) -> AsyncPropertyTestConfig {
    var config = AsyncPropertyTestConfig()

    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return config
    }

    for argument in arguments {
      guard let label = argument.label?.text else { continue }

      switch label {
      case "scheduler":
        config.schedulerStrategy = argument.expression

      case "iterations":
        if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
          let value = Int(intLiteral.literal.text)
        {
          config.iterations = value
        }

      case "maxInterleavings":
        if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
          let value = Int(intLiteral.literal.text)
        {
          config.maxInterleavings = value
        }

      case "timeout":
        config.timeout = argument.expression

      default:
        break
      }
    }

    return config
  }

  // MARK: - Function Building

  private static func buildExpandedFunction(
    original funcDecl: FunctionDeclSyntax,
    parameters: [ExtractedParameter],
    body: CodeBlockSyntax,
    config: AsyncPropertyTestConfig,
    isMainActor: Bool
  ) -> FunctionDeclSyntax {

    let newName = "\(funcDecl.name.text)_AsyncPropertyTest"

    // Build attributes
    var attributesList: [AttributeListSyntax.Element] = []

    // Add @Test attribute
    attributesList.append(
      .attribute(
        AttributeSyntax(
          atSign: .atSignToken(),
          attributeName: IdentifierTypeSyntax(name: .identifier("Test"))
        )
      )
    )

    // Add @available attribute for macOS 15+
    attributesList.append(
      .attribute(buildAvailabilityAttribute())
    )

    if isMainActor {
      attributesList.append(
        .attribute(
          AttributeSyntax(
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier("MainActor"))
          )
        )
      )
    }

    let attributes = AttributeListSyntax(attributesList)

    // Build new body with scheduler integration
    let newBody = AsyncPropertyTestBodyBuilder.build(
      parameters: parameters,
      originalBody: body,
      config: config
    )

    return FunctionDeclSyntax(
      attributes: attributes,
      modifiers: funcDecl.modifiers,
      name: .identifier(newName),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {}
        ),
        effectSpecifiers: FunctionEffectSpecifiersSyntax(
          asyncSpecifier: .keyword(.async),
          throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        )
      ),
      body: newBody
    )
  }

  private static func buildAvailabilityAttribute() -> AttributeSyntax {
    AttributeSyntax(
      atSign: .atSignToken(),
      attributeName: IdentifierTypeSyntax(name: .identifier("available")),
      leftParen: .leftParenToken(),
      arguments: .availability(
        AvailabilityArgumentListSyntax {
          AvailabilityArgumentSyntax(
            argument: .availabilityVersionRestriction(
              PlatformVersionSyntax(
                platform: .identifier("macOS"),
                version: VersionTupleSyntax(
                  major: .integerLiteral("15"),
                  components: VersionComponentListSyntax {}
                )
              )
            )
          )
          AvailabilityArgumentSyntax(
            argument: .availabilityVersionRestriction(
              PlatformVersionSyntax(
                platform: .identifier("iOS"),
                version: VersionTupleSyntax(
                  major: .integerLiteral("18"),
                  components: VersionComponentListSyntax {}
                )
              )
            )
          )
          AvailabilityArgumentSyntax(
            argument: .availabilityVersionRestriction(
              PlatformVersionSyntax(
                platform: .identifier("tvOS"),
                version: VersionTupleSyntax(
                  major: .integerLiteral("18"),
                  components: VersionComponentListSyntax {}
                )
              )
            )
          )
          AvailabilityArgumentSyntax(
            argument: .availabilityVersionRestriction(
              PlatformVersionSyntax(
                platform: .identifier("watchOS"),
                version: VersionTupleSyntax(
                  major: .integerLiteral("11"),
                  components: VersionComponentListSyntax {}
                )
              )
            )
          )
          AvailabilityArgumentSyntax(
            argument: .token(.binaryOperator("*"))
          )
        }
      ),
      rightParen: .rightParenToken()
    )
  }
}

// MARK: - Async Property Test Body Builder

/// Builds the body of an async property test function.
/// Uses proper SwiftSyntax AST construction.
enum AsyncPropertyTestBodyBuilder {

  /// Build the complete test body for async property testing
  static func build(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: AsyncPropertyTestConfig
  ) -> CodeBlockSyntax {
    CodeBlockSyntax {
      // let generator = Gen.zip(...).map { ... }
      buildGeneratorDeclaration(parameters: parameters)

      // var scheduler = Scheduler(strategy: ..., maxInterleavings: ...)
      buildSchedulerDeclaration(config: config)

      // var rng = SplitMix64(seed: 12345)
      buildRNGDeclaration()

      // for iteration in 0..<iterations { ... }
      buildIterationLoop(parameters: parameters, originalBody: originalBody, config: config)
    }
  }

  // MARK: - Generator Declaration

  private static func buildGeneratorDeclaration(
    parameters: [ExtractedParameter]
  ) -> VariableDeclSyntax {
    let generators = parameters.map { GenAttributeExtractor.resolveGenerator(for: $0) }
    let paramNames = parameters.map(\.name)

    let zipExpr = GeneratorBuilder.zip(generators)
    let mapClosure = ClosureBuilder.mapToTuple(paramNames: paramNames).build()
    let generatorExpr = GeneratorBuilder.map(zipExpr, closure: mapClosure)

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

  // MARK: - Scheduler Declaration

  private static func buildSchedulerDeclaration(
    config: AsyncPropertyTestConfig
  ) -> VariableDeclSyntax {
    // Build: var scheduler = Scheduler(strategy: ..., maxInterleavings: ...)
    let schedulerInit = FunctionCallBuilder("Scheduler")
      .arg("strategy", config.schedulerStrategy ?? defaultStrategyExpr())
      .arg("maxInterleavings", int: config.maxInterleavings)
      .buildExpr()

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("scheduler")),
          initializer: InitializerClauseSyntax(value: schedulerInit)
        )
      }
    )
  }

  private static func defaultStrategyExpr() -> ExprSyntax {
    // .random(seed: nil)
    FunctionCallBuilder(
      callee: ExprSyntax(
        MemberAccessExprSyntax(
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("random"))
        )
      )
    )
    .arg("seed", ExprSyntax(NilLiteralExprSyntax()))
    .buildExpr()
  }

  // MARK: - RNG Declaration

  private static func buildRNGDeclaration() -> VariableDeclSyntax {
    let rngInit = FunctionCallBuilder("SplitMix64")
      .arg("seed", int: 12345)
      .buildExpr()

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("rng")),
          initializer: InitializerClauseSyntax(value: rngInit)
        )
      }
    )
  }

  // MARK: - Iteration Loop

  private static func buildIterationLoop(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: AsyncPropertyTestConfig
  ) -> ForStmtSyntax {
    // for iteration in 0..<iterations { ... }
    ForStmtSyntax(
      forKeyword: .keyword(.for),
      pattern: IdentifierPatternSyntax(identifier: .identifier("iteration")),
      inKeyword: .keyword(.in),
      sequence: buildRangeExpression(end: config.iterations),
      body: buildIterationBody(parameters: parameters, originalBody: originalBody, config: config)
    )
  }

  private static func buildRangeExpression(end: Int) -> ExprSyntax {
    // 0..<iterations
    ExprSyntax(
      InfixOperatorExprSyntax(
        leftOperand: SyntaxFactory.intLiteral(0),
        operator: BinaryOperatorExprSyntax(operator: .binaryOperator("..<")),
        rightOperand: SyntaxFactory.intLiteral(end)
      )
    )
  }

  private static func buildIterationBody(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: AsyncPropertyTestConfig
  ) -> CodeBlockSyntax {
    CodeBlockSyntax {
      // Generate inputs for each parameter
      for param in parameters {
        buildInputGeneration(param: param)
      }

      // var interleavingsExplored = 0
      buildInterleavingsCounter()

      // while let nextPath = scheduler.nextInterleaving(), interleavingsExplored < max { ... }
      buildInterleavingLoop(parameters: parameters, originalBody: originalBody, config: config)
    }
  }

  private static func buildInputGeneration(param: ExtractedParameter) -> VariableDeclSyntax {
    // let <name> = generator.generate(&rng, 100)
    let generateCall = FunctionCallExprSyntax(
      calledExpression: SyntaxFactory.memberAccess(
        base: ExprSyntax(SyntaxFactory.declRef("\(param.name)Gen")),
        member: "generate"
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          expression: InOutExprSyntax(
            expression: SyntaxFactory.declRef("rng")
          )
        )
        LabeledExprSyntax(expression: SyntaxFactory.intLiteral(100))
      },
      rightParen: .rightParenToken()
    )

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier(param.name)),
          initializer: InitializerClauseSyntax(value: ExprSyntax(generateCall))
        )
      }
    )
  }

  private static func buildInterleavingsCounter() -> VariableDeclSyntax {
    VariableDeclSyntax(
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("interleavingsExplored")),
          initializer: InitializerClauseSyntax(value: ExprSyntax(SyntaxFactory.intLiteral(0)))
        )
      }
    )
  }

  private static func buildInterleavingLoop(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: AsyncPropertyTestConfig
  ) -> WhileStmtSyntax {
    // Build condition: let nextPath = scheduler.nextInterleaving(), interleavingsExplored < max
    let condition = ConditionElementListSyntax {
      // Optional binding for nextPath
      ConditionElementSyntax(
        condition: .optionalBinding(
          OptionalBindingConditionSyntax(
            bindingSpecifier: .keyword(.let),
            pattern: IdentifierPatternSyntax(identifier: .identifier("nextPath")),
            initializer: InitializerClauseSyntax(
              value: FunctionCallBuilder(
                callee: ExprSyntax(
                  SyntaxFactory.memberAccess(
                    base: ExprSyntax(SyntaxFactory.declRef("scheduler")),
                    member: "nextInterleaving"
                  )
                )
              )
              .buildExpr()
            )
          )
        )
      )
      // Comparison: interleavingsExplored < maxInterleavings
      ConditionElementSyntax(
        condition: .expression(
          ExprSyntax(
            InfixOperatorExprSyntax(
              leftOperand: SyntaxFactory.declRef("interleavingsExplored"),
              operator: BinaryOperatorExprSyntax(operator: .binaryOperator("<")),
              rightOperand: SyntaxFactory.intLiteral(config.maxInterleavings)
            )
          )
        )
      )
    }

    return WhileStmtSyntax(
      conditions: condition,
      body: buildWhileBody(parameters: parameters, originalBody: originalBody)
    )
  }

  private static func buildWhileBody(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax
  ) -> CodeBlockSyntax {
    CodeBlockSyntax {
      // interleavingsExplored += 1
      buildIncrementStatement()

      // do { ... } catch { ... }
      buildDoTryCatch(parameters: parameters, originalBody: originalBody)
    }
  }

  private static func buildIncrementStatement() -> ExprSyntax {
    // interleavingsExplored += 1
    ExprSyntax(
      InfixOperatorExprSyntax(
        leftOperand: SyntaxFactory.declRef("interleavingsExplored"),
        operator: BinaryOperatorExprSyntax(operator: .binaryOperator("+=")),
        rightOperand: SyntaxFactory.intLiteral(1)
      )
    )
  }

  private static func buildDoTryCatch(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax
  ) -> DoStmtSyntax {
    DoStmtSyntax(
      body: CodeBlockSyntax {
        // try await withScheduler(Scheduler(strategy: .replay(path: nextPath))) { ... }
        buildWithSchedulerCall(originalBody: originalBody)
      },
      catchClauses: CatchClauseListSyntax {
        CatchClauseSyntax(
          catchItems: CatchItemListSyntax {
            CatchItemSyntax(
              pattern: ValueBindingPatternSyntax(
                bindingSpecifier: .keyword(.let),
                pattern: IdentifierPatternSyntax(identifier: .identifier("failure"))
              )
            )
          },
          body: buildCatchBody(parameters: parameters)
        )
      }
    )
  }

  private static func buildWithSchedulerCall(
    originalBody: CodeBlockSyntax
  ) -> TryExprSyntax {
    // Build: try await withScheduler(Scheduler(strategy: .replay(path: nextPath))) { ... }
    let replayStrategy = FunctionCallBuilder(
      callee: ExprSyntax(
        MemberAccessExprSyntax(
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("replay"))
        )
      )
    )
    .arg("path", ExprSyntax(SyntaxFactory.declRef("nextPath")))
    .buildExpr()

    let schedulerInit = FunctionCallBuilder("Scheduler")
      .arg("strategy", replayStrategy)
      .buildExpr()

    let withSchedulerCall = FunctionCallExprSyntax(
      calledExpression: SyntaxFactory.declRef("withScheduler"),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(expression: schedulerInit)
      },
      rightParen: .rightParenToken(),
      trailingClosure: ClosureExprSyntax(
        statements: originalBody.statements
      )
    )

    return TryExprSyntax(
      expression: AwaitExprSyntax(expression: ExprSyntax(withSchedulerCall))
    )
  }

  private static func buildCatchBody(
    parameters: [ExtractedParameter]
  ) -> CodeBlockSyntax {
    CodeBlockSyntax {
      // Issue.record("Race condition detected! ...")
      buildIssueRecordCall(parameters: parameters)

      // return
      ReturnStmtSyntax()
    }
  }

  private static func buildIssueRecordCall(
    parameters: [ExtractedParameter]
  ) -> FunctionCallExprSyntax {
    // Issue.record(Comment(stringLiteral: "Race condition detected!"))
    let messageExpr = ExprSyntax(
      StringLiteralExprSyntax(content: "Race condition detected in async property test")
    )

    let commentCall = FunctionCallBuilder("Comment")
      .arg("stringLiteral", messageExpr)
      .buildExpr()

    return FunctionCallBuilder(type: "Issue", member: "record")
      .arg(commentCall)
      .build()
  }
}

// MARK: - Supporting Types

struct AsyncPropertyTestConfig {
  var schedulerStrategy: ExprSyntax?
  var iterations: Int = 100
  var maxInterleavings: Int = 1000
  var timeout: ExprSyntax?
}

enum AsyncPropertyTestError: Error, CustomStringConvertible {
  case notAFunction
  case missingBody
  case invalidAttribute

  var description: String {
    switch self {
    case .notAFunction:
      return "@AsyncPropertyTest can only be applied to functions"

    case .missingBody:
      return "@AsyncPropertyTest requires a function body"

    case .invalidAttribute:
      return "Invalid attribute configuration"
    }
  }
}
