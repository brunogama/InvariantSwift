import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder

struct SwiftTestingTraitConfig {
  let enabledCondition: ExprSyntax?
  let disabledReason: ExprSyntax?
  let serialized: Bool
  let timeLimit: ExprSyntax?
  let tags: [ExprSyntax]
  let bugs: [ExprSyntax]

  static let empty = Self(
    enabledCondition: nil,
    disabledReason: nil,
    serialized: false,
    timeLimit: nil,
    tags: [],
    bugs: []
  )

  var hasConflictingConditions: Bool {
    enabledCondition != nil && disabledReason != nil
  }
}

enum SwiftTestingTraitExtractor {
  static func extract(from attribute: AttributeSyntax) -> SwiftTestingTraitConfig {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
      return .empty
    }

    var enabledCondition: ExprSyntax?
    var disabledReason: ExprSyntax?
    var serialized = false
    var timeLimit: ExprSyntax?
    var tags: [ExprSyntax] = []
    var bugs: [ExprSyntax] = []

    for argument in arguments {
      let label = argument.label?.text

      enabledCondition = enabledCondition ?? optionalExpression(argument, named: "enabledIf")
      disabledReason = disabledReason ?? optionalExpression(argument, named: "disabledReason")
      timeLimit = timeLimit ?? optionalExpression(argument, named: "timeLimit")
      serialized = serialized || booleanValue(argument, named: "serialized")

      if label == "tags" {
        tags = arrayElements(from: argument.expression)
      } else if label == "bugs" {
        bugs = arrayElements(from: argument.expression)
      }
    }

    return SwiftTestingTraitConfig(
      enabledCondition: enabledCondition,
      disabledReason: disabledReason,
      serialized: serialized,
      timeLimit: timeLimit,
      tags: tags,
      bugs: bugs
    )
  }

  private static func arrayElements(from expression: ExprSyntax) -> [ExprSyntax] {
    guard let arrayExpr = expression.as(ArrayExprSyntax.self) else {
      return []
    }

    return arrayExpr.elements.map(\.expression)
  }

  private static func optionalExpression(
    _ argument: LabeledExprSyntax,
    named label: String
  ) -> ExprSyntax? {
    guard argument.label?.text == label, !argument.expression.is(NilLiteralExprSyntax.self) else {
      return nil
    }

    return argument.expression
  }

  private static func booleanValue(
    _ argument: LabeledExprSyntax,
    named label: String
  ) -> Bool {
    guard
      argument.label?.text == label,
      let literal = argument.expression.as(BooleanLiteralExprSyntax.self)
    else {
      return false
    }

    return literal.literal.tokenKind == .keyword(.true)
  }
}

struct GeneratedTestAttributeRequest {
  let displayName: String
  let traits: SwiftTestingTraitConfig
  let labels: [String]
  let configuredSeed: UInt64?
  let includeReplayTag: Bool
  let arguments: ExprSyntax?
}

enum SwiftTestingTraitBuilder {
  static func buildTestAttribute(
    _ request: GeneratedTestAttributeRequest
  ) -> AttributeListSyntax {
    var argumentList: [LabeledExprSyntax] = [
      LabeledExprSyntax(
        expression: ExprSyntax(StringLiteralExprSyntax(content: request.displayName))
      )
    ]

    for traitExpression in buildTraitExpressions(request) {
      argumentList.append(LabeledExprSyntax(expression: traitExpression))
    }

    if let arguments = request.arguments {
      argumentList.append(
        LabeledExprSyntax(
          label: .identifier("arguments"),
          colon: .colonToken(),
          expression: arguments
        )
      )
    }

    let separatedArguments = argumentList.enumerated().map { index, argument in
      guard index < argumentList.count - 1 else {
        return argument
      }

      return argument.with(\.trailingComma, .commaToken())
    }

    return AttributeListSyntax {
      AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("Test")),
        leftParen: .leftParenToken(),
        arguments: .argumentList(LabeledExprListSyntax(separatedArguments)),
        rightParen: .rightParenToken()
      )
    }
  }

  private static func buildTraitExpressions(
    _ request: GeneratedTestAttributeRequest
  ) -> [ExprSyntax] {
    var expressions: [ExprSyntax] = [makeExecutionTraitExpr(request)]

    if let enabledCondition = request.traits.enabledCondition {
      expressions.append(makeEnabledTraitExpr(enabledCondition))
    } else if let disabledReason = request.traits.disabledReason {
      expressions.append(makeDisabledTraitExpr(disabledReason))
    }

    if request.traits.serialized {
      expressions.append(makeSerializedExpr())
    }

    if let timeLimit = request.traits.timeLimit {
      expressions.append(makeTimeLimitExpr(timeLimit))
    }

    expressions.append(makeTagsExpr(request))
    expressions.append(contentsOf: request.traits.bugs)

    return expressions
  }

  /// Builds `InvariantSwiftPropertyExecutionTrait(testName:labels:configuredSeed:)`.
  ///
  /// Uses `MacroTemplateKit.Renderer` for string and array literals. The seed is
  /// rendered as an integer literal via SwiftSyntax directly because `Template`
  /// only supports `Int` and UInt64 requires a raw token to avoid overflow.
  private static func makeExecutionTraitExpr(
    _ request: GeneratedTestAttributeRequest
  ) -> ExprSyntax {
    let testNameExpr = MacroTemplateKit.Renderer.render(
      Template<Void>.literal(request.displayName)
    )
    let labelsExpr = MacroTemplateKit.Renderer.render(
      Template<Void>.arrayLiteral(request.labels.map { .literal($0) })
    )
    let seedExpr: ExprSyntax =
      request.configuredSeed.map {
        ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral(String($0))))
      } ?? MacroTemplateKit.Renderer.render(Template<Void>.nilLiteral())

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
          DeclReferenceExprSyntax(
            baseName: .identifier("InvariantSwiftPropertyExecutionTrait")
          )
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax([
          LabeledExprSyntax(
            label: .identifier("testName"),
            colon: .colonToken(),
            expression: testNameExpr,
            trailingComma: .commaToken()
          ),
          LabeledExprSyntax(
            label: .identifier("labels"),
            colon: .colonToken(),
            expression: labelsExpr,
            trailingComma: .commaToken()
          ),
          LabeledExprSyntax(
            label: .identifier("configuredSeed"),
            colon: .colonToken(),
            expression: seedExpr
          ),
        ]),
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds `.enabled(if: condition)`.
  private static func makeEnabledTraitExpr(_ condition: ExprSyntax) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
          MemberAccessExprSyntax(
            declName: DeclReferenceExprSyntax(baseName: .identifier("enabled"))
          )
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax([
          LabeledExprSyntax(
            label: .identifier("if"),
            colon: .colonToken(),
            expression: condition
          )
        ]),
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds `.disabled(Comment(rawValue: reason))`.
  private static func makeDisabledTraitExpr(_ reason: ExprSyntax) -> ExprSyntax {
    let commentExpr = ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
          DeclReferenceExprSyntax(baseName: .identifier("Comment"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax([
          LabeledExprSyntax(
            label: .identifier("rawValue"),
            colon: .colonToken(),
            expression: reason
          )
        ]),
        rightParen: .rightParenToken()
      )
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
          MemberAccessExprSyntax(
            declName: DeclReferenceExprSyntax(baseName: .identifier("disabled"))
          )
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax([
          LabeledExprSyntax(expression: commentExpr)
        ]),
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds `.serialized`.
  private static func makeSerializedExpr() -> ExprSyntax {
    ExprSyntax(
      MemberAccessExprSyntax(
        declName: DeclReferenceExprSyntax(baseName: .identifier("serialized"))
      )
    )
  }

  /// Builds `.timeLimit(duration)`.
  private static func makeTimeLimitExpr(_ timeLimit: ExprSyntax) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
          MemberAccessExprSyntax(
            declName: DeclReferenceExprSyntax(baseName: .identifier("timeLimit"))
          )
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax([
          LabeledExprSyntax(expression: timeLimit)
        ]),
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds `.tags(.invariantSwiftPropertyBased, [.invariantSwiftPropertyReplay,] ...userTags)`.
  private static func makeTagsExpr(_ request: GeneratedTestAttributeRequest) -> ExprSyntax {
    var tagExprs: [ExprSyntax] = [
      ExprSyntax(
        MemberAccessExprSyntax(
          declName: DeclReferenceExprSyntax(
            baseName: .identifier("invariantSwiftPropertyBased")
          )
        )
      )
    ]

    if request.includeReplayTag {
      tagExprs.append(
        ExprSyntax(
          MemberAccessExprSyntax(
            declName: DeclReferenceExprSyntax(
              baseName: .identifier("invariantSwiftPropertyReplay")
            )
          )
        )
      )
    }

    tagExprs.append(contentsOf: request.traits.tags)

    let arguments = LabeledExprListSyntax(
      tagExprs.enumerated().map { index, expr in
        LabeledExprSyntax(
          expression: expr,
          trailingComma: index < tagExprs.count - 1 ? .commaToken() : nil
        )
      }
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
          MemberAccessExprSyntax(
            declName: DeclReferenceExprSyntax(baseName: .identifier("tags"))
          )
        ),
        leftParen: .leftParenToken(),
        arguments: arguments,
        rightParen: .rightParenToken()
      )
    )
  }
}
