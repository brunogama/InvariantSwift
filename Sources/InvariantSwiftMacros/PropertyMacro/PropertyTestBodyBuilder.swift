import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Property Test Body Builder

/// Builds the body of a property test function.
/// Creates the PropertyRunner invocation and result handling.
public enum PropertyTestBodyBuilder {

  /// Build the complete test body
  public static func build(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax,
    config: PropertyMacroConfig
  ) -> CodeBlockSyntax {
    CodeBlockSyntax {
      // let generator = Gen.zip(gen1, gen2, ...).map { ... }
      buildGeneratorDeclaration(parameters: parameters)

      // let property = Property(generator: generator) { params in ... }
      buildPropertyDeclaration(parameters: parameters, originalBody: originalBody)

      // let config = PropertyConfig(iterations: ..., ...)
      buildConfigDeclaration(config: config)

      // let result = PropertyChecker.check(property, config: config)
      buildResultDeclaration()

      // Handle result with #expect or throw
      buildResultHandling()
    }
  }

  // MARK: - Generator Declaration

  /// Builds: let generator = Gen.zip(...).map { ... }
  private static func buildGeneratorDeclaration(
    parameters: [ExtractedParameter]
  ) -> VariableDeclSyntax {
    // Use GenAttributeExtractor to resolve generators (considers @Gen attributes)
    let generators = parameters.map { GenAttributeExtractor.resolveGenerator(for: $0) }
    let paramNames = parameters.map(\.name)

    // Build the zip expression
    let zipExpr = GeneratorBuilder.zip(generators)

    // Build the map closure
    let mapClosure = ClosureBuilder.mapToTuple(paramNames: paramNames).build()

    // Build zip(...).map { ... }
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

  // MARK: - Property Declaration

  /// Builds: let property = Property(generator: generator) { (a, b, c) in ... }
  private static func buildPropertyDeclaration(
    parameters: [ExtractedParameter],
    originalBody: CodeBlockSyntax
  ) -> VariableDeclSyntax {
    let paramNames = parameters.map(\.name)

    // Build the closure that wraps the original test body
    let testClosure = buildTestClosure(paramNames: paramNames, body: originalBody)

    // Build Property(generator: generator) { ... }
    let propertyInit = FunctionCallExprSyntax(
      calledExpression: SyntaxFactory.declRef("Property"),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("generator"),
          colon: .colonToken(),
          expression: SyntaxFactory.declRef("generator")
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

  /// Builds the test closure: { (a, b, c) in ... return true }
  private static func buildTestClosure(
    paramNames: [String],
    body: CodeBlockSyntax
  ) -> ClosureExprSyntax {
    // Build closure with shorthand parameters

    ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax {
            for name in paramNames {
              ClosureShorthandParameterSyntax(name: .identifier(name))
            }
          }
        )
      ),
      statements: CodeBlockItemListSyntax {
        // Include original body statements
        for statement in body.statements {
          statement
        }
        // Return true if all assertions passed
        ReturnStmtSyntax(expression: SyntaxFactory.boolLiteral(true))
      }
    )
  }

  // MARK: - Config Declaration

  /// Builds: let config = PropertyConfig(iterations: ..., ...)
  private static func buildConfigDeclaration(
    config: PropertyMacroConfig
  ) -> VariableDeclSyntax {
    var configCall = FunctionCallBuilder("PropertyConfig")
      .arg("iterations", int: config.iterations)
      .arg("maxShrinks", int: config.maxShrinks)

    // Add seed if present
    if let seed = config.seed {
      let seedExpr = FunctionCallBuilder("Seed")
        .arg("value", ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("\(seed)"))))
        .buildExpr()
      configCall = configCall.arg("seed", seedExpr)
    }

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("config")),
          initializer: InitializerClauseSyntax(value: configCall.buildExpr())
        )
      }
    )
  }

  // MARK: - Result Declaration

  /// Builds: let result = runPropertySynchronously(property, config: config)
  private static func buildResultDeclaration() -> VariableDeclSyntax {
    let checkCall = FunctionCallBuilder("runPropertySynchronously")
      .arg(ref: "property")
      .arg("config", ref: "config")

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
          initializer: InitializerClauseSyntax(value: checkCall.buildExpr())
        )
      }
    )
  }

  // MARK: - Result Handling

  /// Builds the switch statement to handle property result
  private static func buildResultHandling() -> SwitchExprSyntax {
    SwitchExprSyntax(
      subject: SyntaxFactory.declRef("result"),
      cases: SwitchCaseListSyntax {
        // case .success: break
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

        // case .failure(let counterexample, let iterations, let shrunk, _, _):
        buildFailureCase()

        // case .gaveUp(let discarded, let iterations):
        buildGaveUpCase()
      }
    )
  }

  private static func buildFailureCase() -> SwitchCaseSyntax {
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
                          pattern: IdentifierPatternSyntax(
                            identifier: .identifier("counterexample")
                          )
                        )
                      )
                    )
                    LabeledExprSyntax(
                      label: .identifier("iterations"),
                      colon: .colonToken(),
                      expression: PatternExprSyntax(
                        pattern: ValueBindingPatternSyntax(
                          bindingSpecifier: .keyword(.let),
                          pattern: IdentifierPatternSyntax(
                            identifier: .identifier("iterations")
                          )
                        )
                      )
                    )
                    LabeledExprSyntax(
                      label: .identifier("shrunk"),
                      colon: .colonToken(),
                      expression: PatternExprSyntax(
                        pattern: ValueBindingPatternSyntax(
                          bindingSpecifier: .keyword(.let),
                          pattern: IdentifierPatternSyntax(
                            identifier: .identifier("shrunk")
                          )
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
        // Issue.record(...)
        buildIssueRecord(messageType: "failure")
      }
    )
  }

  private static func buildGaveUpCase() -> SwitchCaseSyntax {
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
                          pattern: IdentifierPatternSyntax(
                            identifier: .identifier("discarded")
                          )
                        )
                      )
                    )
                    LabeledExprSyntax(
                      label: .identifier("iterations"),
                      colon: .colonToken(),
                      expression: PatternExprSyntax(
                        pattern: ValueBindingPatternSyntax(
                          bindingSpecifier: .keyword(.let),
                          pattern: IdentifierPatternSyntax(
                            identifier: .identifier("iterations")
                          )
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
        buildIssueRecord(messageType: "gaveUp")
      }
    )
  }

  private static func buildIssueRecord(messageType: String) -> FunctionCallExprSyntax {
    // Issue.record(Comment(stringLiteral: "..."))
    FunctionCallBuilder(type: "Issue", member: "record")
      .arg(
        FunctionCallBuilder("Comment")
          .arg(
            "stringLiteral",
            ExprSyntax(
              StringLiteralExprSyntax(content: "Property test \(messageType)")
            )
          )
          .buildExpr()
      )
      .build()
  }
}

// MARK: - Closure Builder Extension

extension ClosureBuilder {
  /// Creates a closure that returns a tuple: { a, b, c in (a, b, c) }
  static func mapToTuple(paramNames: [String]) -> ClosureBuilder {
    if paramNames.count == 1 {
      // Single param, just return it
      return ClosureBuilder()
        .params(paramNames)
        .return(ExprSyntax(SyntaxFactory.declRef(paramNames[0])))
    }

    // Multiple params, return tuple
    let tupleExpr = TupleExprSyntax(
      elements: LabeledExprListSyntax {
        for name in paramNames {
          LabeledExprSyntax(expression: SyntaxFactory.declRef(name))
        }
      }
    )

    return ClosureBuilder()
      .params(paramNames)
      .return(ExprSyntax(tupleExpr))
  }
}
