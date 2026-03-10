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
    var expressions: [ExprSyntax] = [
      ExprSyntax(
        stringLiteral:
          "InvariantSwiftPropertyExecutionTrait(testName: \"\(escape(request.displayName))\", labels: \(arrayLiteral(request.labels)), configuredSeed: \(configuredSeedLiteral(request.configuredSeed)))"
      )
    ]

    if let enabledCondition = request.traits.enabledCondition {
      expressions.append(ExprSyntax(stringLiteral: ".enabled(if: \(enabledCondition.description))"))
    } else if let disabledReason = request.traits.disabledReason {
      expressions.append(
        ExprSyntax(
          stringLiteral:
            ".disabled(Comment(rawValue: \(disabledReason.description)))"
        )
      )
    }

    if request.traits.serialized {
      expressions.append(ExprSyntax(stringLiteral: ".serialized"))
    }

    if let timeLimit = request.traits.timeLimit {
      expressions.append(ExprSyntax(stringLiteral: ".timeLimit(\(timeLimit.description))"))
    }

    var tagDescriptions = [".invariantSwiftPropertyBased"]
    if request.includeReplayTag {
      tagDescriptions.append(".invariantSwiftPropertyReplay")
    }
    tagDescriptions.append(contentsOf: request.traits.tags.map(\.description))
    expressions.append(
      ExprSyntax(stringLiteral: ".tags(\(tagDescriptions.joined(separator: ", ")))")
    )

    expressions.append(
      contentsOf: request.traits.bugs.map { ExprSyntax(stringLiteral: $0.description) }
    )

    return expressions
  }

  private static func arrayLiteral(_ values: [String]) -> String {
    let contents = values.map { "\"\(escape($0))\"" }.joined(separator: ", ")
    return "[\(contents)]"
  }

  private static func configuredSeedLiteral(_ seed: UInt64?) -> String {
    seed.map { String($0) } ?? "nil"
  }

  private static func escape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }
}
