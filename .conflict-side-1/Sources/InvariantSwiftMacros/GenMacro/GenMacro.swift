import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct GenMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
  }
}

public enum GenAttributeExtractor {

  public static func extractGenerator(from param: ExtractedParameter) -> ExprSyntax? {
    guard let genAttr = ParameterExtractor.extractGenAttribute(param) else {
      return nil
    }

    guard let parsed = GeneratorDSL.parse(from: genAttr) else {
      return nil
    }

    return GeneratorDSL.generateCode(for: parsed)
  }

  public static func resolveGenerator(for param: ExtractedParameter) -> ExprSyntax {
    if let explicitGen = extractGenerator(from: param) {
      return explicitGen
    }

    return GeneratorBuilder.infer(for: param.type)
  }
}

public enum GenMacroDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.GenMacro"

  case invalidGeneratorExpression = "gen_invalid_expression"
  case unsupportedGeneratorType = "gen_unsupported_type"

  public var severity: DiagnosticSeverity { .error }

  public var message: String {
    switch self {
    case .invalidGeneratorExpression:
      return
        // swiftlint:disable:next line_length
        "@Gen requires a valid generator expression. Use patterns like .int, .string(length: 1...10), etc."

    case .unsupportedGeneratorType:
      return "Unsupported generator type in @Gen expression"
    }
  }
}
