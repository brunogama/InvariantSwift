/**
 * SwiftLint CLI runner
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import { parseViolations, Violation } from './parser';
import { getSettings } from '../config/settings';

const execAsync = promisify(exec);

/**
 * Result of running SwiftLint
 */
export interface LintResult {
  /** Parsed violations */
  violations: Violation[];
  /** Error message if SwiftLint failed */
  error?: string;
}

/**
 * Options for running SwiftLint
 */
interface RunOptions {
  /** File path to lint */
  filePath: string;
  /** Working directory */
  cwd: string;
  /** Optional config file path */
  configPath?: string;
}

/**
 * Run SwiftLint on a single file and return parsed violations
 */
export async function lintFile(options: RunOptions): Promise<LintResult> {
  const settings = getSettings();

  if (!settings.enable) {
    return { violations: [] };
  }

  const args = buildArgs(options);
  const command = `${settings.path} ${args.join(' ')}`;

  try {
    const { stdout } = await execAsync(command, {
      cwd: options.cwd,
      maxBuffer: 20 * 1024 * 1024, // 20MB buffer
      timeout: 60000, // 60 second timeout
    });

    const violations = parseViolations(stdout);
    return { violations };
  } catch (error: unknown) {
    // SwiftLint exits with code 2 when violations are found
    // This is expected behavior, not an error
    if (isExecError(error) && error.code === 2 && error.stdout) {
      const violations = parseViolations(error.stdout);
      return { violations };
    }

    // Handle actual errors
    if (isExecError(error)) {
      if (error.code === 'ENOENT' || error.code === 127) {
        return {
          violations: [],
          error: `SwiftLint not found at '${settings.path}'. Please install SwiftLint or configure the path.`,
        };
      }

      return {
        violations: [],
        error: error.message,
      };
    }

    return {
      violations: [],
      error: 'Unknown error running SwiftLint',
    };
  }
}

/**
 * Run SwiftLint --fix on a file
 */
export async function fixFile(options: RunOptions): Promise<LintResult> {
  const settings = getSettings();

  if (!settings.enable) {
    return { violations: [] };
  }

  const args = [...buildArgs(options), '--fix'];
  const command = `${settings.path} ${args.join(' ')}`;

  try {
    await execAsync(command, {
      cwd: options.cwd,
      maxBuffer: 20 * 1024 * 1024,
      timeout: 60000,
    });

    return { violations: [] };
  } catch (error: unknown) {
    if (isExecError(error)) {
      return {
        violations: [],
        error: error.message,
      };
    }

    return {
      violations: [],
      error: 'Unknown error running SwiftLint --fix',
    };
  }
}

function buildArgs(options: RunOptions): string[] {
  const args = ['lint', '--reporter', 'json', '--quiet'];

  // Add config path if specified
  if (options.configPath) {
    args.push('--config', options.configPath);
  }

  // Add file path
  args.push('--path', `"${options.filePath}"`);

  return args;
}

interface ExecError extends Error {
  code?: number | string;
  stdout?: string;
  stderr?: string;
}

function isExecError(error: unknown): error is ExecError {
  return error instanceof Error;
}
