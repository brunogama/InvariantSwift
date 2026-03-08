import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct ArbitraryMacro: MemberMacro, ExtensionMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    let ctx = MacroContext(context: context)
    let config = ArbitraryConfigExtractor.extract(from: node)

    if let structDecl = declaration.as(StructDeclSyntax.self) {
      return try generateStructMembers(
        structDecl: structDecl,
        config: config,
        context: ctx
      )
    }

    if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      return try generateEnumMembers(
        enumDecl: enumDecl,
        config: config,
        context: ctx
      )
    }

    ctx.error(ArbitraryMacroDiagnostic.mustBeStructOrEnum, at: node)
    return []
  }

  // swiftlint:disable:next function_parameter_count
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {

    let extensionDecl = MacroTemplateAdapter.makeExtension(
      typeName: type.trimmedDescription,
      conformances: ["Generatable"]
    )

    return [extensionDecl]
  }

  private static func generateStructMembers(
    structDecl: StructDeclSyntax,
    config: ArbitraryConfig,
    context: MacroContext
  ) throws -> [DeclSyntax] {

    let typeName = structDecl.name.text
    let fields = StructAnalyzer.extractFields(from: structDecl)

    guard !fields.isEmpty else {
      context.error(ArbitraryMacroDiagnostic.noStoredProperties, at: structDecl.name)
      return []
    }

    // Check for init parameter mismatch
    let initParams = StructAnalyzer.extractInitParameters(from: structDecl)
    let mismatches = StructAnalyzer.findInitMismatches(fields: fields, initParams: initParams)
    if !mismatches.isEmpty {
      context.error(ArbitraryMacroDiagnostic.initParameterMismatch, at: structDecl.name)
      return []
    }

    for constraintField in config.constraints.keys {
      // swiftlint:disable:next for_where
      if !fields.contains(where: { $0.name == constraintField }) {
        context.warning(
          "Constraint for unknown field '\(constraintField)'",
          at: structDecl.name
        )
      }
    }

    let arbitraryProperty = ArbitraryCodeGen.buildStructArbitraryProperty(
      typeName: typeName,
      fields: fields,
      config: config
    )

    var members: [DeclSyntax] = [DeclSyntax(arbitraryProperty)]

    if config.shrinkStrategy != .none {
      let shrinkProperty = ArbitraryCodeGen.buildStructShrinkProperty(
        typeName: typeName,
        fields: fields,
        config: config
      )
      members.append(DeclSyntax(shrinkProperty))
    }

    return members
  }

  private static func generateEnumMembers(
    enumDecl: EnumDeclSyntax,
    config: ArbitraryConfig,
    context: MacroContext
  ) throws -> [DeclSyntax] {

    let typeName = enumDecl.name.text
    let cases = EnumAnalyzer.extractCases(from: enumDecl)

    guard !cases.isEmpty else {
      context.error(ArbitraryMacroDiagnostic.noEnumCases, at: enumDecl.name)
      return []
    }

    let arbitraryProperty = ArbitraryCodeGen.buildEnumArbitraryProperty(
      typeName: typeName,
      cases: cases,
      config: config
    )

    return [DeclSyntax(arbitraryProperty)]
  }
}

struct ArbitraryConfig {
  let shrinkStrategy: ShrinkStrategy
  let constraints: [String: String]

  static let `default` = Self(
    shrinkStrategy: .automatic,
    constraints: [:]
  )
}

enum ShrinkStrategy: Equatable {
  case automatic
  case towards(ExprSyntax)
  case none
  case toEmpty
  case dropFields
  case custom(ExprSyntax)

  static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.automatic, .automatic): return true
    case (.none, .none): return true
    case (.towards, .towards): return true
    case (.toEmpty, .toEmpty): return true
    case (.dropFields, .dropFields): return true
    case (.custom, .custom): return true
    default: return false
    }
  }
}

enum ArbitraryConfigExtractor {

  static func extract(from node: AttributeSyntax) -> ArbitraryConfig {
    var shrinkStrategy: ShrinkStrategy = .automatic
    var constraints: [String: String] = [:]

    guard case .argumentList(let args) = node.arguments else {
      return .default
    }

    for arg in args {
      switch arg.label?.text {
      case "shrink":
        shrinkStrategy = parseShrinkStrategy(arg.expression)

      case "constraints":
        constraints = parseConstraints(arg.expression)

      default:
        break
      }
    }

    return ArbitraryConfig(shrinkStrategy: shrinkStrategy, constraints: constraints)
  }

  private static func parseShrinkStrategy(_ expr: ExprSyntax) -> ShrinkStrategy {
    if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
      switch memberAccess.declName.baseName.text {
      case "automatic": return .automatic
      case "none": return .none
      case "toEmpty": return .toEmpty
      case "dropFields": return .dropFields
      default: break
      }
    }

    if let funcCall = expr.as(FunctionCallExprSyntax.self),
      let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self),
      let firstArg = funcCall.arguments.first
    {
      switch memberAccess.declName.baseName.text {
      case "towards":
        return .towards(firstArg.expression)

      case "custom":
        return .custom(firstArg.expression)

      default:
        break
      }
    }

    return .automatic
  }

  private static func parseConstraints(_ expr: ExprSyntax) -> [String: String] {
    guard let dictExpr = expr.as(DictionaryExprSyntax.self),
      case .elements(let elements) = dictExpr.content
    else {
      return [:]
    }

    var result: [String: String] = [:]
    for element in elements {
      if let keyExpr = element.key.as(StringLiteralExprSyntax.self),
        let valueExpr = element.value.as(StringLiteralExprSyntax.self),
        let key = keyExpr.representedLiteralValue,
        let value = valueExpr.representedLiteralValue
      {
        result[key] = value
      }
    }
    return result
  }
}
