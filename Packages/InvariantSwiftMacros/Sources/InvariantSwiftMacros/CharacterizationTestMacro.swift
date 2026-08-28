import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      throw CharacterizationTestMacroError.message(
        "@CharacterizationTest can only annotate a function"
      )
    }

    let parameters = function.signature.parameterClause.parameters
    guard parameters.count == 1, let parameter = parameters.first else {
      throw CharacterizationTestMacroError.message(
        "@CharacterizationTest requires one input parameter"
      )
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
    let wrapperName = "\(functionName)_CharacterizationTest"
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
          _ = try await characterize(
            CharacterizationConfiguration(
              name: "\(functionName)",
              fixture: \(fixture),
              inputs: \(inputs)
            ),
            operation: { input in \(callPrefix)\(functionName)(\(argument)) }
          )
        }
      }
      """
    return [DeclSyntax(stringLiteral: generated)]
  }

  private static func expression(
    named name: String,
    in arguments: LabeledExprListSyntax
  ) -> String? {
    arguments.first { $0.label?.text == name }?.expression.description
  }
}
