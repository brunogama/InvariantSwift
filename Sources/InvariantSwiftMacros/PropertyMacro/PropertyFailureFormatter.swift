import SwiftSyntax
import SwiftSyntaxBuilder

/// Generates human-readable failure messages for property test failures.
public enum PropertyFailureFormatter {

  /// Generates the complete failure message expression for a property test failure.
  ///
  /// - Parameters:
  ///   - labels: Parameter names or labels for the failing values
  ///   - includeSeed: Whether to include seed information in the output
  /// - Returns: An expression that builds the failure message string
  public static func buildFailureMessage(
    labels: [String],
    includeSeed: Bool
  ) -> ExprSyntax {
    let components = buildMessageComponents(labels: labels, includeSeed: includeSeed)
    return buildStringInterpolation(components)
  }

  private static func buildMessageComponents(
    labels: [String],
    includeSeed: Bool
  ) -> [MessageComponent] {
    var components: [MessageComponent] = []

    components.append(.literal("Property failed after "))
    components.append(.variable("iterations"))
    components.append(.literal(" iterations\n\n"))

    components.append(.literal("Original failing input:\n"))
    for label in labels {
      components.append(.literal("  \(label): "))
      components.append(.counterexampleValue(label))
      components.append(.literal("\n"))
    }

    components.append(.literal("\nShrunk to minimal case:\n"))
    for label in labels {
      components.append(.literal("  \(label): "))
      components.append(.shrunkValue(label))
      components.append(.literal("\n"))
    }

    if includeSeed {
      components.append(.literal("\nSeed: "))
      components.append(.seedValue)
    }

    components.append(.literal("\n\nTip: Re-run with this seed to reproduce the failure."))

    return components
  }

  private enum MessageComponent {
    case literal(String)
    case variable(String)
    case counterexampleValue(String)
    case shrunkValue(String)
    case seedValue
  }

  private static func buildStringInterpolation(_ components: [MessageComponent]) -> ExprSyntax {
    var segments: [StringLiteralSegmentListSyntax.Element] = []

    for component in components {
      switch component {
      case .literal(let text):
        segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment(text))))

      case .variable(let name):
        let expr = DeclReferenceExprSyntax(baseName: .identifier(name))
        segments.append(
          .expressionSegment(
            ExpressionSegmentSyntax(
              expressions: [LabeledExprSyntax(expression: ExprSyntax(expr))]
            )
          )
        )

      case .counterexampleValue:
        let expr = DeclReferenceExprSyntax(baseName: .identifier("counterexample"))
        segments.append(
          .expressionSegment(
            ExpressionSegmentSyntax(
              expressions: [LabeledExprSyntax(expression: ExprSyntax(expr))]
            )
          )
        )

      case .shrunkValue:
        let expr = DeclReferenceExprSyntax(baseName: .identifier("shrunk"))
        segments.append(
          .expressionSegment(
            ExpressionSegmentSyntax(
              expressions: [LabeledExprSyntax(expression: ExprSyntax(expr))]
            )
          )
        )

      case .seedValue:
        let seedAccess = buildSeedAccessExpression()
        segments.append(
          .expressionSegment(
            ExpressionSegmentSyntax(
              expressions: [LabeledExprSyntax(expression: seedAccess)]
            )
          )
        )
      }
    }

    return ExprSyntax(
      StringLiteralExprSyntax(
        openingQuote: .stringQuoteToken(),
        segments: StringLiteralSegmentListSyntax(segments),
        closingQuote: .stringQuoteToken()
      )
    )
  }

  private static func buildSeedAccessExpression() -> ExprSyntax {
    let configSeed = OptionalChainingExprSyntax(
      expression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("config")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("seed"))
      )
    )

    let seedValue = MemberAccessExprSyntax(
      base: ExprSyntax(configSeed),
      declName: DeclReferenceExprSyntax(baseName: .identifier("value"))
    )

    let nilCoalescing = InfixOperatorExprSyntax(
      leftOperand: ExprSyntax(seedValue),
      operator: BinaryOperatorExprSyntax(operator: .binaryOperator("??")),
      rightOperand: StringLiteralExprSyntax(content: "random")
    )

    return ExprSyntax(nilCoalescing)
  }

  /// Builds the Issue.record call with formatted failure message.
  ///
  /// - Parameters:
  ///   - labels: Parameter names or labels for the failing values
  ///   - includeSeed: Whether to include seed information in the output
  /// - Returns: Expression syntax for `Issue.record(Comment(...))`
  public static func buildFormattedIssueRecord(
    labels: [String],
    includeSeed: Bool
  ) -> ExprSyntax {
    let messageExpr = buildFailureMessage(labels: labels, includeSeed: includeSeed)

    let comment = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Comment")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("rawValue"),
          colon: .colonToken(),
          expression: messageExpr
        )
      },
      rightParen: .rightParenToken()
    )

    let issueRecord = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("Issue")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("record"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(expression: ExprSyntax(comment))
      },
      rightParen: .rightParenToken()
    )

    return ExprSyntax(issueRecord)
  }

  /// Extracts labels from parameters, using @Label value or parameter name as fallback.
  ///
  /// - Parameter parameters: The extracted parameters from the function
  /// - Returns: Array of labels for each parameter
  public static func extractLabels(from parameters: [ExtractedParameter]) -> [String] {
    parameters.map { param in
      if let labelAttr = ParameterExtractor.findAttribute(named: "Label", in: param),
        case .argumentList(let args) = labelAttr.arguments,
        let firstArg = args.first,
        let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
        let labelValue = stringLiteral.representedLiteralValue,
        !labelValue.isEmpty
      {
        return labelValue
      }
      return param.name
    }
  }
}
