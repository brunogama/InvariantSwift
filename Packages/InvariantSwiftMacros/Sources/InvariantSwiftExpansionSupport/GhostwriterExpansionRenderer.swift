import Foundation
import MacroTemplateKit
import SwiftBasicFormat
import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Public Interface

/// Renders Ghostwriter test plans as Swift source.
public enum GhostwriterExpansionRenderer {
  /// Renders a generated `Generatable` conformance.
  public static func render(
    arbitraryExtension ext: GhostwriterGeneratedArbitraryExtension
  ) -> String {
    let property = MacroTemplateAdapter.makeComputedProperty(
      accessLevel: .public,
      name: "arbitrary",
      type: "Gen<\(ext.typeName)>",
      isStatic: true,
      getterBody: CodeBlockSyntax {
        CodeBlockItemSyntax(
          item: .expr(
            ext.enumCases.isEmpty
              ? composeCall(
                typeName: ext.typeName,
                propertyGenerators: ext.propertyGenerators
              )
              : renderEnumGenerator(typeName: ext.typeName, cases: ext.enumCases)
          )
        )
      }
    )

    let extensionDecl = MacroTemplateAdapter.makeExtension(
      typeName: ext.typeName,
      conformances: ["InvariantSwiftCore.Generatable"]
    )

    let memberBlock = MemberBlockSyntax(
      members: MemberBlockItemListSyntax([
        MemberBlockItemSyntax(decl: DeclSyntax(property))
      ])
    )

    return extensionDecl.with(\.memberBlock, memberBlock).formatted().description
  }

  /// Renders one generated property test.
  public static func render(test: GhostwriterGeneratedTest) -> String {
    let params = FunctionParameterListSyntax(
      test.parameters.enumerated().map { index, param in
        var p = FunctionParameterSyntax(
          firstName: .identifier(param.name),
          colon: .colonToken(trailingTrivia: .space),
          type: TypeSyntax(stringLiteral: param.type)
        )
        if index < test.parameters.count - 1 {
          p = p.with(\.trailingComma, .commaToken(trailingTrivia: .space))
        }
        return p
      }
    )

    let function = MacroTemplateAdapter.makeFunction(
      attributes: [.init("PropertyTest")],
      name: test.functionName,
      canThrow: test.isThrowing,
      body: CodeBlockSyntax(
        statements: CodeBlockItemListSyntax(test.bodyStatements.map(render(statement:)))
      )
    )
    .with(
      \.signature.parameterClause,
      FunctionParameterClauseSyntax(parameters: params)
    )
    .with(\.leadingTrivia, [.docLineComment("/// \(test.docComment)"), .newlines(1)])

    return function.formatted().description
  }

  /// Renders one expression from a generated test plan.
  public static func renderExpression(_ expression: ExpansionExpr) -> String {
    render(expr: expression).description
  }
}

// MARK: - Private Rendering Helpers

extension GhostwriterExpansionRenderer {
  static func render(statement: ExpansionStatement) -> CodeBlockItemSyntax {
    switch statement {
    case .letBinding(let name, let initializer):
      return renderBinding(name: name, initializer: initializer, mutable: false)

    case .varBinding(let name, let initializer):
      return renderBinding(name: name, initializer: initializer, mutable: true)

    case .assignment(let target, let value):
      return CodeBlockItemSyntax(
        item: .expr(
          ExprSyntax(
            SequenceExprSyntax {
              render(expr: target)
              AssignmentExprSyntax()
              render(expr: value)
            }
          )
        )
      )

    case .ifStatement(let condition, let body):
      return CodeBlockItemSyntax(
        item: .expr(
          ExprSyntax(
            IfExprSyntax(
              conditions: ConditionElementListSyntax([
                ConditionElementSyntax(
                  condition: .expression(render(expr: condition))
                )
              ]),
              body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(body.map(render(statement:)))
              )
            )
          )
        )
      )

    case .expression(let expression):
      return CodeBlockItemSyntax(item: .expr(render(expr: expression)))

    case .expect(let condition, let message):
      return GhostwriterExpansionEscapeHatches.renderExpectation(
        condition: render(expr: condition),
        message: message
      )
    }
  }

  static func renderBinding(
    name: String,
    initializer: ExpansionExpr,
    mutable: Bool
  ) -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      item: .decl(
        DeclSyntax(
          VariableDeclSyntax(
            bindingSpecifier: mutable ? .keyword(.var) : .keyword(.let),
            bindings: PatternBindingListSyntax([
              PatternBindingSyntax(
                pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
                initializer: InitializerClauseSyntax(value: render(expr: initializer))
              )
            ])
          )
        )
      )
    )
  }

  static func render(expr: ExpansionExpr) -> ExprSyntax {
    switch expr {
    case .identifier(let name):
      return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))

    case .member(let base, let name):
      return ExprSyntax(
        MemberAccessExprSyntax(
          base: render(expr: base),
          declName: DeclReferenceExprSyntax(baseName: .identifier(name))
        )
      )

    case .call(let callee, let arguments, let trailingClosure):
      return renderCall(
        callee: callee,
        arguments: arguments,
        trailingClosure: trailingClosure
      )

    case .tryExpr(let expression):
      return ExprSyntax(TryExprSyntax(expression: render(expr: expression)))

    case .binary(let lhs, let op, let rhs):
      return ExprSyntax(
        SequenceExprSyntax {
          renderBinaryOperand(lhs)
          BinaryOperatorExprSyntax(operator: .binaryOperator(op))
          renderBinaryOperand(rhs)
        }
      )

    case .prefix(let op, let expression):
      return ExprSyntax(
        PrefixOperatorExprSyntax(
          operator: .prefixOperator(op),
          expression: renderBinaryOperand(expression)
        )
      )

    case .array(let expressions):
      return renderArray(expressions)

    case .tuple(let expressions):
      return ExprSyntax(
        TupleExprSyntax(
          elements: LabeledExprListSyntax(
            expressions.map { expression in
              LabeledExprSyntax(expression: render(expr: expression))
            }
          )
        )
      )

    case .exactlyOneTrue(let expressions):
      return GhostwriterExpansionEscapeHatches.renderExactlyOneTrue(
        expressions.map(render(expr:))
      )
    }
  }

  static func renderBinaryOperand(_ expression: ExpansionExpr) -> ExprSyntax {
    let rendered = render(expr: expression)
    guard case .binary = expression else { return rendered }
    return ExprSyntax(
      TupleExprSyntax(
        elements: LabeledExprListSyntax([
          LabeledExprSyntax(expression: rendered)
        ])
      )
    )
  }

  static func renderCall(
    callee: ExpansionExpr,
    arguments: [ExpansionArgument],
    trailingClosure: ExpansionClosure?
  ) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: render(expr: callee),
        leftParen: trailingClosure == nil ? .leftParenToken() : nil,
        arguments: LabeledExprListSyntax(
          arguments.enumerated().map { index, argument in
            var rendered = render(argument: argument)
            if index < arguments.count - 1 {
              rendered = rendered.with(\.trailingComma, .commaToken(trailingTrivia: .space))
            }
            return rendered
          }
        ),
        rightParen: trailingClosure == nil ? .rightParenToken() : nil,
        trailingClosure: trailingClosure.map(render(closure:))
      )
    )
  }

  static func render(argument: ExpansionArgument) -> LabeledExprSyntax {
    LabeledExprSyntax(
      label: argument.label.map { .identifier($0) },
      colon: argument.label == nil ? nil : .colonToken(trailingTrivia: .space),
      expression: render(expr: argument.expression)
    )
  }

  static func render(closure: ExpansionClosure) -> ClosureExprSyntax {
    ClosureExprSyntax(
      signature: closure.parameters.isEmpty
        ? nil
        : ClosureSignatureSyntax(
          parameterClause: .simpleInput(
            ClosureShorthandParameterListSyntax(
              closure.parameters.map { name in
                ClosureShorthandParameterSyntax(name: .identifier(name))
              }
            )
          ),
          inKeyword: .keyword(.in, trailingTrivia: .space)
        ),
      statements: CodeBlockItemListSyntax(closure.bodyStatements.map(render(statement:)))
    )
  }

  static func composeCall(
    typeName: String,
    propertyGenerators: [GhostwriterPropertyGenerator]
  ) -> ExprSyntax {
    let typeCallExpr = generatedTypeCall(
      typeName: typeName,
      propertyGenerators: propertyGenerators
    )
    if propertyGenerators.isEmpty {
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: ExprSyntax(
            MemberAccessExprSyntax(
              base: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("Gen"))),
              declName: DeclReferenceExprSyntax(baseName: .identifier("pure"))
            )
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax([
            LabeledExprSyntax(expression: ExprSyntax(typeCallExpr))
          ]),
          rightParen: .rightParenToken()
        )
      )
    }

    var result = ExprSyntax(typeCallExpr)
    for index in propertyGenerators.indices.reversed() {
      result = wrapGenerator(
        propertyGenerators[index],
        index: index,
        isLast: index == propertyGenerators.count - 1,
        result: result
      )
    }
    return result
  }

  static func generatedTypeCall(
    typeName: String,
    propertyGenerators: [GhostwriterPropertyGenerator]
  ) -> FunctionCallExprSyntax {
    let arguments = propertyGenerators.enumerated().map { index, generator in
      var labeledExpr = LabeledExprSyntax(
        label: .identifier(generator.name),
        colon: .colonToken(trailingTrivia: .space),
        expression: ExprSyntax(
          DeclReferenceExprSyntax(baseName: .identifier("value\(index)"))
        )
      )
      if index < propertyGenerators.count - 1 {
        labeledExpr = labeledExpr.with(\.trailingComma, .commaToken())
      }
      return labeledExpr as LabeledExprSyntax
    }

    return FunctionCallExprSyntax(
      calledExpression: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(typeName))),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(arguments),
      rightParen: .rightParenToken()
    )
  }

  static func wrapGenerator(
    _ generator: GhostwriterPropertyGenerator,
    index: Int,
    isLast: Bool,
    result: ExprSyntax
  ) -> ExprSyntax {
    let method = isLast ? "map" : "flatMap"
    let closure = ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax([
            ClosureShorthandParameterSyntax(name: .identifier("value\(index)"))
          ])
        ),
        inKeyword: .keyword(.in, trailingTrivia: .space)
      ),
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .expr(result))
      ])
    )
    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
          MemberAccessExprSyntax(
            base: propertyExpression(for: generator),
            declName: DeclReferenceExprSyntax(baseName: .identifier(method))
          )
        ),
        leftParen: nil,
        arguments: LabeledExprListSyntax([]),
        rightParen: nil,
        trailingClosure: closure
      )
    )
  }

  static func propertyExpression(
    for property: GhostwriterPropertyGenerator
  ) -> ExprSyntax {
    let expression = render(expr: property.expression)
    guard let todoComment = property.todoComment else {
      return expression
    }
    return expression.with(\.leadingTrivia, [.blockComment(todoComment), .spaces(1)])
  }
}
