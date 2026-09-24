import SwiftSyntax
import SwiftSyntaxBuilder

public enum MacroExpansionEscapeHatches {
  public static func declaration(_ source: String) -> DeclSyntax {
    DeclSyntax(stringLiteral: source)
  }

  public static func expression(_ source: String) -> ExprSyntax {
    ExprSyntax(stringLiteral: source)
  }

  /// Parses `source` as a sequence of statements.
  ///
  /// `expression(_:)` parses as a single expression, so a multi-statement body handed
  /// to it does not round-trip: the parser takes the first statement and files the rest
  /// as unexpected tokens, and the node it returns carries no leading trivia. Placed
  /// after a closure's `in`, that rendered as `{ (value: Int) invar current = ... }`,
  /// which is not valid Swift.
  public static func statements(_ source: String) -> CodeBlockItemListSyntax {
    CodeBlockItemListSyntax(stringLiteral: source)
  }
}
