import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct StateMachineMacro: MemberMacro, ExtensionMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: StateMachineDiagnostic.mustBeStruct
        )
      )
      return []
    }

    let typeName = structDecl.name.text
    let analysis = StateMachineAnalyzer.analyze(structDecl)

    guard !analysis.commandMethods.isEmpty else {
      context.diagnose(
        Diagnostic(
          node: structDecl.name,
          message: StateMachineDiagnostic.noCommandMethods
        )
      )
      return []
    }

    return StateMachineCodeGen.generateMembers(
      typeName: typeName,
      analysis: analysis
    )
  }

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {

    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      return []
    }

    let analysis = StateMachineAnalyzer.analyze(structDecl)

    guard !analysis.commandMethods.isEmpty else {
      return []
    }

    let typeName = structDecl.name.text

    return StateMachineCodeGen.generateExtensions(
      typeName: typeName,
      type: type,
      analysis: analysis
    )
  }
}

public struct CommandMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
  }
}

enum StateMachineDiagnostic: String, DiagnosticMessage {
  case mustBeStruct = "@StateMachine can only be applied to structs"
  case noCommandMethods = "@StateMachine requires at least one @Command method"

  var message: String { rawValue }
  var diagnosticID: MessageID {
    MessageID(domain: "InvariantSwiftMacros", id: rawValue)
  }
  var severity: DiagnosticSeverity { .error }
}
