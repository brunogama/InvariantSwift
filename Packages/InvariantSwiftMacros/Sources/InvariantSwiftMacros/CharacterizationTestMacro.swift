import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private enum CharacterizationTestDiagnostic: String, DiagnosticMessage {
  case mustBeFunction
  case mustBeFileScope
  case requiresOneInputParameter
  var message: String {
    switch self {
    case .mustBeFunction:
      return "@CharacterizationTest can only annotate a function"

    case .mustBeFileScope:
      return "@CharacterizationTest can only annotate a file-scope function"

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
    guard let function = validFunction(declaration, node: node, in: context),
      let parameter = validParameter(of: function, in: context)
    else {
      return []
    }

    let plan = try ExpansionPlan(
      function: function,
      parameter: parameter,
      node: node,
      context: context
    )
    return [DeclSyntax(stringLiteral: plan.generatedSource)]
  }

  private static func validFunction(
    _ declaration: some DeclSyntaxProtocol,
    node: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> FunctionDeclSyntax? {
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: CharacterizationTestDiagnostic.mustBeFunction
        )
      )
      return nil
    }
    guard context.lexicalContext.isEmpty else {
      context.diagnose(
        Diagnostic(node: node, message: CharacterizationTestDiagnostic.mustBeFileScope)
      )
      return nil
    }
    return function
  }

  private static func validParameter(
    of function: FunctionDeclSyntax,
    in context: some MacroExpansionContext
  ) -> FunctionParameterSyntax? {
    let parameters = function.signature.parameterClause.parameters
    guard parameters.count == 1, let parameter = parameters.first else {
      context.diagnose(
        Diagnostic(
          node: function.signature.parameterClause,
          message: CharacterizationTestDiagnostic.requiresOneInputParameter
        )
      )
      return nil
    }
    return parameter
  }
}

/// The resolved pieces required to render one generated test peer.
private struct ExpansionPlan {
  let functionName: String
  let wrapperName: String
  let fixture: String
  let inputs: String
  let sourceFile: String
  let callPrefix: String
  let argument: String

  init(
    function: FunctionDeclSyntax,
    parameter: FunctionParameterSyntax,
    node: AttributeSyntax,
    context: some MacroExpansionContext
  ) throws {
    let arguments = try Self.labeledArguments(of: node)
    fixture = try Self.requiredExpression(named: "fixture", in: arguments)
    inputs = try Self.requiredExpression(named: "inputs", in: arguments)
    functionName = function.name.text
    wrapperName = Self.uniqueWrapperName(for: function, in: context)
    sourceFile = Self.sourceFileExpression(of: node, in: context)
    callPrefix = Self.callPrefix(for: function)
    argument = Self.callArgument(for: parameter)
  }

  var generatedSource: String {
    """
    private enum \(wrapperName) {
      @Test("\(functionName) characterization")
      static func run() async throws {
        _ = try await InvariantSwiftTesting.CharacterizationTestRuntime.run(
          name: "\(functionName)",
          fixture: \(fixture),
          inputs: \(inputs),
          operation: { input in \(callPrefix)\(functionName)(\(argument)) },
          sourceFile: \(sourceFile)
        )
      }
    }
    """
  }

  private static func labeledArguments(
    of node: AttributeSyntax
  ) throws -> LabeledExprListSyntax {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      throw CharacterizationTestMacroError.message(
        "@CharacterizationTest requires fixture and inputs"
      )
    }
    return arguments
  }

  private static func requiredExpression(
    named name: String,
    in arguments: LabeledExprListSyntax
  ) throws -> String {
    guard
      let argument = arguments.first(where: { $0.label?.text == name })
    else {
      throw CharacterizationTestMacroError.message(
        "@CharacterizationTest requires fixture and inputs"
      )
    }
    return argument.expression.description
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

  private static func sourceFileExpression(
    of node: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> String {
    let location = context.location(
      of: node,
      at: .afterLeadingTrivia,
      filePathMode: .filePath
    )
    return location?.file.description ?? "#filePath"
  }

  private static func callPrefix(for function: FunctionDeclSyntax) -> String {
    let effects = function.signature.effectSpecifiers
    return [
      effects?.throwsClause != nil ? "try " : "",
      effects?.asyncSpecifier != nil ? "await " : "",
    ].joined()
  }

  private static func callArgument(
    for parameter: FunctionParameterSyntax
  ) -> String {
    parameter.firstName.text == "_"
      ? "input"
      : "\(parameter.firstName.text): input"
  }
}
