/**
 * Code action provider for SwiftLint fixes
 *
 * Provides exactly 3 fix options per violation:
 * 1. Auto-fix or documentation
 * 2. Disable for line
 * 3. Disable for file
 */

import * as vscode from 'vscode';
import { fixRegistry } from './registry';
import { getRuleIdFromDiagnostic, DIAGNOSTIC_SOURCE } from '../diagnostics/converter';
import { Violation } from '../swiftlint/parser';

/**
 * Provides code actions (quick fixes) for SwiftLint violations
 */
export class SwiftLintCodeActionProvider implements vscode.CodeActionProvider {
  static readonly providedCodeActionKinds = [
    vscode.CodeActionKind.QuickFix,
    vscode.CodeActionKind.SourceFixAll,
  ];

  provideCodeActions(
    document: vscode.TextDocument,
    range: vscode.Range | vscode.Selection,
    context: vscode.CodeActionContext
  ): vscode.CodeAction[] {
    const actions: vscode.CodeAction[] = [];

    // Get SwiftLint diagnostics in the range
    const diagnostics = context.diagnostics.filter(
      (d) => d.source === DIAGNOSTIC_SOURCE
    );

    // Generate code actions for each diagnostic
    for (const diagnostic of diagnostics) {
      const ruleId = getRuleIdFromDiagnostic(diagnostic);
      if (!ruleId) {
        continue;
      }

      // Get the 3 fix templates for this rule
      const fixes = fixRegistry.getFixesForRule(ruleId);

      // Create a mock violation for the fix templates
      const violation = this.diagnosticToViolation(diagnostic, document);

      // Generate code actions from templates
      for (const template of fixes) {
        const action = this.createCodeAction(
          template.title,
          document,
          violation,
          diagnostic,
          template
        );
        if (action) {
          actions.push(action);
        }
      }
    }

    // Add "Fix All" action if there are multiple diagnostics
    if (diagnostics.length > 1) {
      const fixAllAction = this.createFixAllAction(document, diagnostics);
      if (fixAllAction) {
        actions.push(fixAllAction);
      }
    }

    return actions;
  }

  private createCodeAction(
    title: string,
    document: vscode.TextDocument,
    violation: Violation,
    diagnostic: vscode.Diagnostic,
    template: { createEdit: (doc: vscode.TextDocument, v: Violation, d: vscode.Diagnostic) => vscode.WorkspaceEdit | null; isPreferred?: boolean }
  ): vscode.CodeAction | null {
    const edit = template.createEdit(document, violation, diagnostic);

    // For actions that don't create edits (like opening docs), still create the action
    const action = new vscode.CodeAction(title, vscode.CodeActionKind.QuickFix);
    action.diagnostics = [diagnostic];

    if (edit) {
      action.edit = edit;
    }

    if (template.isPreferred) {
      action.isPreferred = true;
    }

    return action;
  }

  private createFixAllAction(
    document: vscode.TextDocument,
    diagnostics: readonly vscode.Diagnostic[]
  ): vscode.CodeAction | null {
    const action = new vscode.CodeAction(
      'Fix all auto-correctable SwiftLint issues',
      vscode.CodeActionKind.SourceFixAll
    );

    const edit = new vscode.WorkspaceEdit();
    let hasEdits = false;

    for (const diagnostic of diagnostics) {
      const ruleId = getRuleIdFromDiagnostic(diagnostic);
      if (!ruleId) {
        continue;
      }

      const fixes = fixRegistry.getFixesForRule(ruleId);
      const preferredFix = fixes.find((f) => f.isPreferred) ?? fixes[0];
      const violation = this.diagnosticToViolation(diagnostic, document);

      const fixEdit = preferredFix.createEdit(document, violation, diagnostic);
      if (fixEdit) {
        // Merge edits
        for (const [uri, edits] of fixEdit.entries()) {
          for (const e of edits) {
            if ('range' in e && 'newText' in e) {
              edit.replace(uri, e.range, e.newText);
              hasEdits = true;
            }
          }
        }
      }
    }

    if (!hasEdits) {
      return null;
    }

    action.edit = edit;
    action.diagnostics = [...diagnostics];
    return action;
  }

  private diagnosticToViolation(
    diagnostic: vscode.Diagnostic,
    document: vscode.TextDocument
  ): Violation {
    const ruleId = getRuleIdFromDiagnostic(diagnostic) ?? 'unknown';

    // Extract reason from message (format: "reason (rule_id)")
    const message = diagnostic.message;
    const reasonMatch = message.match(/^(.+?)\s*\([^)]+\)$/);
    const reason = reasonMatch ? reasonMatch[1] : message;

    return {
      file: document.uri.fsPath,
      line: diagnostic.range.start.line + 1, // Convert to 1-based
      character: diagnostic.range.start.character + 1,
      severity: diagnostic.severity === vscode.DiagnosticSeverity.Error ? 'Error' : 'Warning',
      type: ruleId, // Use rule_id as type fallback
      ruleId,
      reason,
    };
  }
}
