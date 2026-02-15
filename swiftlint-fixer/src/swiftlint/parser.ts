/**
 * SwiftLint JSON output parser
 */

/**
 * Represents a single SwiftLint violation
 */
export interface Violation {
  /** File path where the violation occurred */
  file: string;
  /** Line number (1-based) */
  line: number;
  /** Character/column position (1-based, null if not applicable) */
  character: number | null;
  /** Violation severity */
  severity: 'Warning' | 'Error';
  /** Human-readable rule name (e.g., "Line Length") */
  type: string;
  /** Machine-readable rule identifier (e.g., "line_length") */
  ruleId: string;
  /** Detailed description of the violation */
  reason: string;
}

/**
 * Raw JSON structure from SwiftLint --reporter json
 */
interface RawViolation {
  file: string;
  line: number;
  character: number | null;
  severity: string;
  type: string;
  rule_id: string;
  reason: string;
}

/**
 * Parse SwiftLint JSON output into typed Violation objects
 */
export function parseViolations(jsonOutput: string): Violation[] {
  if (!jsonOutput.trim()) {
    return [];
  }

  try {
    const raw: RawViolation[] = JSON.parse(jsonOutput);

    if (!Array.isArray(raw)) {
      return [];
    }

    return raw.map(mapRawViolation).filter(isValidViolation);
  } catch {
    return [];
  }
}

function mapRawViolation(raw: RawViolation): Violation {
  return {
    file: raw.file,
    line: raw.line,
    character: raw.character,
    severity: normalizeSeverity(raw.severity),
    type: raw.type,
    ruleId: raw.rule_id,
    reason: raw.reason,
  };
}

function normalizeSeverity(severity: string): 'Warning' | 'Error' {
  const normalized = severity.toLowerCase();
  if (normalized === 'error') {
    return 'Error';
  }
  return 'Warning';
}

function isValidViolation(violation: Violation): boolean {
  return (
    typeof violation.file === 'string' &&
    typeof violation.line === 'number' &&
    violation.line > 0 &&
    typeof violation.ruleId === 'string' &&
    violation.ruleId.length > 0
  );
}

/**
 * Group violations by file path
 */
export function groupByFile(violations: Violation[]): Map<string, Violation[]> {
  const grouped = new Map<string, Violation[]>();

  for (const violation of violations) {
    const existing = grouped.get(violation.file) ?? [];
    existing.push(violation);
    grouped.set(violation.file, existing);
  }

  return grouped;
}
