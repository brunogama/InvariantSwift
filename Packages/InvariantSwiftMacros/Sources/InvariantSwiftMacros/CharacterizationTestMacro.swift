import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private enum CharacterizationTestDiagnostic: String, DiagnosticMessage {
  case mustBeFunction
  case requiresOneInputParameter

  var message: String {
    switch self {
    case .mustBeFunction:
      return "@CharacterizationTest can only annotate a function"

    case .requiresOneInputParameter:
      return "@CharacterizationTest requires one input parameter"
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "InvariantSwiftMacros", id: rawValue)
  }

  var severity: DiagnosticSeverity { .error }
}

private enum CharacterizationTestMacroError: Error, CustomStringConvertible {
  case message(String)

  var description: String {
    switch self {
    case .message(let message):
      return message
    }
  }
}

/// Generates a Swift Testing wrapper for an explicit characterization fixture.
public struct CharacterizationTestMacro: PeerMacro {
  /// Expands an annotated single-parameter function into a generated test peer.
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(node: node, message: CharacterizationTestDiagnostic.mustBeFunction)
      )
      return []
    }

    let parameters = function.signature.parameterClause.parameters
    guard parameters.count == 1, let parameter = parameters.first else {
      context.diagnose(
        Diagnostic(
          node: function.signature.parameterClause,
          message: CharacterizationTestDiagnostic.requiresOneInputParameter
        )
      )
      return []
    }

    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let fixture = expression(named: "fixture", in: arguments),
      let inputs = expression(named: "inputs", in: arguments)
    else {
      throw CharacterizationTestMacroError.message(
        "@CharacterizationTest requires fixture and inputs"
      )
    }

    let functionName = function.name.text
    let wrapperName = uniqueWrapperName(for: function, in: context)
    let inputName = parameter.secondName?.text ?? parameter.firstName.text
    let argument =
      parameter.firstName.text == "_"
      ? inputName
      : "\(parameter.firstName.text): \(inputName)"
    let effects = function.signature.effectSpecifiers
    let callPrefix = [
      effects?.asyncSpecifier != nil ? "await " : "",
      effects?.throwsClause != nil ? "try " : "",
    ].joined()

    let generated = """
      private enum \(wrapperName) {
        @Test("\(functionName) characterization")
        static func run() async throws {
          _ = try await InvariantSwiftTesting.CharacterizationTestRuntime.run(
            name: "\(functionName)",
            fixture: \(fixture),
            inputs: \(inputs),
            operation: { input in \(callPrefix)\(functionName)(\(argument)) }
          )
        }
      }
      """
    return [DeclSyntax(stringLiteral: generated)]
  }

  private static func uniqueWrapperName(
    for function: FunctionDeclSyntax,
    in context: some MacroExpansionContext
  ) -> String {
    let signature = function.signature.tokens(viewMode: .sourceAccurate)
      .map(\.text)
      .joined()
    var discriminator: UInt64 = 14_695_981_039_346_656_037
    for byte in signature.utf8 {
      discriminator ^= UInt64(byte)
      discriminator &*= 1_099_511_628_211
    }
    return context.makeUniqueName(
      "\(function.name.text)_\(String(discriminator, radix: 16))_CharacterizationTest"
    ).text
  }

  private static func expression(
    named name: String,
    in arguments: LabeledExprListSyntax
  ) -> String? {
    arguments.first { $0.label?.text == name }?.expression.description
  }
}
