/**
 * SwiftLint Fixer - VS Code Extension
 *
 * Displays SwiftLint violations as inline diagnostics and provides
 * 3 rule-based fix suggestions per violation.
 */

import * as vscode from 'vscode';
import { DiagnosticProvider } from './diagnostics/provider';
import { SwiftLintCodeActionProvider } from './fixes/codeActionProvider';
import { fixFile } from './swiftlint/runner';
import { findConfigFile, getSettings } from './config/settings';

let diagnosticProvider: DiagnosticProvider | undefined;

/**
 * Extension activation
 */
export function activate(context: vscode.ExtensionContext): void {
  console.log('SwiftLint Fixer is now active');

  const settings = getSettings();
  if (!settings.enable) {
    return;
  }

  // Create diagnostic provider
  diagnosticProvider = new DiagnosticProvider();
  context.subscriptions.push(diagnosticProvider);

  // Register code action provider
  const codeActionProvider = vscode.languages.registerCodeActionsProvider(
    { language: 'swift', scheme: 'file' },
    new SwiftLintCodeActionProvider(),
    {
      providedCodeActionKinds: SwiftLintCodeActionProvider.providedCodeActionKinds,
    }
  );
  context.subscriptions.push(codeActionProvider);

  // Register commands
  context.subscriptions.push(
    vscode.commands.registerCommand('swiftlintFixer.lintDocument', lintCurrentDocument),
    vscode.commands.registerCommand('swiftlintFixer.fixDocument', fixCurrentDocument),
    vscode.commands.registerCommand('swiftlintFixer.lintWorkspace', lintWorkspace)
  );

  // Lint all open Swift documents on activation
  diagnosticProvider.lintAllOpenDocuments();
}

/**
 * Extension deactivation
 */
export function deactivate(): void {
  diagnosticProvider?.dispose();
  diagnosticProvider = undefined;
}

/**
 * Lint the currently active document
 */
async function lintCurrentDocument(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor || editor.document.languageId !== 'swift') {
    vscode.window.showWarningMessage('No Swift file is currently open');
    return;
  }

  if (diagnosticProvider) {
    await diagnosticProvider.lintDocument(editor.document);
    vscode.window.showInformationMessage('SwiftLint: Document linted');
  }
}

/**
 * Fix all auto-correctable issues in the current document
 */
async function fixCurrentDocument(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor || editor.document.languageId !== 'swift') {
    vscode.window.showWarningMessage('No Swift file is currently open');
    return;
  }

  const document = editor.document;
  const workspaceFolder = vscode.workspace.getWorkspaceFolder(document.uri);
  const cwd = workspaceFolder?.uri.fsPath ?? require('path').dirname(document.uri.fsPath);

  // Find config file
  const configPath = workspaceFolder
    ? await findConfigFile(workspaceFolder)
    : undefined;

  // Save document first
  await document.save();

  // Run SwiftLint --fix
  const result = await fixFile({
    filePath: document.uri.fsPath,
    cwd,
    configPath,
  });

  if (result.error) {
    vscode.window.showErrorMessage(`SwiftLint fix failed: ${result.error}`);
    return;
  }

  // Reload document to show changes
  const newDoc = await vscode.workspace.openTextDocument(document.uri);
  await vscode.window.showTextDocument(newDoc);

  // Re-lint to update diagnostics
  if (diagnosticProvider) {
    await diagnosticProvider.lintDocument(newDoc);
  }

  vscode.window.showInformationMessage('SwiftLint: Auto-fixes applied');
}

/**
 * Lint all Swift files in the workspace
 */
async function lintWorkspace(): Promise<void> {
  if (!diagnosticProvider) {
    return;
  }

  vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'SwiftLint: Linting workspace...',
      cancellable: false,
    },
    async () => {
      // Find all Swift files
      const files = await vscode.workspace.findFiles(
        '**/*.swift',
        '**/.build/**'
      );

      let linted = 0;
      for (const file of files) {
        try {
          const doc = await vscode.workspace.openTextDocument(file);
          await diagnosticProvider?.lintDocument(doc);
          linted++;
        } catch {
          // Skip files that can't be opened
        }
      }

      vscode.window.showInformationMessage(
        `SwiftLint: Linted ${linted} Swift files`
      );
    }
  );
}
