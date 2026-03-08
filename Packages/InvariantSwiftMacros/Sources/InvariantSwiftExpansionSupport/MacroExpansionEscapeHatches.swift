import SwiftSyntax

public enum MacroExpansionEscapeHatches {
  public static func declaration(_ source: String) -> DeclSyntax {
    DeclSyntax(stringLiteral: source)
  }

  public static func expression(_ source: String) -> ExprSyntax {
    ExprSyntax(stringLiteral: source)
  }
}
