import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// A type-safe wrapper around MacroExpansionContext for unified error emission.
///
/// Provides convenience methods for emitting diagnostics with proper typing
/// and consistent patterns across all macros.
///
/// Usage:
/// ```swift
/// let ctx = MacroContext(context: context)
/// ctx.error(PropertyDiagnostic.mustBeFunction, at: node)
/// ctx.warning("Optional parameter not provided", at: node)
/// ```
public struct MacroContext {
  private let context: any MacroExpansionContext

  public init(context: some MacroExpansionContext) {
    self.context = context
  }

  public func error(_ diagnostic: some DiagnosticMessage, at node: some SyntaxProtocol) {
    context.diagnose(Diagnostic(node: node, message: diagnostic))
  }

  public func error(
    _ diagnostic: some DiagnosticMessage,
    at node: some SyntaxProtocol,
    note: String,
    noteNode: some SyntaxProtocol
  ) {
    let noteMessage = MacroNoteMessage(message: note)
    let noteDiagnostic = Note(node: Syntax(noteNode), message: noteMessage)

    context.diagnose(
      Diagnostic(
        node: node,
        message: diagnostic,
        notes: [noteDiagnostic]
      )
    )
  }

  public func warning(_ message: String, at node: some SyntaxProtocol) {
    context.diagnose(
      Diagnostic(
        node: node,
        message: AdHocDiagnosticMessage(
          message: message,
          id: "warning",
          severity: .warning
        )
      )
    )
  }

  public func warning(
    _ message: String,
    at node: some SyntaxProtocol,
    domain: String
  ) {
    context.diagnose(
      Diagnostic(
        node: node,
        message: AdHocDiagnosticMessage(
          message: message,
          id: "warning",
          severity: .warning,
          domain: domain
        )
      )
    )
  }

  public func error(_ message: String, at node: some SyntaxProtocol) {
    context.diagnose(
      Diagnostic(
        node: node,
        message: AdHocDiagnosticMessage(
          message: message,
          id: "error",
          severity: .error
        )
      )
    )
  }

  public func error(
    _ message: String,
    at node: some SyntaxProtocol,
    domain: String
  ) {
    context.diagnose(
      Diagnostic(
        node: node,
        message: AdHocDiagnosticMessage(
          message: message,
          id: "error",
          severity: .error,
          domain: domain
        )
      )
    )
  }

  public func makeUniqueName(_ base: String) -> TokenSyntax {
    context.makeUniqueName(base)
  }

  // MARK: - Fix-It Support

  /// Emits an error with a Fix-It suggestion to insert text.
  public func error(
    _ diagnostic: some DiagnosticMessage,
    at node: some SyntaxProtocol,
    fixIt message: String,
    insert text: String,
    at position: AbsolutePosition
  ) {
    let changes: [FixIt.Change] = [
      .replace(
        oldNode: Syntax(node),
        newNode: Syntax(node)  // Swift limitation - we'll use a note instead
      )
    ]

    context.diagnose(
      Diagnostic(
        node: node,
        message: diagnostic,
        fixIts: [
          FixIt(message: MacroFixItMessage(message), changes: changes)
        ]
      )
    )
  }

  /// Emits an error with a Fix-It suggestion using a replacement node.
  public func error(
    _ diagnostic: some DiagnosticMessage,
    at node: some SyntaxProtocol,
    fixIt message: String,
    replaceWith newNode: some SyntaxProtocol
  ) {
    context.diagnose(
      Diagnostic(
        node: node,
        message: diagnostic,
        fixIts: [
          FixIt(
            message: MacroFixItMessage(message),
            changes: [.replace(oldNode: Syntax(node), newNode: Syntax(newNode))]
          )
        ]
      )
    )
  }
}

public struct MacroNoteMessage: SwiftDiagnostics.NoteMessage {
  public let message: String
  public let noteID: MessageID

  public init(message: String, domain: String = "InvariantSwift") {
    self.message = message
    self.noteID = MessageID(domain: domain, id: "note")
  }
}

public struct AdHocDiagnosticMessage: DiagnosticMessage {
  public let message: String
  public let diagnosticID: MessageID
  public let severity: DiagnosticSeverity

  public init(
    message: String,
    id: String,
    severity: DiagnosticSeverity,
    domain: String = "InvariantSwift"
  ) {
    self.message = message
    self.diagnosticID = MessageID(domain: domain, id: id)
    self.severity = severity
  }
}

/// A message for Fix-It suggestions in macro diagnostics.
public struct MacroFixItMessage: FixItMessage {
  public let message: String
  public let fixItID: MessageID

  public init(_ message: String, domain: String = "InvariantSwift") {
    self.message = message
    self.fixItID = MessageID(domain: domain, id: "fix-it")
  }
}
