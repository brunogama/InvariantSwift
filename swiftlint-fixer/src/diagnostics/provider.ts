/**
 * Diagnostic collection provider
 */

import * as vscode from 'vscode';
import { lintFile } from '../swiftlint/runner';
import { violationsToDiagnostics, DIAGNOSTIC_SOURCE } from './converter';
import { getSettings, findConfigFile } from '../config/settings';

/**
 * Manages SwiftLint diagnostics for all documents
 */
export class DiagnosticProvider implements vscode.Disposable {
  private diagnosticCollection: vscode.DiagnosticCollection;
  private disposables: vscode.Disposable[] = [];
  private documentVersions = new Map<string, number>();
  private debounceTimers = new Map<string, NodeJS.Timeout>();

  constructor() {
    this.diagnosticCollection = vscode.languages.createDiagnosticCollection(
      DIAGNOSTIC_SOURCE
    );
    this.disposables.push(this.diagnosticCollection);

    this.registerListeners();
  }

  private registerListeners(): void {
    const settings = getSettings();

    // Lint on document open
    if (settings.lintOnOpen) {
      this.disposables.push(
        vscode.workspace.onDidOpenTextDocument((doc) => {
          if (this.isSwiftDocument(doc)) {
            this.lintDocument(doc);
          }
        })
      );
    }

    // Lint on document save
    if (settings.lintOnSave) {
      this.disposables.push(
        vscode.workspace.onDidSaveTextDocument((doc) => {
          if (this.isSwiftDocument(doc)) {
            this.lintDocument(doc);
          }
        })
      );
    }

    // Lint on document change (debounced)
    if (settings.lintOnType) {
      this.disposables.push(
        vscode.workspace.onDidChangeTextDocument((event) => {
          if (this.isSwiftDocument(event.document)) {
            this.debouncedLint(event.document);
          }
        })
      );
    }

    // Clear diagnostics when document is closed
    this.disposables.push(
      vscode.workspace.onDidCloseTextDocument((doc) => {
        this.diagnosticCollection.delete(doc.uri);
        this.documentVersions.delete(doc.uri.toString());
      })
    );

    // Re-lint when configuration changes
    this.disposables.push(
      vscode.workspace.onDidChangeConfiguration((event) => {
        if (event.affectsConfiguration('swiftlintFixer')) {
          this.lintAllOpenDocuments();
        }
      })
    );
  }

  /**
   * Lint a single document
   */
  async lintDocument(document: vscode.TextDocument): Promise<void> {
    const settings = getSettings();
    if (!settings.enable) {
      return;
    }

    // Skip if document hasn't changed
    const key = document.uri.toString();
    const lastVersion = this.documentVersions.get(key);
    if (lastVersion !== undefined && lastVersion >= document.version) {
      return;
    }
    this.documentVersions.set(key, document.version);

    // Get workspace folder for config resolution
    const workspaceFolder = vscode.workspace.getWorkspaceFolder(document.uri);
    const cwd = workspaceFolder?.uri.fsPath ?? require('path').dirname(document.uri.fsPath);

    // Find config file
    const configPath = workspaceFolder
      ? await findConfigFile(workspaceFolder)
      : undefined;

    // Run SwiftLint
    const result = await lintFile({
      filePath: document.uri.fsPath,
      cwd,
      configPath,
    });

    // Handle errors
    if (result.error) {
      vscode.window.showWarningMessage(`SwiftLint: ${result.error}`);
      return;
    }

    // Convert to diagnostics
    const diagnostics = violationsToDiagnostics(result.violations, document);
    this.diagnosticCollection.set(document.uri, diagnostics);
  }

  /**
   * Debounced lint for typing events
   */
  private debouncedLint(document: vscode.TextDocument): void {
    const key = document.uri.toString();

    // Clear existing timer
    const existingTimer = this.debounceTimers.get(key);
    if (existingTimer) {
      clearTimeout(existingTimer);
    }

    // Set new timer (500ms debounce)
    const timer = setTimeout(() => {
      this.debounceTimers.delete(key);
      this.lintDocument(document);
    }, 500);

    this.debounceTimers.set(key, timer);
  }

  /**
   * Lint all currently open Swift documents
   */
  async lintAllOpenDocuments(): Promise<void> {
    const documents = vscode.workspace.textDocuments.filter((doc) =>
      this.isSwiftDocument(doc)
    );

    for (const doc of documents) {
      await this.lintDocument(doc);
    }
  }

  /**
   * Clear all diagnostics
   */
  clearAll(): void {
    this.diagnosticCollection.clear();
    this.documentVersions.clear();
  }

  /**
   * Get diagnostics for a document
   */
  getDiagnostics(uri: vscode.Uri): readonly vscode.Diagnostic[] {
    return this.diagnosticCollection.get(uri) ?? [];
  }

  private isSwiftDocument(document: vscode.TextDocument): boolean {
    return document.languageId === 'swift';
  }

  dispose(): void {
    // Clear debounce timers
    for (const timer of this.debounceTimers.values()) {
      clearTimeout(timer);
    }
    this.debounceTimers.clear();

    // Dispose all subscriptions
    for (const disposable of this.disposables) {
      disposable.dispose();
    }
    this.disposables = [];
  }
}
