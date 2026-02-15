/**
 * Convert SwiftLint violations to VS Code diagnostics
 */

import * as vscode from 'vscode';
import { Violation } from '../swiftlint/parser';

/** Diagnostic source identifier */
export const DIAGNOSTIC_SOURCE = 'SwiftLint';

/**
 * Convert a Violation to a VS Code Diagnostic
 */
export function violationToDiagnostic(
  violation: Violation,
  document: vscode.TextDocument
): vscode.Diagnostic {
  const range = getRange(violation, document);
  const severity = getSeverity(violation.severity);
  const message = `${violation.reason} (${violation.ruleId})`;

  const diagnostic = new vscode.Diagnostic(range, message, severity);
  diagnostic.source = DIAGNOSTIC_SOURCE;
  diagnostic.code = violation.ruleId;

  return diagnostic;
}

/**
 * Convert multiple violations to diagnostics
 */
export function violationsToDiagnostics(
  violations: Violation[],
  document: vscode.TextDocument
): vscode.Diagnostic[] {
  return violations
    .filter((v) => v.file === document.uri.fsPath)
    .map((v) => violationToDiagnostic(v, document));
}

/**
 * Calculate the range for a violation
 */
function getRange(
  violation: Violation,
  document: vscode.TextDocument
): vscode.Range {
  // Line numbers are 1-based in SwiftLint, 0-based in VS Code
  const lineIndex = Math.max(0, violation.line - 1);

  // Ensure line exists in document
  if (lineIndex >= document.lineCount) {
    return new vscode.Range(document.lineCount - 1, 0, document.lineCount - 1, 0);
  }

  const line = document.lineAt(lineIndex);

  // If character position is specified, try to get word range
  if (violation.character !== null && violation.character > 0) {
    const charIndex = violation.character - 1; // Convert to 0-based
    const position = new vscode.Position(lineIndex, charIndex);

    // Try to get the word at position
    const wordRange = document.getWordRangeAtPosition(position);
    if (wordRange) {
      return wordRange;
    }

    // Fall back to character position to end of meaningful content
    const endChar = Math.min(charIndex + 20, line.range.end.character);
    return new vscode.Range(lineIndex, charIndex, lineIndex, endChar);
  }

  // No character position - highlight the entire line (trimmed)
  const startChar = line.firstNonWhitespaceCharacterIndex;
  return new vscode.Range(lineIndex, startChar, lineIndex, line.range.end.character);
}

/**
 * Convert SwiftLint severity to VS Code DiagnosticSeverity
 */
function getSeverity(severity: 'Warning' | 'Error'): vscode.DiagnosticSeverity {
  switch (severity) {
    case 'Error':
      return vscode.DiagnosticSeverity.Error;
    case 'Warning':
      return vscode.DiagnosticSeverity.Warning;
    default:
      return vscode.DiagnosticSeverity.Information;
  }
}

/**
 * Extract rule ID from a diagnostic (stored in diagnostic.code)
 */
export function getRuleIdFromDiagnostic(
  diagnostic: vscode.Diagnostic
): string | undefined {
  if (diagnostic.source !== DIAGNOSTIC_SOURCE) {
    return undefined;
  }

  if (typeof diagnostic.code === 'string') {
    return diagnostic.code;
  }

  if (
    typeof diagnostic.code === 'object' &&
    diagnostic.code !== null &&
    'value' in diagnostic.code
  ) {
    return String(diagnostic.code.value);
  }

  return undefined;
}
