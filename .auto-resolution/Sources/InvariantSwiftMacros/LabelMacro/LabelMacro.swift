import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct LabelMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let ctx = MacroContext(context: context)

    guard case .argumentList(let args) = node.arguments,
      let firstArg = args.first
    else {
      ctx.error(LabelDiagnostic.missingLabel, at: node)
      return []
    }

    guard let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let value = stringLiteral.representedLiteralValue
    else {
      ctx.error(LabelDiagnostic.requiresStringLiteral, at: firstArg.expression)
      return []
    }

    if value.isEmpty {
      ctx.warning("@Label should not be empty", at: firstArg.expression)
    }

    return []
  }
}

enum LabelDiagnostic: String, MacroDiagnostic {
  static let domain = "InvariantSwift.LabelMacro"

  case missingLabel = "label_missing"
  case requiresStringLiteral = "label_requires_string"

  var severity: DiagnosticSeverity {
    .error
  }

  var message: String {
    switch self {
    case .missingLabel:
      return "@Label requires a string argument"

    case .requiresStringLiteral:
      return "@Label requires a string literal"
    }
  }
}
