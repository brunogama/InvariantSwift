/// RuleBasedTestMacro - Member macro for rule-based state machine tests
///
/// Implements `@RuleBasedTest` from ISP-0003 for declarative stateful testing.
/// Uses proper SwiftSyntax AST builders for code generation.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// `@RuleBasedTest` macro for declarative stateful testing.
///
/// Transforms a struct with `@Rule`, `@Bundle`, and `@Invariant` annotations
/// into a runnable state machine test.
public struct RuleBasedTestMacro: MemberMacro, ExtensionMacro {

  // MARK: - MemberMacro

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    let ctx = MacroContext(context: context)

    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      ctx.error(RuleBasedTestMacroDiagnostic.mustBeStruct, at: node)
      return []
    }

    let typeName = structDecl.name.text

    // Extract configuration from attribute
    let config = extractConfiguration(from: node)

    // Collect rules, invariants, and bundles from the struct
    let rules = collectRules(from: structDecl)
    let invariants = collectInvariants(from: structDecl)
    let bundles = collectBundles(from: structDecl)

    // Generate static rules property
    let rulesDecl = try generateRulesProperty(rules: rules, typeName: typeName)

    // Generate static invariants property
    let invariantsDecl = try generateInvariantsProperty(
      invariants: invariants,
      typeName: typeName
    )

    // Generate static bundles property
    let bundlesDecl = try generateBundlesProperty(bundles: bundles, typeName: typeName)

    // Generate run method
    let runDecl = try generateRunMethod(config: config)

    return [rulesDecl, invariantsDecl, bundlesDecl, runDecl]
  }

  // MARK: - ExtensionMacro

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let inheritanceClause = InheritanceClauseSyntax {
      InheritedTypeSyntax(
        type: IdentifierTypeSyntax(name: .identifier("RuleBasedStateMachine"))
      )
    }

    let ext = ExtensionDeclSyntax(
      extendedType: type,
      inheritanceClause: inheritanceClause,
      memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
    )
    return [ext]
  }

  // MARK: - Configuration Extraction

  private static func extractConfiguration(from node: AttributeSyntax) -> Configuration {
    var maxSteps = 100
    var maxExamples = 100

    if let args = node.arguments?.as(LabeledExprListSyntax.self) {
      for arg in args {
        if arg.label?.text == "maxSteps",
          let literal = arg.expression.as(IntegerLiteralExprSyntax.self)
        {
          maxSteps = Int(literal.literal.text) ?? 100
        }
        if arg.label?.text == "maxExamples",
          let literal = arg.expression.as(IntegerLiteralExprSyntax.self)
        {
          maxExamples = Int(literal.literal.text) ?? 100
        }
      }
    }

    return Configuration(maxSteps: maxSteps, maxExamples: maxExamples)
  }

  // MARK: - Collection Methods

  private static func collectRules(from structDecl: StructDeclSyntax) -> [RuleInfo] {
    var rules: [RuleInfo] = []

    for member in structDecl.memberBlock.members {
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }

      // Check for @Rule attribute
      let hasRule = funcDecl.attributes.contains { attr in
        if let identAttr = attr.as(AttributeSyntax.self),
          let ident = identAttr.attributeName.as(IdentifierTypeSyntax.self)
        {
          return ident.name.text == "Rule"
        }
        return false
      }

      guard hasRule else { continue }

      // Extract precondition if present
      let precondition = extractPrecondition(from: funcDecl)

      // Extract weight from @Rule attribute
      let weight = extractWeight(from: funcDecl)

      rules.append(
        RuleInfo(
          name: funcDecl.name.text,
          weight: weight,
          preconditionExpr: precondition,
          isMutating: funcDecl.modifiers.contains { $0.name.text == "mutating" }
        )
      )
    }

    return rules
  }

  private static func collectInvariants(from structDecl: StructDeclSyntax) -> [InvariantInfo] {
    var invariants: [InvariantInfo] = []

    for member in structDecl.memberBlock.members {
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }

      // Check for @Invariant attribute
      let hasInvariant = funcDecl.attributes.contains { attr in
        if let identAttr = attr.as(AttributeSyntax.self),
          let ident = identAttr.attributeName.as(IdentifierTypeSyntax.self)
        {
          return ident.name.text == "Invariant"
        }
        return false
      }

      guard hasInvariant else { continue }

      invariants.append(InvariantInfo(name: funcDecl.name.text))
    }

    return invariants
  }

  private static func collectBundles(from structDecl: StructDeclSyntax) -> [BundleInfo] {
    var bundles: [BundleInfo] = []

    for member in structDecl.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

      // Check for @Bundle attribute
      let hasBundle = varDecl.attributes.contains { attr in
        if let identAttr = attr.as(AttributeSyntax.self),
          let ident = identAttr.attributeName.as(IdentifierTypeSyntax.self)
        {
          return ident.name.text == "Bundle"
        }
        return false
      }

      guard hasBundle else { continue }

      for binding in varDecl.bindings {
        if let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
          bundles.append(BundleInfo(name: name))
        }
      }
    }

    return bundles
  }

  private static func extractPrecondition(from funcDecl: FunctionDeclSyntax) -> ExprSyntax? {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self),
        let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self),
        ident.name.text == "Precondition"
      else { continue }

      // Extract the closure from @Precondition({ ... })
      if let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self),
        let firstArg = args.first
      {
        return firstArg.expression
      }
    }
    return nil
  }

  private static func extractWeight(from funcDecl: FunctionDeclSyntax) -> Int {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self),
        let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self),
        ident.name.text == "Rule"
      else { continue }

      if let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self) {
        for arg in args where arg.label?.text == "weight" {
          if let literal = arg.expression.as(IntegerLiteralExprSyntax.self) {
            return Int(literal.literal.text) ?? 1
          }
        }
      }
    }
    return 1
  }

  // MARK: - AST-Based Code Generation

  private static func generateRulesProperty(
    rules: [RuleInfo],
    typeName: String
  ) throws
    -> DeclSyntax
  {
    // Build array elements
    var arrayElements: [ArrayElementSyntax] = []

    for (index, rule) in rules.enumerated() {
      let ruleExpr = buildAnyRuleExpr(rule: rule)
      let element = ArrayElementSyntax(
        expression: ruleExpr,
        trailingComma: index < rules.count - 1 ? .commaToken() : nil
      )
      arrayElements.append(element)
    }

    // Build array literal
    let arrayExpr = ArrayExprSyntax(
      elements: ArrayElementListSyntax(arrayElements)
    )

    // Build return statement
    let returnStmt = ReturnStmtSyntax(expression: arrayExpr)

    // Build code block
    let codeBlock = CodeBlockSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
      ])
    )

    // Build type annotation: [AnyRule<TypeName>]
    let elementType = GenericArgumentClauseSyntax(
      arguments: GenericArgumentListSyntax([
        GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier(typeName)))
      ])
    )

    let arrayType = ArrayTypeSyntax(
      element: IdentifierTypeSyntax(
        name: .identifier("AnyRule"),
        genericArgumentClause: elementType
      )
    )

    let typeAnnotation = TypeAnnotationSyntax(type: arrayType)

    // Build property with computed getter
    let accessor = AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: codeBlock
    )

    let accessorBlock = AccessorBlockSyntax(
      accessors: .accessors(AccessorDeclListSyntax([accessor]))
    )

    let binding = PatternBindingSyntax(
      pattern: IdentifierPatternSyntax(identifier: .identifier("rules")),
      typeAnnotation: typeAnnotation,
      accessorBlock: accessorBlock
    )

    let varDecl = VariableDeclSyntax(
      modifiers: DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.static))
      ]),
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax([binding])
    )

    return DeclSyntax(varDecl)
  }

  private static func buildAnyRuleExpr(rule: RuleInfo) -> FunctionCallExprSyntax {
    // Build: AnyRule(name: "ruleName", weight: 1, precondition: { ... }, execute: { ... })

    var arguments: [LabeledExprSyntax] = []

    // name: "ruleName"
    arguments.append(
      LabeledExprSyntax(
        label: .identifier("name"),
        colon: .colonToken(),
        expression: StringLiteralExprSyntax(content: rule.name),
        trailingComma: .commaToken()
      )
    )

    // weight: N
    arguments.append(
      LabeledExprSyntax(
        label: .identifier("weight"),
        colon: .colonToken(),
        expression: IntegerLiteralExprSyntax(integerLiteral: rule.weight),
        trailingComma: .commaToken()
      )
    )

    // precondition: { ... } or { _ in true }
    let preconditionExpr: ExprSyntax =
      rule.preconditionExpr
      ?? ExprSyntax(
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
      )

    arguments.append(
      LabeledExprSyntax(
        label: .identifier("precondition"),
        colon: .colonToken(),
        expression: preconditionExpr,
        trailingComma: .commaToken()
      )
    )

    // execute: { state in state.ruleName() }
    let executeExpr = ClosureExprSyntax(
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
                  declName: DeclReferenceExprSyntax(baseName: .identifier(rule.name))
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

    arguments.append(
      LabeledExprSyntax(
        label: .identifier("execute"),
        colon: .colonToken(),
        expression: ExprSyntax(executeExpr)
      )
    )

    return FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("AnyRule")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(arguments),
      rightParen: .rightParenToken()
    )
  }

  private static func generateInvariantsProperty(
    invariants: [InvariantInfo],
    typeName: String
  ) throws -> DeclSyntax {
    // Build array elements: [("name", { $0.name() }), ...]
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

    // Type: [(String, (TypeName) -> Bool)]
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
    let typeAnnotation = TypeAnnotationSyntax(type: arrayType)

    let accessor = AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: codeBlock
    )

    let accessorBlock = AccessorBlockSyntax(
      accessors: .accessors(AccessorDeclListSyntax([accessor]))
    )

    let binding = PatternBindingSyntax(
      pattern: IdentifierPatternSyntax(identifier: .identifier("invariants")),
      typeAnnotation: typeAnnotation,
      accessorBlock: accessorBlock
    )

    let varDecl = VariableDeclSyntax(
      modifiers: DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.static))
      ]),
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax([binding])
    )

    return DeclSyntax(varDecl)
  }

  private static func buildInvariantTuple(invariant: InvariantInfo) -> TupleExprSyntax {
    // Build: ("invariantName", { $0.invariantName() })
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

  private static func generateBundlesProperty(
    bundles: [BundleInfo],
    typeName: String
  ) throws
    -> DeclSyntax
  {
    // Build array elements
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

    // Type: [AnyBundle<TypeName>]
    let elementType = GenericArgumentClauseSyntax(
      arguments: GenericArgumentListSyntax([
        GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier(typeName)))
      ])
    )

    let arrayType = ArrayTypeSyntax(
      element: IdentifierTypeSyntax(
        name: .identifier("AnyBundle"),
        genericArgumentClause: elementType
      )
    )

    let typeAnnotation = TypeAnnotationSyntax(type: arrayType)

    let accessor = AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: codeBlock
    )

    let accessorBlock = AccessorBlockSyntax(
      accessors: .accessors(AccessorDeclListSyntax([accessor]))
    )

    let binding = PatternBindingSyntax(
      pattern: IdentifierPatternSyntax(identifier: .identifier("bundles")),
      typeAnnotation: typeAnnotation,
      accessorBlock: accessorBlock
    )

    let varDecl = VariableDeclSyntax(
      modifiers: DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.static))
      ]),
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax([binding])
    )

    return DeclSyntax(varDecl)
  }

  private static func buildAnyBundleExpr(bundle: BundleInfo) -> FunctionCallExprSyntax {
    // Build: AnyBundle(name: "bundleName", count: { $0.bundleName.count }, isEmpty: { $0.bundleName.isEmpty })

    var arguments: [LabeledExprSyntax] = []

    // name: "bundleName"
    arguments.append(
      LabeledExprSyntax(
        label: .identifier("name"),
        colon: .colonToken(),
        expression: StringLiteralExprSyntax(content: bundle.name),
        trailingComma: .commaToken()
      )
    )

    // count: { $0.bundleName.count }
    let countClosure = ClosureExprSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(
          item: .expr(
            ExprSyntax(
              MemberAccessExprSyntax(
                base: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")),
                  declName: DeclReferenceExprSyntax(baseName: .identifier(bundle.name))
                ),
                declName: DeclReferenceExprSyntax(baseName: .identifier("count"))
              )
            )
          )
        )
      ])
    )

    arguments.append(
      LabeledExprSyntax(
        label: .identifier("count"),
        colon: .colonToken(),
        expression: ExprSyntax(countClosure),
        trailingComma: .commaToken()
      )
    )

    // isEmpty: { $0.bundleName.isEmpty }
    let isEmptyClosure = ClosureExprSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(
          item: .expr(
            ExprSyntax(
              MemberAccessExprSyntax(
                base: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")),
                  declName: DeclReferenceExprSyntax(baseName: .identifier(bundle.name))
                ),
                declName: DeclReferenceExprSyntax(baseName: .identifier("isEmpty"))
              )
            )
          )
        )
      ])
    )

    arguments.append(
      LabeledExprSyntax(
        label: .identifier("isEmpty"),
        colon: .colonToken(),
        expression: ExprSyntax(isEmptyClosure)
      )
    )

    return FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("AnyBundle")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(arguments),
      rightParen: .rightParenToken()
    )
  }

  private static func generateRunMethod(config: Configuration) throws -> DeclSyntax {
    // Build: @MainActor static func runTest() async throws { try await run(maxSteps: N, maxExamples: M) }

    // Build function call: run(maxSteps: N, maxExamples: M)
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

    // Build: try await run(...)
    let tryAwaitExpr = TryExprSyntax(
      expression: AwaitExprSyntax(expression: ExprSyntax(runCall))
    )

    let codeBlock = CodeBlockSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .expr(ExprSyntax(tryAwaitExpr)))
      ])
    )

    // Build function signature
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

// MARK: - Supporting Types

struct Configuration {
  let maxSteps: Int
  let maxExamples: Int
}

struct RuleInfo {
  let name: String
  let weight: Int
  let preconditionExpr: ExprSyntax?
  let isMutating: Bool
}

struct InvariantInfo {
  let name: String
}

struct BundleInfo {
  let name: String
}

// MARK: - Diagnostics

public enum RuleBasedTestMacroDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.RuleBasedTestMacro"

  case mustBeStruct = "must_be_struct"
  case noRules = "no_rules"
  case invalidRuleSignature = "invalid_rule_signature"
  case invalidInvariantReturn = "invalid_invariant_return"

  public var severity: DiagnosticSeverity { .error }

  public var message: String {
    switch self {
    case .mustBeStruct:
      return "@RuleBasedTest can only be applied to structs"

    case .noRules:
      return "@RuleBasedTest requires at least one @Rule method"

    case .invalidRuleSignature:
      return "@Rule must be applied to a mutating method with no parameters"

    case .invalidInvariantReturn:
      return "@Invariant must be applied to a method returning Bool"
    }
  }
}

// Legacy error type for backward compatibility
enum RuleBasedTestMacroError: Error, CustomStringConvertible {
  case notAStruct
  case invalidConfiguration

  var description: String {
    switch self {
    case .notAStruct:
      return "@RuleBasedTest can only be applied to structs"

    case .invalidConfiguration:
      return "@RuleBasedTest has invalid configuration"
    }
  }
}
