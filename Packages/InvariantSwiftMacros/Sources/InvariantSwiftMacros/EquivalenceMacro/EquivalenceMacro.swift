import InvariantSwiftExpansionSupport
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
// swiftlint:disable:next type_body_length
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

    // 2. Validate the reference and candidate parameters
    guard let validated = validatedParameters(of: funcDecl, in: context) else {
      return []
    }

    // 3. Extract configuration
    let config = EquivalenceConfigExtractor.extract(from: node)

    // 4. CRITICAL: Validate tolerance only used with BinaryFloatingPoint types
    guard
      validateTolerance(
        config,
        returnType: TypeSyntax(validated.refFuncType.returnClause.type),
        at: node,
        in: context
      )
    else {
      return []
    }

    // 5. Build generator inference
    let inputTypes = extractInputTypes(from: validated.refFuncType)
    let generatorExpr = buildGeneratorExpression(for: inputTypes)

    // 6. Build wrapper enum with @Test function
    let wrapperEnum = buildWrapperEnum(
      plan: TestPlan(
        functionName: funcDecl.name.text,
        refParam: validated.reference,
        candParam: validated.candidate,
        refFuncType: validated.refFuncType,
        generatorExpr: generatorExpr,
        config: config
      )
    )

    return [DeclSyntax(wrapperEnum)]
  }

  // MARK: - TestPlan

  /// Everything the generated test needs, gathered once so that the builders below do
  /// not each take the same five arguments.
  private struct TestPlan {
    let functionName: String
    let refParam: ExtractedParameter
    let candParam: ExtractedParameter
    let refFuncType: FunctionTypeSyntax
    let generatorExpr: ExprSyntax
    let config: EquivalenceMacroConfig

    /// Effects are read off the compared closures' type, not the annotated function:
    /// `(Int) async -> Int` has to be awaited, and the generated test awaits it, so the
    /// test itself must be async.
    var isAsync: Bool { refFuncType.effectSpecifiers?.asyncSpecifier != nil }

    var isThrowing: Bool { refFuncType.effectSpecifiers?.throwsClause != nil }

    /// The arguments for one call. A closure taking several parameters cannot be called
    /// with the generated tuple as a single argument, so the tuple is spread.
    var callArguments: [String] {
      let count = refFuncType.parameters.count
      guard count > 1 else { return ["input"] }
      return (0..<count).map { "input.\($0)" }
    }
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
  private static func buildWrapperEnum(plan: TestPlan) -> EnumDeclSyntax {
    let enumName = "\(plan.functionName)_EquivalenceTest"
    let testName = plan.functionName

    let testBody = buildTestBody(plan: plan)

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
          asyncSpecifier: plan.isAsync ? .keyword(.async) : nil,
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
  private static func buildTestBody(plan: TestPlan) -> CodeBlockSyntax {
    CodeBlockSyntax {
      // let reference: (Int) -> Int = oldSort
      buildImplementationBinding(for: plan.refParam)

      // let candidate: (Int) -> Int = newSort
      buildImplementationBinding(for: plan.candParam)

      // for _ in 0..<iterations
      ForStmtSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier("_")),
        sequence: InfixOperatorExprSyntax(
          leftOperand: IntegerLiteralExprSyntax(literal: .integerLiteral("0")),
          operator: BinaryOperatorExprSyntax(operator: .binaryOperator("..<")),
          rightOperand: IntegerLiteralExprSyntax(
            literal: .integerLiteral("\(plan.config.iterations)")
          )
        ),
        body: CodeBlockSyntax {
          // var rng = ..., let input = generator.generate(&rng, Size.default)
          for item in buildInputGeneration(generatorExpr: plan.generatorExpr) {
            item
          }

          // let referenceResult = reference(input)
          buildFunctionCall(resultName: "referenceResult", callee: plan.refParam.name, plan: plan)

          // let candidateResult = candidate(input)
          buildFunctionCall(resultName: "candidateResult", callee: plan.candParam.name, plan: plan)

          // Comparison logic (with or without tolerance)
          buildComparisonLogic(config: plan.config)
        }
      )
    }
  }

  /// Binds a parameter's default value to its own name, so the generated peer test can
  /// reach the implementation the annotated function only names as a default.
  private static func buildImplementationBinding(
    for param: ExtractedParameter
  ) -> VariableDeclSyntax {
    VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier(param.name)),
          // Only `@escaping` and friends come off. Dropping every attribute would lose
          // `@MainActor` here, and the assignment would stop compiling.
          typeAnnotation: TypeAnnotationSyntax(
            type: TypeAnalyzer.withoutParameterAttributes(param.type)
          ),
          initializer: param.defaultValue.map { InitializerClauseSyntax(value: $0.trimmed) }
        )
      }
    )
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
    callee: String,
    plan: TestPlan
  ) -> VariableDeclSyntax {
    let arguments = plan.callArguments.joined(separator: ", ")
    let effects = "\(plan.isThrowing ? "try " : "")\(plan.isAsync ? "await " : "")"

    return VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier(resultName)),
          initializer: InitializerClauseSyntax(
            value: MacroExpansionEscapeHatches.expression("\(effects)\(callee)(\(arguments))")
          )
        )
      }
    )
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
