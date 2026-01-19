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

// MARK: - Contextual Diagnostics

/// A diagnostic message wrapper that adds context (field name, type, etc.) to base diagnostics.
///
/// Usage:
/// ```swift
/// ctx.error(
///   ContextualDiagnostic(
///     base: ArbitraryMacroDiagnostic.cannotInferFieldGenerator,
///     context: "field 'timestamp' of type 'CustomDate'"
///   ),
///   at: node
/// )
/// ```
public struct ContextualDiagnostic<Base: MacroDiagnostic>: DiagnosticMessage {
  public let base: Base
  public let context: String

  public init(base: Base, context: String) {
    self.base = base
    self.context = context
  }

  public var message: String {
    "\(base.message) (\(context))"
  }

  public var diagnosticID: MessageID {
    base.diagnosticID
  }

  public var severity: DiagnosticSeverity {
    base.severity
  }
}

/// Convenience extension for creating contextual diagnostics with field info.
extension MacroDiagnostic {
  /// Creates a contextual diagnostic with field name.
  public func withField(_ fieldName: String) -> ContextualDiagnostic<Self> {
    ContextualDiagnostic(base: self, context: "field '\(fieldName)'")
  }

  /// Creates a contextual diagnostic with field name and type.
  public func withField(_ fieldName: String, type: String) -> ContextualDiagnostic<Self> {
    ContextualDiagnostic(base: self, context: "field '\(fieldName)' of type '\(type)'")
  }

  /// Creates a contextual diagnostic with parameter name.
  public func withParameter(_ paramName: String) -> ContextualDiagnostic<Self> {
    ContextualDiagnostic(base: self, context: "parameter '\(paramName)'")
  }

  /// Creates a contextual diagnostic with parameter name and type.
  public func withParameter(_ paramName: String, type: String) -> ContextualDiagnostic<Self> {
    ContextualDiagnostic(base: self, context: "parameter '\(paramName)' of type '\(type)'")
  }

  /// Creates a contextual diagnostic with type name.
  public func withType(_ typeName: String) -> ContextualDiagnostic<Self> {
    ContextualDiagnostic(base: self, context: "type '\(typeName)'")
  }
}
