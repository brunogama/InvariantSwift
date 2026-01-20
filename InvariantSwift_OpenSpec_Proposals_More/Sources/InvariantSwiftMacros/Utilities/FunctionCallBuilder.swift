import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Function Call Builder

/// Builder for constructing function call expressions.
/// Fluent API for type-safe function call construction.
public struct FunctionCallBuilder {
  private let callee: ExprSyntax
  private var arguments: [LabeledExprSyntax] = []
  private var trailingClosure: ClosureExprSyntax?

  /// Initialize with a simple function name
  public init(_ name: String) {
    self.callee = ExprSyntax(SyntaxFactory.declRef(name))
  }

  /// Initialize with a member access: `Type.method`
  public init(type: String, member: String) {
    self.callee = ExprSyntax(SyntaxFactory.memberAccess(type: type, member: member))
  }

  /// Initialize with an arbitrary callee expression
  public init(callee: ExprSyntax) {
    self.callee = callee
  }

  /// Add an unlabeled argument
  public func arg(_ expr: ExprSyntax) -> Self {
    var copy = self
    copy.arguments.append(
      LabeledExprSyntax(expression: expr)
    )
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

  /// Add an integer argument
  public func arg(_ label: String, int value: Int) -> Self {
    arg(label, ExprSyntax(SyntaxFactory.intLiteral(value)))
  }

  /// Add a string argument
  public func arg(_ label: String, string value: String) -> Self {
    arg(label, ExprSyntax(SyntaxFactory.stringLiteral(value)))
  }

  /// Add a boolean argument
  public func arg(_ label: String, bool value: Bool) -> Self {
    arg(label, ExprSyntax(SyntaxFactory.boolLiteral(value)))
  }

  /// Add an identifier reference argument
  public func arg(_ label: String, ref name: String) -> Self {
    arg(label, ExprSyntax(SyntaxFactory.declRef(name)))
  }

  /// Add unlabeled identifier reference
  public func arg(ref name: String) -> Self {
    arg(ExprSyntax(SyntaxFactory.declRef(name)))
  }

  /// Add a trailing closure
  public func trailing(_ closure: ClosureExprSyntax) -> Self {
    var copy = self
    copy.trailingClosure = closure
    return copy
  }

  /// Build the function call expression
  public func build() -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: callee,
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(arguments),
      rightParen: .rightParenToken(),
      trailingClosure: trailingClosure
    )
  }

  /// Build as ExprSyntax
  public func buildExpr() -> ExprSyntax {
    ExprSyntax(build())
  }
}

// MARK: - Convenience Extensions

extension FunctionCallBuilder {
  /// Creates Gen.zip(...) call
  public static func genZip(_ generators: [ExprSyntax]) -> FunctionCallBuilder {
    var builder = FunctionCallBuilder(type: "Gen", member: "zip")
    for gen in generators {
      builder = builder.arg(gen)
    }
    return builder
  }

  /// Creates Gen.pure(value)
  public static func genPure(_ value: ExprSyntax) -> FunctionCallBuilder {
    FunctionCallBuilder(type: "Gen", member: "pure")
      .arg(value)
  }

  /// Creates Type.init(...)
  public static func initCall(
    type: String,
    arguments: [(label: String, value: ExprSyntax)]
  ) -> FunctionCallBuilder {
    var builder = FunctionCallBuilder(type)
    for (label, value) in arguments {
      builder = builder.arg(label, value)
    }
    return builder
  }
}
