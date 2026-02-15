/**
 * Fix template registry - maps rules to fix suggestions
 *
 * Each rule has exactly 3 fix options:
 * 1. Auto-fix (if available) or documentation link
 * 2. Disable rule for this line
 * 3. Disable rule for entire file
 */

import * as vscode from 'vscode';
import { Violation } from '../swiftlint/parser';

/**
 * A fix template that can generate a code action
 */
export interface FixTemplate {
  /** Display title for the code action */
  title: string;
  /** Whether this is the preferred fix */
  isPreferred?: boolean;
  /** Generate the workspace edit for this fix */
  createEdit: (
    document: vscode.TextDocument,
    violation: Violation,
    diagnostic: vscode.Diagnostic
  ) => vscode.WorkspaceEdit | null;
}

/**
 * Fix templates for a specific rule
 */
export interface RuleFixes {
  ruleId: string;
  fixes: [FixTemplate, FixTemplate, FixTemplate];
}

/**
 * Registry of rule fixes
 */
class FixTemplateRegistry {
  private rules = new Map<string, RuleFixes>();

  constructor() {
    this.registerDefaultFixes();
    this.registerSpacingFixes();
    this.registerStyleFixes();
    this.registerNamingFixes();
    this.registerAllRules();
  }

  /**
   * Get fixes for a rule
   */
  getFixesForRule(ruleId: string): [FixTemplate, FixTemplate, FixTemplate] {
    const ruleFixes = this.rules.get(ruleId);
    if (ruleFixes) {
      return ruleFixes.fixes;
    }

    // Return default fixes for unknown rules
    return this.createDefaultFixes(ruleId);
  }

  /**
   * Create default fixes that work for any rule
   */
  private createDefaultFixes(ruleId: string): [FixTemplate, FixTemplate, FixTemplate] {
    return [
      {
        title: `View documentation for '${ruleId}'`,
        createEdit: () => {
          // Open documentation instead of editing
          const url = `https://realm.github.io/SwiftLint/${ruleId}.html`;
          vscode.env.openExternal(vscode.Uri.parse(url));
          return null;
        },
      },
      createLineDisableFix(ruleId),
      createFileDisableFix(ruleId),
    ];
  }

  private registerDefaultFixes(): void {
    // These are common rules without specific auto-fixes
    const defaultRules = [
      'todo',
      'fixme',
      'mark',
      'function_body_length',
      'file_length',
      'type_body_length',
      'cyclomatic_complexity',
      'nesting',
      'large_tuple',
    ];

    for (const ruleId of defaultRules) {
      this.rules.set(ruleId, {
        ruleId,
        fixes: this.createDefaultFixes(ruleId),
      });
    }
  }

  private registerSpacingFixes(): void {
    // trailing_whitespace
    this.rules.set('trailing_whitespace', {
      ruleId: 'trailing_whitespace',
      fixes: [
        {
          title: 'Remove trailing whitespace',
          isPreferred: true,
          createEdit: (doc, violation, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const line = doc.lineAt(diagnostic.range.start.line);
            const trimmed = line.text.trimEnd();
            const range = new vscode.Range(
              line.range.start.line,
              trimmed.length,
              line.range.start.line,
              line.text.length
            );
            edit.delete(doc.uri, range);
            return edit;
          },
        },
        createLineDisableFix('trailing_whitespace'),
        createFileDisableFix('trailing_whitespace'),
      ],
    });

    // trailing_newline
    this.rules.set('trailing_newline', {
      ruleId: 'trailing_newline',
      fixes: [
        {
          title: 'Fix trailing newline',
          isPreferred: true,
          createEdit: (doc) => {
            const edit = new vscode.WorkspaceEdit();
            const lastLine = doc.lineAt(doc.lineCount - 1);

            if (lastLine.text.length === 0) {
              // Remove extra blank line
              if (doc.lineCount > 1) {
                const prevLine = doc.lineAt(doc.lineCount - 2);
                edit.delete(
                  doc.uri,
                  new vscode.Range(prevLine.range.end, lastLine.range.end)
                );
              }
            } else {
              // Add trailing newline
              edit.insert(doc.uri, lastLine.range.end, '\n');
            }
            return edit;
          },
        },
        createLineDisableFix('trailing_newline'),
        createFileDisableFix('trailing_newline'),
      ],
    });

    // colon
    this.rules.set('colon', {
      ruleId: 'colon',
      fixes: [
        {
          title: 'Fix colon spacing (no space before, one space after)',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Standard pattern: no space before colon, one space after
            const fixed = text.replace(/\s*:\s*/g, ': ');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('colon'),
        createFileDisableFix('colon'),
      ],
    });

    // comma
    this.rules.set('comma', {
      ruleId: 'comma',
      fixes: [
        {
          title: 'Fix comma spacing (no space before, one space after)',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/\s*,\s*/g, ', ');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('comma'),
        createFileDisableFix('comma'),
      ],
    });

    // vertical_whitespace
    this.rules.set('vertical_whitespace', {
      ruleId: 'vertical_whitespace',
      fixes: [
        {
          title: 'Remove extra blank lines',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const startLine = diagnostic.range.start.line;
            const endLine = diagnostic.range.end.line;

            // Keep only one blank line
            if (endLine > startLine) {
              const deleteRange = new vscode.Range(
                startLine + 1,
                0,
                endLine,
                doc.lineAt(endLine).range.end.character
              );
              edit.delete(doc.uri, deleteRange);
            }
            return edit;
          },
        },
        createLineDisableFix('vertical_whitespace'),
        createFileDisableFix('vertical_whitespace'),
      ],
    });
  }

  private registerStyleFixes(): void {
    // line_length
    this.rules.set('line_length', {
      ruleId: 'line_length',
      fixes: [
        {
          title: 'Break line at logical point',
          createEdit: () => {
            // This requires semantic understanding, show message instead
            vscode.window.showInformationMessage(
              'Consider breaking this line at a logical point (after comma, operator, or opening bracket).'
            );
            return null;
          },
        },
        createLineDisableFix('line_length'),
        createFileDisableFix('line_length'),
      ],
    });

    // trailing_semicolon
    this.rules.set('trailing_semicolon', {
      ruleId: 'trailing_semicolon',
      fixes: [
        {
          title: 'Remove trailing semicolon',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const line = doc.lineAt(diagnostic.range.start.line);
            const text = line.text;
            const semicolonIndex = text.lastIndexOf(';');
            if (semicolonIndex >= 0) {
              edit.delete(
                doc.uri,
                new vscode.Range(
                  line.range.start.line,
                  semicolonIndex,
                  line.range.start.line,
                  semicolonIndex + 1
                )
              );
            }
            return edit;
          },
        },
        createLineDisableFix('trailing_semicolon'),
        createFileDisableFix('trailing_semicolon'),
      ],
    });

    // opening_brace
    this.rules.set('opening_brace', {
      ruleId: 'opening_brace',
      fixes: [
        {
          title: 'Fix opening brace placement',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Opening brace should be preceded by single space, not newline
            const fixed = text.replace(/\s*\{/g, ' {');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('opening_brace'),
        createFileDisableFix('opening_brace'),
      ],
    });

    // statement_position (else/catch on same line)
    this.rules.set('statement_position', {
      ruleId: 'statement_position',
      fixes: [
        {
          title: 'Fix statement position',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // } else { should be on same line
            const fixed = text
              .replace(/\}\s*\n\s*else/g, '} else')
              .replace(/\}\s*\n\s*catch/g, '} catch');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('statement_position'),
        createFileDisableFix('statement_position'),
      ],
    });

    // return_arrow_whitespace
    this.rules.set('return_arrow_whitespace', {
      ruleId: 'return_arrow_whitespace',
      fixes: [
        {
          title: 'Fix return arrow spacing',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Should be "-> Type" with spaces
            const fixed = text.replace(/\s*->\s*/g, ' -> ');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('return_arrow_whitespace'),
        createFileDisableFix('return_arrow_whitespace'),
      ],
    });
  }

  private registerNamingFixes(): void {
    // identifier_name
    this.rules.set('identifier_name', {
      ruleId: 'identifier_name',
      fixes: [
        {
          title: 'Rename to follow naming conventions',
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Use Rename Symbol (F2) to rename this identifier following Swift naming conventions.'
            );
            return null;
          },
        },
        createLineDisableFix('identifier_name'),
        createFileDisableFix('identifier_name'),
      ],
    });

    // type_name
    this.rules.set('type_name', {
      ruleId: 'type_name',
      fixes: [
        {
          title: 'Rename type to follow conventions',
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Use Rename Symbol (F2) to rename this type. Types should use UpperCamelCase.'
            );
            return null;
          },
        },
        createLineDisableFix('type_name'),
        createFileDisableFix('type_name'),
      ],
    });

    // function_parameter_count
    this.rules.set('function_parameter_count', {
      ruleId: 'function_parameter_count',
      fixes: [
        {
          title: 'Consider using a configuration struct',
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Consider grouping related parameters into a struct or using a builder pattern.'
            );
            return null;
          },
        },
        createLineDisableFix('function_parameter_count'),
        createFileDisableFix('function_parameter_count'),
      ],
    });
  }

  private registerAllRules(): void {
    // Force/implicit unwrapping rules
    this.registerForceRules();
    // Syntax rules
    this.registerSyntaxRules();
    // Documentation rules
    this.registerDocRules();
    // Metrics rules
    this.registerMetricsRules();
    // Lint rules
    this.registerLintRules();
    // Performance rules
    this.registerPerformanceRules();
    // Idiomatic rules
    this.registerIdiomaticRules();
  }

  private registerForceRules(): void {
    // force_cast
    this.rules.set('force_cast', {
      ruleId: 'force_cast',
      fixes: [
        {
          title: 'Use conditional cast (as?) with guard/if-let',
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/\s+as!\s+/g, ' as? ');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('force_cast'),
        createFileDisableFix('force_cast'),
      ],
    });

    // force_try
    this.rules.set('force_try', {
      ruleId: 'force_try',
      fixes: [
        {
          title: 'Use do-catch or try? instead',
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/try!/g, 'try?');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('force_try'),
        createFileDisableFix('force_try'),
      ],
    });

    // force_unwrapping
    this.rules.set('force_unwrapping', {
      ruleId: 'force_unwrapping',
      fixes: [
        {
          title: 'Use guard let or if let instead',
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace force unwrap (!) with guard let, if let, or nil coalescing (??).'
            );
            return null;
          },
        },
        createLineDisableFix('force_unwrapping'),
        createFileDisableFix('force_unwrapping'),
      ],
    });

    // implicitly_unwrapped_optional
    this.rules.set('implicitly_unwrapped_optional', {
      ruleId: 'implicitly_unwrapped_optional',
      fixes: [
        {
          title: 'Use regular optional (?) instead',
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const line = doc.lineAt(diagnostic.range.start.line);
            const fixed = line.text.replace(/:\s*(\w+)!/g, ': $1?');
            edit.replace(doc.uri, line.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('implicitly_unwrapped_optional'),
        createFileDisableFix('implicitly_unwrapped_optional'),
      ],
    });
  }

  private registerSyntaxRules(): void {
    // closure_parameter_position
    this.rules.set('closure_parameter_position', {
      ruleId: 'closure_parameter_position',
      fixes: [
        {
          title: 'Move parameters to same line as opening brace',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/\{\s*\n\s*(\([^)]*\))\s*in/g, '{ $1 in');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('closure_parameter_position'),
        createFileDisableFix('closure_parameter_position'),
      ],
    });

    // closure_end_indentation
    this.rules.set('closure_end_indentation', {
      ruleId: 'closure_end_indentation',
      fixes: [
        {
          title: 'Fix closing brace indentation',
          isPreferred: true,
          createEdit: () => {
            vscode.commands.executeCommand('editor.action.formatDocument');
            return null;
          },
        },
        createLineDisableFix('closure_end_indentation'),
        createFileDisableFix('closure_end_indentation'),
      ],
    });

    // control_statement
    this.rules.set('control_statement', {
      ruleId: 'control_statement',
      fixes: [
        {
          title: 'Remove unnecessary parentheses',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Remove outer parens from if/guard/while/switch conditions
            const fixed = text.replace(
              /(if|guard|while|switch)\s*\(([^)]+)\)/g,
              '$1 $2'
            );
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('control_statement'),
        createFileDisableFix('control_statement'),
      ],
    });

    // empty_parentheses_with_trailing_closure
    this.rules.set('empty_parentheses_with_trailing_closure', {
      ruleId: 'empty_parentheses_with_trailing_closure',
      fixes: [
        {
          title: 'Remove empty parentheses',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/\(\)\s*\{/g, ' {');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('empty_parentheses_with_trailing_closure'),
        createFileDisableFix('empty_parentheses_with_trailing_closure'),
      ],
    });

    // redundant_void_return
    this.rules.set('redundant_void_return', {
      ruleId: 'redundant_void_return',
      fixes: [
        {
          title: 'Remove redundant -> Void',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/\s*->\s*(Void|\(\))/g, '');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('redundant_void_return'),
        createFileDisableFix('redundant_void_return'),
      ],
    });

    // void_return
    this.rules.set('void_return', {
      ruleId: 'void_return',
      fixes: [
        {
          title: 'Use -> Void instead of -> ()',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/->\s*\(\)/g, '-> Void');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('void_return'),
        createFileDisableFix('void_return'),
      ],
    });

    // redundant_optional_initialization
    this.rules.set('redundant_optional_initialization', {
      ruleId: 'redundant_optional_initialization',
      fixes: [
        {
          title: 'Remove = nil (optionals are nil by default)',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/\s*=\s*nil\s*$/g, '');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('redundant_optional_initialization'),
        createFileDisableFix('redundant_optional_initialization'),
      ],
    });

    // syntactic_sugar
    this.rules.set('syntactic_sugar', {
      ruleId: 'syntactic_sugar',
      fixes: [
        {
          title: 'Use shorthand syntax',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            let fixed = text;
            fixed = fixed.replace(/Array<(\w+)>/g, '[$1]');
            fixed = fixed.replace(/Dictionary<(\w+),\s*(\w+)>/g, '[$1: $2]');
            fixed = fixed.replace(/Optional<(\w+)>/g, '$1?');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('syntactic_sugar'),
        createFileDisableFix('syntactic_sugar'),
      ],
    });

    // shorthand_operator
    this.rules.set('shorthand_operator', {
      ruleId: 'shorthand_operator',
      fixes: [
        {
          title: 'Use shorthand operator (+=, -=, etc.)',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            let fixed = text;
            fixed = fixed.replace(/(\w+)\s*=\s*\1\s*\+\s*/g, '$1 += ');
            fixed = fixed.replace(/(\w+)\s*=\s*\1\s*-\s*/g, '$1 -= ');
            fixed = fixed.replace(/(\w+)\s*=\s*\1\s*\*\s*/g, '$1 *= ');
            fixed = fixed.replace(/(\w+)\s*=\s*\1\s*\/\s*/g, '$1 /= ');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('shorthand_operator'),
        createFileDisableFix('shorthand_operator'),
      ],
    });
  }

  private registerDocRules(): void {
    // missing_docs
    this.rules.set('missing_docs', {
      ruleId: 'missing_docs',
      fixes: [
        {
          title: 'Add documentation comment',
          createEdit: (doc, violation) => {
            const edit = new vscode.WorkspaceEdit();
            const line = doc.lineAt(violation.line - 1);
            const indent = line.text.match(/^(\s*)/)?.[1] ?? '';
            const docComment = `${indent}/// <#Description#>\n`;
            edit.insert(doc.uri, new vscode.Position(violation.line - 1, 0), docComment);
            return edit;
          },
        },
        createLineDisableFix('missing_docs'),
        createFileDisableFix('missing_docs'),
      ],
    });

    // orphaned_doc_comment
    this.rules.set('orphaned_doc_comment', {
      ruleId: 'orphaned_doc_comment',
      fixes: [
        {
          title: 'Remove orphaned documentation',
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const line = doc.lineAt(diagnostic.range.start.line);
            edit.delete(doc.uri, line.rangeIncludingLineBreak);
            return edit;
          },
        },
        createLineDisableFix('orphaned_doc_comment'),
        createFileDisableFix('orphaned_doc_comment'),
      ],
    });
  }

  private registerMetricsRules(): void {
    const metricsRules = [
      'closure_body_length',
      'enum_case_associated_values_count',
      'file_length',
      'function_body_length',
      'type_body_length',
    ];

    for (const ruleId of metricsRules) {
      this.rules.set(ruleId, {
        ruleId,
        fixes: [
          {
            title: 'Consider extracting functionality',
            createEdit: () => {
              vscode.window.showInformationMessage(
                'Consider extracting some functionality into separate methods or types to reduce complexity.'
              );
              return null;
            },
          },
          createLineDisableFix(ruleId),
          createFileDisableFix(ruleId),
        ],
      });
    }
  }

  private registerLintRules(): void {
    // unused_closure_parameter
    this.rules.set('unused_closure_parameter', {
      ruleId: 'unused_closure_parameter',
      fixes: [
        {
          title: 'Replace with underscore (_)',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Extract the unused parameter name and replace with _
            const match = text.match(/(\w+)/);
            if (match) {
              edit.replace(doc.uri, diagnostic.range, '_');
            }
            return edit;
          },
        },
        createLineDisableFix('unused_closure_parameter'),
        createFileDisableFix('unused_closure_parameter'),
      ],
    });

    // unused_enumerated
    this.rules.set('unused_enumerated', {
      ruleId: 'unused_enumerated',
      fixes: [
        {
          title: 'Remove .enumerated() if index unused',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'If the index is unused, remove .enumerated() and use direct iteration.'
            );
            return null;
          },
        },
        createLineDisableFix('unused_enumerated'),
        createFileDisableFix('unused_enumerated'),
      ],
    });

    // unused_optional_binding
    this.rules.set('unused_optional_binding', {
      ruleId: 'unused_optional_binding',
      fixes: [
        {
          title: 'Use != nil check instead',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Convert "if let _ = x" to "if x != nil"
            const fixed = text.replace(/let\s+_\s*=\s*(\w+)/g, '$1 != nil');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('unused_optional_binding'),
        createFileDisableFix('unused_optional_binding'),
      ],
    });

    // private_over_fileprivate
    this.rules.set('private_over_fileprivate', {
      ruleId: 'private_over_fileprivate',
      fixes: [
        {
          title: 'Use private instead of fileprivate',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/fileprivate/g, 'private');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('private_over_fileprivate'),
        createFileDisableFix('private_over_fileprivate'),
      ],
    });

    // redundant_discardable_let
    this.rules.set('redundant_discardable_let', {
      ruleId: 'redundant_discardable_let',
      fixes: [
        {
          title: 'Remove redundant let _ =',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/let\s+_\s*=\s*/g, '');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('redundant_discardable_let'),
        createFileDisableFix('redundant_discardable_let'),
      ],
    });

    // mark
    this.rules.set('mark', {
      ruleId: 'mark',
      fixes: [
        {
          title: 'Fix MARK format',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Ensure proper format: // MARK: - Description
            const fixed = text.replace(/\/\/\s*MARK\s*:?\s*-?\s*/gi, '// MARK: - ');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('mark'),
        createFileDisableFix('mark'),
      ],
    });
  }

  private registerPerformanceRules(): void {
    // empty_count
    this.rules.set('empty_count', {
      ruleId: 'empty_count',
      fixes: [
        {
          title: 'Use .isEmpty instead of .count == 0',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            let fixed = text;
            fixed = fixed.replace(/\.count\s*==\s*0/g, '.isEmpty');
            fixed = fixed.replace(/\.count\s*!=\s*0/g, '!.isEmpty');
            fixed = fixed.replace(/\.count\s*>\s*0/g, '!.isEmpty');
            fixed = fixed.replace(/\.count\s*<\s*1/g, '.isEmpty');
            fixed = fixed.replace(/0\s*==\s*(\w+)\.count/g, '$1.isEmpty');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('empty_count'),
        createFileDisableFix('empty_count'),
      ],
    });

    // first_where
    this.rules.set('first_where', {
      ruleId: 'first_where',
      fixes: [
        {
          title: 'Use .first(where:) instead of .filter().first',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace .filter { ... }.first with .first(where: { ... }) for better performance.'
            );
            return null;
          },
        },
        createLineDisableFix('first_where'),
        createFileDisableFix('first_where'),
      ],
    });

    // last_where
    this.rules.set('last_where', {
      ruleId: 'last_where',
      fixes: [
        {
          title: 'Use .last(where:) instead of .filter().last',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace .filter { ... }.last with .last(where: { ... }) for better performance.'
            );
            return null;
          },
        },
        createLineDisableFix('last_where'),
        createFileDisableFix('last_where'),
      ],
    });

    // contains_over_filter_count
    this.rules.set('contains_over_filter_count', {
      ruleId: 'contains_over_filter_count',
      fixes: [
        {
          title: 'Use .contains(where:) instead',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace .filter { ... }.count > 0 with .contains(where: { ... }).'
            );
            return null;
          },
        },
        createLineDisableFix('contains_over_filter_count'),
        createFileDisableFix('contains_over_filter_count'),
      ],
    });

    // contains_over_filter_is_empty
    this.rules.set('contains_over_filter_is_empty', {
      ruleId: 'contains_over_filter_is_empty',
      fixes: [
        {
          title: 'Use .contains(where:) instead',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace !.filter { ... }.isEmpty with .contains(where: { ... }).'
            );
            return null;
          },
        },
        createLineDisableFix('contains_over_filter_is_empty'),
        createFileDisableFix('contains_over_filter_is_empty'),
      ],
    });

    // contains_over_first_not_nil
    this.rules.set('contains_over_first_not_nil', {
      ruleId: 'contains_over_first_not_nil',
      fixes: [
        {
          title: 'Use .contains(where:) instead',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace .first(where: { ... }) != nil with .contains(where: { ... }).'
            );
            return null;
          },
        },
        createLineDisableFix('contains_over_first_not_nil'),
        createFileDisableFix('contains_over_first_not_nil'),
      ],
    });

    // flatmap_over_map_reduce
    this.rules.set('flatmap_over_map_reduce', {
      ruleId: 'flatmap_over_map_reduce',
      fixes: [
        {
          title: 'Use .flatMap instead of .map.reduce',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace .map { ... }.reduce([], +) with .flatMap { ... }.'
            );
            return null;
          },
        },
        createLineDisableFix('flatmap_over_map_reduce'),
        createFileDisableFix('flatmap_over_map_reduce'),
      ],
    });

    // reduce_boolean
    this.rules.set('reduce_boolean', {
      ruleId: 'reduce_boolean',
      fixes: [
        {
          title: 'Use .allSatisfy or .contains instead',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace .reduce(true) { $0 && ... } with .allSatisfy { ... } or .reduce(false) { $0 || ... } with .contains { ... }.'
            );
            return null;
          },
        },
        createLineDisableFix('reduce_boolean'),
        createFileDisableFix('reduce_boolean'),
      ],
    });

    // sorted_first_last
    this.rules.set('sorted_first_last', {
      ruleId: 'sorted_first_last',
      fixes: [
        {
          title: 'Use .min() or .max() instead',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Replace .sorted().first with .min() or .sorted().last with .max().'
            );
            return null;
          },
        },
        createLineDisableFix('sorted_first_last'),
        createFileDisableFix('sorted_first_last'),
      ],
    });
  }

  private registerIdiomaticRules(): void {
    // explicit_init
    this.rules.set('explicit_init', {
      ruleId: 'explicit_init',
      fixes: [
        {
          title: 'Remove explicit .init',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/\.init\(/g, '(');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('explicit_init'),
        createFileDisableFix('explicit_init'),
      ],
    });

    // redundant_nil_coalescing
    this.rules.set('redundant_nil_coalescing', {
      ruleId: 'redundant_nil_coalescing',
      fixes: [
        {
          title: 'Remove redundant ?? nil',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/\s*\?\?\s*nil/g, '');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('redundant_nil_coalescing'),
        createFileDisableFix('redundant_nil_coalescing'),
      ],
    });

    // redundant_type_annotation
    this.rules.set('redundant_type_annotation', {
      ruleId: 'redundant_type_annotation',
      fixes: [
        {
          title: 'Remove redundant type annotation',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Remove ": Type" when it can be inferred
            const fixed = text.replace(/:\s*\w+(\s*=)/g, '$1');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('redundant_type_annotation'),
        createFileDisableFix('redundant_type_annotation'),
      ],
    });

    // toggle_bool
    this.rules.set('toggle_bool', {
      ruleId: 'toggle_bool',
      fixes: [
        {
          title: 'Use .toggle() instead',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Convert "x = !x" to "x.toggle()"
            const match = text.match(/(\w+)\s*=\s*!\1/);
            if (match) {
              const fixed = `${match[1]}.toggle()`;
              edit.replace(doc.uri, diagnostic.range, fixed);
            }
            return edit;
          },
        },
        createLineDisableFix('toggle_bool'),
        createFileDisableFix('toggle_bool'),
      ],
    });

    // trailing_closure
    this.rules.set('trailing_closure', {
      ruleId: 'trailing_closure',
      fixes: [
        {
          title: 'Use trailing closure syntax',
          isPreferred: true,
          createEdit: () => {
            vscode.window.showInformationMessage(
              'Move the closure outside the parentheses using trailing closure syntax.'
            );
            return null;
          },
        },
        createLineDisableFix('trailing_closure'),
        createFileDisableFix('trailing_closure'),
      ],
    });

    // yoda_condition
    this.rules.set('yoda_condition', {
      ruleId: 'yoda_condition',
      fixes: [
        {
          title: 'Swap operands (variable first)',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            // Swap "literal == variable" to "variable == literal"
            const fixed = text.replace(
              /(["\d\w.]+)\s*(==|!=)\s*(\w+)/g,
              '$3 $2 $1'
            );
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('yoda_condition'),
        createFileDisableFix('yoda_condition'),
      ],
    });

    // legacy_cggeometry_functions
    this.rules.set('legacy_cggeometry_functions', {
      ruleId: 'legacy_cggeometry_functions',
      fixes: [
        {
          title: 'Use modern CGRect/CGPoint properties',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            let fixed = text;
            fixed = fixed.replace(/CGRectGetWidth\((\w+)\)/g, '$1.width');
            fixed = fixed.replace(/CGRectGetHeight\((\w+)\)/g, '$1.height');
            fixed = fixed.replace(/CGRectGetMinX\((\w+)\)/g, '$1.minX');
            fixed = fixed.replace(/CGRectGetMinY\((\w+)\)/g, '$1.minY');
            fixed = fixed.replace(/CGRectGetMaxX\((\w+)\)/g, '$1.maxX');
            fixed = fixed.replace(/CGRectGetMaxY\((\w+)\)/g, '$1.maxY');
            fixed = fixed.replace(/CGRectGetMidX\((\w+)\)/g, '$1.midX');
            fixed = fixed.replace(/CGRectGetMidY\((\w+)\)/g, '$1.midY');
            fixed = fixed.replace(/CGRectIsEmpty\((\w+)\)/g, '$1.isEmpty');
            fixed = fixed.replace(/CGRectIsNull\((\w+)\)/g, '$1.isNull');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('legacy_cggeometry_functions'),
        createFileDisableFix('legacy_cggeometry_functions'),
      ],
    });

    // legacy_constant
    this.rules.set('legacy_constant', {
      ruleId: 'legacy_constant',
      fixes: [
        {
          title: 'Use modern constant syntax',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            let fixed = text;
            fixed = fixed.replace(/CGRectZero/g, '.zero');
            fixed = fixed.replace(/CGPointZero/g, '.zero');
            fixed = fixed.replace(/CGSizeZero/g, '.zero');
            fixed = fixed.replace(/NSZeroRect/g, '.zero');
            fixed = fixed.replace(/NSZeroPoint/g, '.zero');
            fixed = fixed.replace(/NSZeroSize/g, '.zero');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('legacy_constant'),
        createFileDisableFix('legacy_constant'),
      ],
    });

    // legacy_constructor
    this.rules.set('legacy_constructor', {
      ruleId: 'legacy_constructor',
      fixes: [
        {
          title: 'Use modern constructor syntax',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            let fixed = text;
            fixed = fixed.replace(/CGRectMake\(/g, 'CGRect(x: ');
            fixed = fixed.replace(/CGPointMake\(/g, 'CGPoint(x: ');
            fixed = fixed.replace(/CGSizeMake\(/g, 'CGSize(width: ');
            fixed = fixed.replace(/NSMakeRect\(/g, 'NSRect(x: ');
            fixed = fixed.replace(/NSMakePoint\(/g, 'NSPoint(x: ');
            fixed = fixed.replace(/NSMakeSize\(/g, 'NSSize(width: ');
            fixed = fixed.replace(/NSMakeRange\(/g, 'NSRange(location: ');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('legacy_constructor'),
        createFileDisableFix('legacy_constructor'),
      ],
    });

    // prefer_self_type_over_type_of_self
    this.rules.set('prefer_self_type_over_type_of_self', {
      ruleId: 'prefer_self_type_over_type_of_self',
      fixes: [
        {
          title: 'Use Self instead of type(of: self)',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const text = doc.getText(diagnostic.range);
            const fixed = text.replace(/type\(of:\s*self\)/g, 'Self');
            edit.replace(doc.uri, diagnostic.range, fixed);
            return edit;
          },
        },
        createLineDisableFix('prefer_self_type_over_type_of_self'),
        createFileDisableFix('prefer_self_type_over_type_of_self'),
      ],
    });

    // unneeded_break_in_switch
    this.rules.set('unneeded_break_in_switch', {
      ruleId: 'unneeded_break_in_switch',
      fixes: [
        {
          title: 'Remove unnecessary break',
          isPreferred: true,
          createEdit: (doc, _, diagnostic) => {
            const edit = new vscode.WorkspaceEdit();
            const line = doc.lineAt(diagnostic.range.start.line);
            edit.delete(doc.uri, line.rangeIncludingLineBreak);
            return edit;
          },
        },
        createLineDisableFix('unneeded_break_in_switch'),
        createFileDisableFix('unneeded_break_in_switch'),
      ],
    });
  }
}

/**
 * Create a fix that disables the rule for the current line
 */
function createLineDisableFix(ruleId: string): FixTemplate {
  return {
    title: `Disable '${ruleId}' for this line`,
    createEdit: (doc, _, diagnostic) => {
      const edit = new vscode.WorkspaceEdit();
      const line = doc.lineAt(diagnostic.range.start.line);
      const indent = line.text.match(/^(\s*)/)?.[1] ?? '';
      const comment = `${indent}// swiftlint:disable:next ${ruleId}\n`;
      edit.insert(doc.uri, new vscode.Position(line.lineNumber, 0), comment);
      return edit;
    },
  };
}

/**
 * Create a fix that disables the rule for the entire file
 */
function createFileDisableFix(ruleId: string): FixTemplate {
  return {
    title: `Disable '${ruleId}' for entire file`,
    createEdit: (doc) => {
      const edit = new vscode.WorkspaceEdit();
      const comment = `// swiftlint:disable ${ruleId}\n`;
      edit.insert(doc.uri, new vscode.Position(0, 0), comment);
      return edit;
    },
  };
}

// Export singleton instance
export const fixRegistry = new FixTemplateRegistry();
