import SwiftDiagnostics
import SwiftSyntax

// MARK: - Supporting Types

struct RuleBasedTestConfiguration {
  let maxSteps: Int
  let maxExamples: Int
}

struct RuleInfo {
  let name: String
  let weight: Int
  let preconditionExpr: ExprSyntax?
  let isMutating: Bool
}

struct InvariantInfo {
  let name: String
}

struct BundleInfo {
  let name: String
}

// MARK: - Diagnostics

public enum RuleBasedTestMacroDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.RuleBasedTestMacro"

  case mustBeStruct = "must_be_struct"
  case noRules = "no_rules"
  case invalidRuleSignature = "invalid_rule_signature"
  case invalidInvariantReturn = "invalid_invariant_return"

  public var severity: DiagnosticSeverity { .error }

  public var message: String {
    switch self {
    case .mustBeStruct:
      return "@RuleBasedTest can only be applied to structs"

    case .noRules:
      return "@RuleBasedTest requires at least one @Rule method"

    case .invalidRuleSignature:
      return "@Rule must be applied to a mutating method with no parameters"

    case .invalidInvariantReturn:
      return "@Invariant must be applied to a method returning Bool"
    }
  }
}

enum RuleBasedTestMacroError: Error, CustomStringConvertible {
  case notAStruct
  case invalidConfiguration

  var description: String {
    switch self {
    case .notAStruct:
      return "@RuleBasedTest can only be applied to structs"

    case .invalidConfiguration:
      return "@RuleBasedTest has invalid configuration"
    }
  }
}
