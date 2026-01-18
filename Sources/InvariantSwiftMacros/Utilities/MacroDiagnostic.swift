import SwiftDiagnostics
import SwiftSyntax

/// A protocol for macro-specific diagnostic messages that reduces boilerplate.
///
/// Conforming types only need to provide the domain and a switch over cases
/// for the message. The diagnosticID is computed automatically from the domain
/// and rawValue.
///
/// Usage:
/// ```swift
/// enum MyMacroDiagnostic: String, MacroDiagnostic {
///     static let domain = "InvariantSwift.MyMacro"
///
///     case invalidInput = "invalid_input"
///     case missingRequired = "missing_required"
///
///     var message: String {
///         switch self {
///         case .invalidInput: return "Invalid input provided"
///         case .missingRequired: return "Missing required parameter"
///         }
///     }
///
///     var severity: DiagnosticSeverity { .error }
/// }
/// ```
public protocol MacroDiagnostic: DiagnosticMessage, RawRepresentable where RawValue == String {
  /// The domain prefix for all diagnostics of this type.
  /// Example: "InvariantSwift.PropertyMacro"
  static var domain: String { get }
}

extension MacroDiagnostic {
  /// Automatically generates the MessageID from domain and rawValue.
  public var diagnosticID: MessageID {
    MessageID(domain: Self.domain, id: rawValue)
  }
}

extension MacroDiagnostic {
  public var defaultSeverity: DiagnosticSeverity { .error }
}
