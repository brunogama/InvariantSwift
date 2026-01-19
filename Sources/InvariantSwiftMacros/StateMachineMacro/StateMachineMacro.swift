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

    let ctx = MacroContext(context: context)

    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      ctx.error(StateMachineDiagnostic.mustBeStruct, at: node)
      return []
    }

    let typeName = structDecl.name.text
    let analysis = StateMachineAnalyzer.analyze(structDecl)

    guard !analysis.commandMethods.isEmpty else {
      ctx.error(StateMachineDiagnostic.noCommandMethods, at: structDecl.name)
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

public enum StateMachineDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.StateMachineMacro"

  case mustBeStruct = "must_be_struct"
  case noCommandMethods = "no_command_methods"
  case invalidCommandSignature = "invalid_command_signature"
  case missingStateProperty = "missing_state_property"
  case duplicateCommandNames = "duplicate_command_names"

  public var severity: DiagnosticSeverity { .error }

  public var message: String {
    switch self {
    case .mustBeStruct:
      return "@StateMachine can only be applied to structs"

    case .noCommandMethods:
      return "@StateMachine requires at least one @Command method"

    case .invalidCommandSignature:
      return "@Command must be applied to a mutating method"

    case .missingStateProperty:
      return "@StateMachine requires a state property"

    case .duplicateCommandNames:
      return "@StateMachine has duplicate command names"
    }
  }
}
