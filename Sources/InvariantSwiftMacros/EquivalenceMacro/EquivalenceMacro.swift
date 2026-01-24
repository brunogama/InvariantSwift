import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// Note: EquivalenceMacroConfig, EquivalenceDiagnostic, GeneratorInference,
// ParameterExtractor, TypeAnalyzer, FunctionCallBuilder, and SyntaxFactory
// are all defined within the InvariantSwiftMacros target - no imports needed.

/// Peer macro implementation for @Equivalence.
///
/// Generates a Swift Testing @Test function that compares reference and candidate
/// implementations across generated inputs with optional floating-point tolerance.
public struct EquivalenceMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    // 1. Validate declaration is a function
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: EquivalenceDiagnostic.mustBeFunction
        )
      )
      return []
    }

    // 2. Extract and validate parameters
    let parameters = ParameterExtractor.extract(from: funcDecl)

    guard parameters.count == 2 else {
      context.diagnose(
        Diagnostic(
          node: funcDecl.signature.parameterClause,
          message: EquivalenceDiagnostic.requiresTwoFunctionParameters
        )
      )
      return []
    }

    let refParam = parameters[0]
    let candParam = parameters[1]

    // Both parameters should be function types
    guard let refFuncType = refParam.type.as(FunctionTypeSyntax.self),
      let candFuncType = candParam.type.as(FunctionTypeSyntax.self)
    else {
      context.diagnose(
        Diagnostic(
          node: funcDecl.signature.parameterClause,
          message: EquivalenceDiagnostic.incompatibleFunctionTypes
        )
      )
      return []
    }

    // 3. Extract configuration
    let config = EquivalenceConfigExtractor.extract(from: node)

    // 4. CRITICAL: Validate tolerance only used with BinaryFloatingPoint types
    if let _ = config.tolerance {
      // Extract output type from function return type
      guard let outputType = refFuncType.returnClause.type.as(TypeSyntax.self) else {
        context.diagnose(
          Diagnostic(
            node: node,
            message: EquivalenceDiagnostic.toleranceRequiresBinaryFloatingPoint
          )
        )
        return []
      }

      let typeName = TypeAnalyzer.baseTypeName(from: outputType)
      let floatingPointTypes: Set<String> = [
        "Double", "Float", "Float16", "Float80", "CGFloat",
      ]

      if !floatingPointTypes.contains(typeName) {
        context.diagnose(
          Diagnostic(
            node: node,
            message: EquivalenceDiagnostic.toleranceRequiresBinaryFloatingPoint
          )
        )
        return []
      }
    }

    // 5. Build generator inference
    let inputTypes = extractInputTypes(from: refFuncType)
    let generatorExpr = buildGeneratorExpression(for: inputTypes)

    // 6. Build wrapper enum with @Test function
    let wrapperEnum = buildWrapperEnum(
      functionName: funcDecl.name.text,
      refParam: refParam,
      candParam: candParam,
      refFuncType: refFuncType,
      generatorExpr: generatorExpr,
      config: config
    )

    return [DeclSyntax(wrapperEnum)]
  }

  // MARK: - Helper Methods

  /// Extracts input types from function type signature.
  private static func extractInputTypes(from funcType: FunctionTypeSyntax) -> [TypeSyntax] {
    funcType.parameters.map { param in
      param.type
    }
  }

  /// Builds generator expression for input types.
  /// If multiple inputs, combines with Gen.zip; if single input, uses direct generator.
  private static func buildGeneratorExpression(for inputTypes: [TypeSyntax]) -> ExprSyntax {
    let generators = inputTypes.map { inputType in
      GeneratorInference.infer(for: inputType)
    }

    if generators.count == 1 {
      return generators[0]
    } else {
      return FunctionCallBuilder.genZip(generators).buildExpr()
    }
  }

  /// Builds the wrapper enum containing the @Test function.
  // swiftlint:disable:next function_parameter_count function_body_length
  private static func buildWrapperEnum(
    functionName: String,
    refParam: ExtractedParameter,
    candParam: ExtractedParameter,
    refFuncType: FunctionTypeSyntax,
    generatorExpr: ExprSyntax,
    config: EquivalenceMacroConfig
  ) -> EnumDeclSyntax {
    let enumName = "\(functionName)_EquivalenceTest"
    let testName = functionName

    let testBody = buildTestBody(
      refParam: refParam,
      candParam: candParam,
      refFuncType: refFuncType,
      generatorExpr: generatorExpr,
      config: config
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
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {}
        ),
        effectSpecifiers: FunctionEffectSpecifiersSyntax(
          throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        )
      ),
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

  /// Builds the test function body.
  // swiftlint:disable:next function_body_length
  private static func buildTestBody(
    refParam: ExtractedParameter,
    candParam: ExtractedParameter,
    refFuncType: FunctionTypeSyntax,
    generatorExpr: ExprSyntax,
    config: EquivalenceMacroConfig
  ) -> CodeBlockSyntax {
    CodeBlockSyntax {
      // for _ in 0..<iterations
      ForStmtSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier("_")),
        sequence: InfixOperatorExprSyntax(
          leftOperand: IntegerLiteralExprSyntax(literal: .integerLiteral("0")),
          operator: BinaryOperatorExprSyntax(operator: .binaryOperator("..<")),
          rightOperand: IntegerLiteralExprSyntax(
            literal: .integerLiteral("\(config.iterations)")
          )
        ),
        body: CodeBlockSyntax {
          // var rng = ..., let input = generator.generate(&rng, Size.default)
          for item in buildInputGeneration(generatorExpr: generatorExpr) {
            item
          }

          // let referenceResult = reference(input)
          buildFunctionCall(
            resultName: "referenceResult",
            functionName: refParam.name,
            inputPattern: buildInputPattern(from: refFuncType)
          )

          // let candidateResult = candidate(input)
          buildFunctionCall(
            resultName: "candidateResult",
            functionName: candParam.name,
            inputPattern: buildInputPattern(from: refFuncType)
          )

          // Comparison logic (with or without tolerance)
          buildComparisonLogic(config: config)
        }
      )
    }
  }

  /// Builds input generation statements (var rng and let input).
  private static func buildInputGeneration(generatorExpr: ExprSyntax) -> [CodeBlockItemSyntax] {
    let rngDecl = VariableDeclSyntax(
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("rng")),
          initializer: InitializerClauseSyntax(
            value: FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("SystemRandomNumberGenerator")),
                declName: DeclReferenceExprSyntax(baseName: .identifier("init"))
              ),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {},
              rightParen: .rightParenToken()
            )
          )
        )
      }
    )

    let inputDecl = VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("input")),
          initializer: InitializerClauseSyntax(
            value: FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: generatorExpr,
                declName: DeclReferenceExprSyntax(baseName: .identifier("generate"))
              ),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                  expression: InOutExprSyntax(
                    expression: DeclReferenceExprSyntax(baseName: .identifier("rng"))
                  )
                )
                LabeledExprSyntax(
                  expression: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("Size")),
                    declName: DeclReferenceExprSyntax(baseName: .identifier("default"))
                  )
                )
              },
              rightParen: .rightParenToken()
            )
          )
        )
      }
    )

    return [
      CodeBlockItemSyntax(item: .decl(DeclSyntax(rngDecl))),
      CodeBlockItemSyntax(item: .decl(DeclSyntax(inputDecl))),
    ]
  }

  /// Builds function call statement.
  private static func buildFunctionCall(
    resultName: String,
    functionName: String,
    inputPattern: String
  ) -> VariableDeclSyntax {
    VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier(resultName)),
          initializer: InitializerClauseSyntax(
            value: FunctionCallExprSyntax(
              calledExpression: DeclReferenceExprSyntax(baseName: .identifier(functionName)),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                  expression: DeclReferenceExprSyntax(
                    baseName: .identifier(inputPattern)
                  )
                )
              },
              rightParen: .rightParenToken()
            )
          )
        )
      }
    )
  }

  /// Builds input pattern (either "input" for single param or tuple destructuring).
  private static func buildInputPattern(from funcType: FunctionTypeSyntax) -> String {
    if funcType.parameters.count == 1 {
      return "input"
    } else {
      // For multiple parameters, we'd need tuple destructuring
      // For now, assume single parameter
      return "input"
    }
  }

  /// Builds comparison logic (with or without tolerance).
  private static func buildComparisonLogic(config: EquivalenceMacroConfig) -> CodeBlockItemSyntax {
    if let tolerance = config.tolerance {
      // WITH TOLERANCE: Use isApproximatelyEqual instance method
      return buildToleranceComparison(tolerance: tolerance)
    } else {
      // WITHOUT TOLERANCE: Use != operator
      return buildExactComparison()
    }
  }

  /// Builds exact equality comparison.
  private static func buildExactComparison() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      item: .expr(
        ExprSyntax(
          IfExprSyntax(
            conditions: ConditionElementListSyntax {
              ConditionElementSyntax(
                condition: .expression(
                  ExprSyntax(
                    InfixOperatorExprSyntax(
                      leftOperand: DeclReferenceExprSyntax(
                        baseName: .identifier("referenceResult")
                      ),
                      operator: BinaryOperatorExprSyntax(operator: .binaryOperator("!=")),
                      rightOperand: DeclReferenceExprSyntax(
                        baseName: .identifier("candidateResult")
                      )
                    )
                  )
                )
              )
            },
            body: CodeBlockSyntax {
              buildIssueRecord()
            }
          )
        )
      )
    )
  }

  /// Builds tolerance-aware comparison using isApproximatelyEqual instance method.
  private static func buildToleranceComparison(tolerance: Double) -> CodeBlockItemSyntax {
    // Build FloatingPointTolerance.absolute(tolerance) value
    let toleranceValue = buildToleranceValue(tolerance: tolerance)

    // Build referenceResult.isApproximatelyEqual(to: candidateResult, tolerance: toleranceValue)
    let isApproxEqualCall = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("referenceResult")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("isApproximatelyEqual"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("to"),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: .identifier("candidateResult"))
        )
        LabeledExprSyntax(
          label: .identifier("tolerance"),
          colon: .colonToken(),
          expression: ExprSyntax(toleranceValue)
        )
      },
      rightParen: .rightParenToken()
    )

    // Negate for divergence check: !isApproxEqual
    let divergenceCondition = PrefixOperatorExprSyntax(
      operator: .prefixOperator("!"),
      expression: ExprSyntax(isApproxEqualCall)
    )

    return CodeBlockItemSyntax(
      item: .expr(
        ExprSyntax(
          IfExprSyntax(
            conditions: ConditionElementListSyntax {
              ConditionElementSyntax(
                condition: .expression(ExprSyntax(divergenceCondition))
              )
            },
            body: CodeBlockSyntax {
              buildIssueRecord()
            }
          )
        )
      )
    )
  }

  /// Builds FloatingPointTolerance.absolute(tolerance) expression.
  private static func buildToleranceValue(tolerance: Double) -> ExprSyntax {
    // Build .absolute enum case access
    let absoluteMember = MemberAccessExprSyntax(
      period: .periodToken(),
      declName: DeclReferenceExprSyntax(baseName: .identifier("absolute"))
    )

    // Build function call: .absolute(tolerance)
    let toleranceCall = FunctionCallExprSyntax(
      calledExpression: absoluteMember,
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          expression: FloatLiteralExprSyntax(literal: .floatLiteral("\(tolerance)"))
        )
      },
      rightParen: .rightParenToken()
    )

    return ExprSyntax(toleranceCall)
  }

  /// Builds Issue.record call for divergence.
  private static func buildIssueRecord() -> CodeBlockItemSyntax {
    let issueCall = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("Issue")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("record"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          expression: FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Comment")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
              LabeledExprSyntax(
                label: .identifier("rawValue"),
                colon: .colonToken(),
                expression: StringLiteralExprSyntax(
                  content:
                    "Equivalence test failed: reference and candidate produced different outputs"
                )
              )
            },
            rightParen: .rightParenToken()
          )
        )
      },
      rightParen: .rightParenToken()
    )

    return CodeBlockItemSyntax(item: .expr(ExprSyntax(issueCall)))
  }
}
