/**
 * Extension configuration settings
 */

import * as vscode from 'vscode';

/**
 * Extension settings interface
 */
export interface Settings {
  /** Enable/disable the extension */
  enable: boolean;
  /** Path to SwiftLint executable */
  path: string;
  /** Paths to search for SwiftLint configuration */
  configSearchPaths: string[];
  /** Lint on file save */
  lintOnSave: boolean;
  /** Lint on file open */
  lintOnOpen: boolean;
  /** Lint while typing */
  lintOnType: boolean;
}

const SECTION = 'swiftlintFixer';

/**
 * Get current extension settings
 */
export function getSettings(): Settings {
  const config = vscode.workspace.getConfiguration(SECTION);

  return {
    enable: config.get<boolean>('enable', true),
    path: config.get<string>('path', 'swiftlint'),
    configSearchPaths: config.get<string[]>('configSearchPaths', [
      '.swiftlint.yml',
      '.swiftlint.yaml',
    ]),
    lintOnSave: config.get<boolean>('lintOnSave', true),
    lintOnOpen: config.get<boolean>('lintOnOpen', true),
    lintOnType: config.get<boolean>('lintOnType', false),
  };
}

/**
 * Find SwiftLint config file in workspace
 */
export async function findConfigFile(
  workspaceFolder: vscode.WorkspaceFolder
): Promise<string | undefined> {
  const settings = getSettings();

  for (const searchPath of settings.configSearchPaths) {
    const pattern = new vscode.RelativePattern(workspaceFolder, searchPath);
    const files = await vscode.workspace.findFiles(pattern, null, 1);

    if (files.length > 0) {
      return files[0].fsPath;
    }
  }

  return undefined;
}
