import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Attribute Builder

/// Builder for constructing attribute syntax nodes.
public struct AttributeBuilder {
  private let name: String
  private var arguments: [LabeledExprSyntax] = []

  public init(_ name: String) {
    self.name = name
  }

  /// Add an unlabeled argument
  public func arg(_ expr: ExprSyntax) -> Self {
    var copy = self
    copy.arguments.append(LabeledExprSyntax(expression: expr))
    return copy
  }

  /// Add a labeled argument
  public func arg(_ label: String, _ expr: ExprSyntax) -> Self {
    var copy = self
    copy.arguments.append(
      LabeledExprSyntax(
        label: .identifier(label),
        colon: .colonToken(),
        expression: expr
      )
    )
    return copy
  }

  /// Add integer argument
  public func arg(_ label: String, int value: Int) -> Self {
    arg(label, ExprSyntax(SyntaxFactory.intLiteral(value)))
  }

  /// Build the attribute
  public func build() -> AttributeSyntax {
    if arguments.isEmpty {
      return AttributeSyntax(
        attributeName: SyntaxFactory.simpleType(name)
      )
    }

    return AttributeSyntax(
      attributeName: SyntaxFactory.simpleType(name),
      leftParen: .leftParenToken(),
      arguments: .argumentList(LabeledExprListSyntax(arguments)),
      rightParen: .rightParenToken()
    )
  }
}

// MARK: - Common Attributes

extension AttributeBuilder {
  /// Creates @Test attribute
  public static var test: AttributeSyntax {
    AttributeBuilder("Test").build()
  }

  /// Creates @Test(arguments: expr)
  public static func testWithArguments(_ expr: ExprSyntax) -> AttributeSyntax {
    AttributeBuilder("Test")
      .arg("arguments", expr)
      .build()
  }

  /// Creates @available(macOS 10.15, iOS 13.0, *)
  /// Note: SwiftSyntax availability attribute API is complex and version-dependent.
  /// This simplified version returns a basic available attribute.
  public static var availableAsync: AttributeSyntax {
    // For simplicity, return a basic @available(*) which is compatible across SwiftSyntax versions
    AttributeSyntax(
      attributeName: SyntaxFactory.simpleType("available"),
      leftParen: .leftParenToken(),
      arguments: .availability(
        AvailabilityArgumentListSyntax {
          AvailabilityArgumentSyntax(argument: .token(.binaryOperator("*")))
        }
      ),
      rightParen: .rightParenToken()
    )
  }
}
