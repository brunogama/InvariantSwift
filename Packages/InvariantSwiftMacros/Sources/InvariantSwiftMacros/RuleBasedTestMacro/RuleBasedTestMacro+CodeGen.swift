import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - AST-Based Code Generation

extension RuleBasedTestMacro {

  static func generateRulesProperty(
    rules: [RuleInfo],
    typeName: String
  ) throws
    -> DeclSyntax
  {
    var arrayElements: [ArrayElementSyntax] = []

    for (index, rule) in rules.enumerated() {
      let ruleExpr = buildAnyRuleExpr(rule: rule)
      let element = ArrayElementSyntax(
        expression: ruleExpr,
        trailingComma: index < rules.count - 1 ? .commaToken() : nil
      )
      arrayElements.append(element)
    }

    let arrayExpr = ArrayExprSyntax(
      elements: ArrayElementListSyntax(arrayElements)
    )

    let returnStmt = ReturnStmtSyntax(expression: arrayExpr)
    let codeBlock = CodeBlockSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
      ])
    )

    let elementType = GenericArgumentClauseSyntax(
      arguments: GenericArgumentListSyntax([
        GenericArgumentSyntax(
          argument: .init(IdentifierTypeSyntax(name: .identifier(typeName)))
        )
      ])
    )

    let arrayType = ArrayTypeSyntax(
      element: IdentifierTypeSyntax(
        name: .identifier("AnyRule"),
        genericArgumentClause: elementType
      )
    )

    return DeclSyntax(buildStaticComputedVar(name: "rules", type: arrayType, body: codeBlock))
  }

  static func generateInvariantsProperty(
    invariants: [InvariantInfo],
    typeName: String
  ) throws -> DeclSyntax {
    var arrayElements: [ArrayElementSyntax] = []

    for (index, invariant) in invariants.enumerated() {
      let tupleExpr = buildInvariantTuple(invariant: invariant)
      let element = ArrayElementSyntax(
        expression: tupleExpr,
        trailingComma: index < invariants.count - 1 ? .commaToken() : nil
      )
      arrayElements.append(element)
    }

    let arrayExpr = ArrayExprSyntax(
      elements: ArrayElementListSyntax(arrayElements)
    )

    let returnStmt = ReturnStmtSyntax(expression: arrayExpr)
    let codeBlock = CodeBlockSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
      ])
    )

    let tupleType = TupleTypeSyntax(
      elements: TupleTypeElementListSyntax([
        TupleTypeElementSyntax(
          type: IdentifierTypeSyntax(name: .identifier("String")),
          trailingComma: .commaToken()
        ),
        TupleTypeElementSyntax(
          type: FunctionTypeSyntax(
            parameters: TupleTypeElementListSyntax([
              TupleTypeElementSyntax(
                type: IdentifierTypeSyntax(name: .identifier(typeName))
              )
            ]),
            returnClause: ReturnClauseSyntax(
              type: IdentifierTypeSyntax(name: .identifier("Bool"))
            )
          )
        ),
      ])
    )

    let arrayType = ArrayTypeSyntax(element: tupleType)
    return DeclSyntax(buildStaticComputedVar(name: "invariants", type: arrayType, body: codeBlock))
  }

  static func generateBundlesProperty(
    bundles: [BundleInfo],
    typeName: String
  ) throws
    -> DeclSyntax
  {
    var arrayElements: [ArrayElementSyntax] = []

    for (index, bundle) in bundles.enumerated() {
      let bundleExpr = buildAnyBundleExpr(bundle: bundle)
      let element = ArrayElementSyntax(
        expression: bundleExpr,
        trailingComma: index < bundles.count - 1 ? .commaToken() : nil
      )
      arrayElements.append(element)
    }

    let arrayExpr = ArrayExprSyntax(
      elements: ArrayElementListSyntax(arrayElements)
    )

    let returnStmt = ReturnStmtSyntax(expression: arrayExpr)
    let codeBlock = CodeBlockSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
      ])
    )

    let elementType = GenericArgumentClauseSyntax(
      arguments: GenericArgumentListSyntax([
        GenericArgumentSyntax(
          argument: .init(IdentifierTypeSyntax(name: .identifier(typeName)))
        )
      ])
    )

    let arrayType = ArrayTypeSyntax(
      element: IdentifierTypeSyntax(
        name: .identifier("AnyBundle"),
        genericArgumentClause: elementType
      )
    )

    return DeclSyntax(buildStaticComputedVar(name: "bundles", type: arrayType, body: codeBlock))
  }

  static func generateRunMethod(config: RuleBasedTestConfiguration) throws -> DeclSyntax {
    let runCall = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("run")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax([
        LabeledExprSyntax(
          label: .identifier("maxSteps"),
          colon: .colonToken(),
          expression: IntegerLiteralExprSyntax(integerLiteral: config.maxSteps),
          trailingComma: .commaToken()
        ),
        LabeledExprSyntax(
          label: .identifier("maxExamples"),
          colon: .colonToken(),
          expression: IntegerLiteralExprSyntax(integerLiteral: config.maxExamples)
        ),
      ]),
      rightParen: .rightParenToken()
    )

    let tryAwaitExpr = TryExprSyntax(
      expression: AwaitExprSyntax(expression: ExprSyntax(runCall))
    )

    let codeBlock = CodeBlockSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .expr(ExprSyntax(tryAwaitExpr)))
      ])
    )

    let funcDecl = FunctionDeclSyntax(
      attributes: AttributeListSyntax([
        .attribute(
          AttributeSyntax(
            attributeName: IdentifierTypeSyntax(name: .identifier("MainActor"))
          )
        )
      ]),
      modifiers: DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.static))
      ]),
      funcKeyword: .keyword(.func),
      name: .identifier("runTest"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax([])
        ),
        effectSpecifiers: FunctionEffectSpecifiersSyntax(
          asyncSpecifier: .keyword(.async),
          throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        )
      ),
      body: codeBlock
    )

    return DeclSyntax(funcDecl)
  }
}

// MARK: - Private Helpers

extension RuleBasedTestMacro {

  private static func buildAnyRuleExpr(rule: RuleInfo) -> FunctionCallExprSyntax {
    let nameArg = LabeledExprSyntax(
      label: .identifier("name"),
      colon: .colonToken(),
      expression: StringLiteralExprSyntax(content: rule.name),
      trailingComma: .commaToken()
    )

    let weightArg = LabeledExprSyntax(
      label: .identifier("weight"),
      colon: .colonToken(),
      expression: IntegerLiteralExprSyntax(integerLiteral: rule.weight),
      trailingComma: .commaToken()
    )

    let preconditionExpr: ExprSyntax =
      rule.preconditionExpr ?? ExprSyntax(buildDefaultPreconditionClosure())

    let preconditionArg = LabeledExprSyntax(
      label: .identifier("precondition"),
      colon: .colonToken(),
      expression: preconditionExpr,
      trailingComma: .commaToken()
    )

    let executeArg = LabeledExprSyntax(
      label: .identifier("execute"),
      colon: .colonToken(),
      expression: ExprSyntax(buildExecuteClosure(ruleName: rule.name))
    )

    return FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("AnyRule")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax([nameArg, weightArg, preconditionArg, executeArg]),
      rightParen: .rightParenToken()
    )
  }

  private static func buildDefaultPreconditionClosure() -> ClosureExprSyntax {
    ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax([
            ClosureShorthandParameterSyntax(name: .identifier("_"))
          ])
        ),
        inKeyword: .keyword(.in)
      ),
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(
          item: .expr(ExprSyntax(BooleanLiteralExprSyntax(booleanLiteral: true)))
        )
      ])
    )
  }

  private static func buildExecuteClosure(ruleName: String) -> ClosureExprSyntax {
    ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax([
            ClosureShorthandParameterSyntax(name: .identifier("state"))
          ])
        ),
        inKeyword: .keyword(.in)
      ),
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(
          item: .expr(
            ExprSyntax(
              FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .identifier("state")),
                  declName: DeclReferenceExprSyntax(baseName: .identifier(ruleName))
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax([]),
                rightParen: .rightParenToken()
              )
            )
          )
        )
      ])
    )
  }

  private static func buildInvariantTuple(invariant: InvariantInfo) -> TupleExprSyntax {
    let nameLiteral = StringLiteralExprSyntax(content: invariant.name)

    let closureExpr = ClosureExprSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(
          item: .expr(
            ExprSyntax(
              FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")),
                  declName: DeclReferenceExprSyntax(baseName: .identifier(invariant.name))
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax([]),
                rightParen: .rightParenToken()
              )
            )
          )
        )
      ])
    )

    return TupleExprSyntax(
      elements: LabeledExprListSyntax([
        LabeledExprSyntax(expression: ExprSyntax(nameLiteral), trailingComma: .commaToken()),
        LabeledExprSyntax(expression: ExprSyntax(closureExpr)),
      ])
    )
  }

  private static func buildAnyBundleExpr(bundle: BundleInfo) -> FunctionCallExprSyntax {
    let nameArg = LabeledExprSyntax(
      label: .identifier("name"),
      colon: .colonToken(),
      expression: StringLiteralExprSyntax(content: bundle.name),
      trailingComma: .commaToken()
    )

    let countArg = LabeledExprSyntax(
      label: .identifier("count"),
      colon: .colonToken(),
      expression: ExprSyntax(buildBundleMemberClosure(bundleName: bundle.name, member: "count")),
      trailingComma: .commaToken()
    )

    let isEmptyArg = LabeledExprSyntax(
      label: .identifier("isEmpty"),
      colon: .colonToken(),
      expression: ExprSyntax(
        buildBundleMemberClosure(bundleName: bundle.name, member: "isEmpty")
      )
    )

    return FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("AnyBundle")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax([nameArg, countArg, isEmptyArg]),
      rightParen: .rightParenToken()
    )
  }

  private static func buildBundleMemberClosure(
    bundleName: String,
    member: String
  ) -> ClosureExprSyntax {
    ClosureExprSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(
          item: .expr(
            ExprSyntax(
              MemberAccessExprSyntax(
                base: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")),
                  declName: DeclReferenceExprSyntax(baseName: .identifier(bundleName))
                ),
                declName: DeclReferenceExprSyntax(baseName: .identifier(member))
              )
            )
          )
        )
      ])
    )
  }

  private static func buildStaticComputedVar(
    name: String,
    type: some TypeSyntaxProtocol,
    body: CodeBlockSyntax
  ) -> VariableDeclSyntax {
    let accessor = AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: body
    )

    let accessorBlock = AccessorBlockSyntax(
      accessors: .accessors(AccessorDeclListSyntax([accessor]))
    )

    let binding = PatternBindingSyntax(
      pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
      typeAnnotation: TypeAnnotationSyntax(type: TypeSyntax(type)),
      accessorBlock: accessorBlock
    )

    return VariableDeclSyntax(
      modifiers: DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.static))
      ]),
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax([binding])
    )
  }
}
