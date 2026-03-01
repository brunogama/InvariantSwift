import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@RuleBasedTest` macro for declarative stateful testing.
///
/// Transforms a struct with `@Rule`, `@Bundle`, and `@Invariant` annotations
/// into a runnable state machine test.
public struct RuleBasedTestMacro: MemberMacro, ExtensionMacro {

  // MARK: - MemberMacro

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    let ctx = MacroContext(context: context)

    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      ctx.error(RuleBasedTestMacroDiagnostic.mustBeStruct, at: node)
      return []
    }

    let typeName = structDecl.name.text
    let config = extractConfiguration(from: node)

    let rules = collectRules(from: structDecl)
    let invariants = collectInvariants(from: structDecl)
    let bundles = collectBundles(from: structDecl)

    let rulesDecl = try generateRulesProperty(rules: rules, typeName: typeName)
    let invariantsDecl = try generateInvariantsProperty(
      invariants: invariants,
      typeName: typeName
    )
    let bundlesDecl = try generateBundlesProperty(bundles: bundles, typeName: typeName)
    let runDecl = try generateRunMethod(config: config)

    return [rulesDecl, invariantsDecl, bundlesDecl, runDecl]
  }

  // MARK: - ExtensionMacro

  // swiftlint:disable:next function_parameter_count
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let inheritanceClause = InheritanceClauseSyntax {
      InheritedTypeSyntax(
        type: IdentifierTypeSyntax(name: .identifier("RuleBasedStateMachine"))
      )
    }

    let ext = ExtensionDeclSyntax(
      extendedType: type,
      inheritanceClause: inheritanceClause,
      memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
    )
    return [ext]
  }

  // MARK: - Configuration

  static func extractConfiguration(from node: AttributeSyntax) -> RuleBasedTestConfiguration {
    var maxSteps = 100
    var maxExamples = 100

    if let args = node.arguments?.as(LabeledExprListSyntax.self) {
      for arg in args {
        if arg.label?.text == "maxSteps",
          let literal = arg.expression.as(IntegerLiteralExprSyntax.self)
        {
          maxSteps = Int(literal.literal.text) ?? 100
        }
        if arg.label?.text == "maxExamples",
          let literal = arg.expression.as(IntegerLiteralExprSyntax.self)
        {
          maxExamples = Int(literal.literal.text) ?? 100
        }
      }
    }

    return RuleBasedTestConfiguration(maxSteps: maxSteps, maxExamples: maxExamples)
  }
}
