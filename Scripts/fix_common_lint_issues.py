#!/usr/bin/env python3
"""
Batch Lint Fixer for Swift Projects using SwiftLint
Generates automatic fixes for common lint violations.

Usage:
    python3 fix_common_lint_issues.py [--dry-run] [--path PATH]
"""

import subprocess
import json
import re
import sys
import argparse
from pathlib import Path
from typing import NamedTuple, Optional
from collections import defaultdict


class LintViolation(NamedTuple):
    """Represents a single lint violation."""
    file: str
    line: int
    column: int
    rule: str
    severity: str
    message: str


def run_swiftlint_json(path: str = ".") -> list[LintViolation]:
    """Run SwiftLint and parse JSON output."""
    try:
        result = subprocess.run(
            ["swiftlint", "lint", "--reporter", "json", path],
            capture_output=True,
            text=True,
            cwd=path
        )
        violations = json.loads(result.stdout) if result.stdout.strip() else []
        return [
            LintViolation(
                file=v.get("file", ""),
                line=v.get("line", 0),
                column=v.get("column", 0),
                rule=v.get("rule_id", ""),
                severity=v.get("severity", ""),
                message=v.get("reason", "")
            )
            for v in violations
        ]
    except Exception as e:
        print(f"Error running SwiftLint: {e}")
        return []


def fix_redundant_string_enum_value(content: str, line_num: int) -> tuple[str, bool]:
    """
    Fix redundant_string_enum_value violations.
    Example: case foo = "foo" -> case foo
    """
    lines = content.split('\n')
    if line_num <= 0 or line_num > len(lines):
        return content, False
    
    line = lines[line_num - 1]
    # Pattern: case identifier = "identifier"
    pattern = r'(\s*case\s+)(\w+)\s*=\s*"(\2)"'
    match = re.search(pattern, line)
    if match:
        new_line = re.sub(pattern, r'\1\2', line)
        lines[line_num - 1] = new_line
        return '\n'.join(lines), True
    return content, False


def fix_identifier_name_underscore(content: str, line_num: int, identifier: str) -> tuple[str, bool]:
    """
    Fix identifier_name violations for snake_case -> camelCase.
    Example: case some_thing -> case someThing
    """
    lines = content.split('\n')
    if line_num <= 0 or line_num > len(lines):
        return content, False
    
    line = lines[line_num - 1]
    
    # Convert snake_case to camelCase
    def to_camel_case(snake_str: str) -> str:
        components = snake_str.split('_')
        return components[0] + ''.join(x.title() for x in components[1:])
    
    if '_' in identifier:
        camel_case = to_camel_case(identifier)
        # Only fix in case declarations, keep raw value for enums
        if f'case {identifier}' in line:
            # For enums, preserve the raw value
            if '=' not in line:
                new_line = line.replace(f'case {identifier}', f'case {camel_case} = "{identifier}"')
            else:
                new_line = line.replace(f'case {identifier}', f'case {camel_case}')
            lines[line_num - 1] = new_line
            return '\n'.join(lines), True
    
    return content, False


def add_swiftlint_disable_next(content: str, line_num: int, rule: str) -> tuple[str, bool]:
    """Add swiftlint:disable:next comment for a specific line and rule."""
    lines = content.split('\n')
    if line_num <= 0 or line_num > len(lines):
        return content, False
    
    # Insert disable:next comment before the violating line
    insert_index = line_num - 1
    
    # Get indentation from the violating line
    violating_line = lines[insert_index]
    indent = len(violating_line) - len(violating_line.lstrip())
    indent_str = ' ' * indent
    
    disable_comment = f"{indent_str}// swiftlint:disable:next {rule}"
    
    # Check if already disabled
    if insert_index > 0:
        prev_line = lines[insert_index - 1].strip()
        if f"swiftlint:disable:next {rule}" in prev_line or "swiftlint:disable:next" in prev_line:
            return content, False
    
    lines.insert(insert_index, disable_comment)
    return '\n'.join(lines), True


def fix_contains_over_filter_is_empty(content: str, line_num: int) -> tuple[str, bool]:
    """
    Fix contains_over_filter_is_empty violations.
    Example: arr.filter { ... }.isEmpty -> !arr.contains { ... }
    """
    lines = content.split('\n')
    if line_num <= 0 or line_num > len(lines):
        return content, False
    
    line = lines[line_num - 1]
    # Pattern: .filter { ... }.isEmpty
    pattern = r'(\w+)\.filter\s*\{([^}]+)\}\.isEmpty'
    match = re.search(pattern, line)
    if match:
        var_name = match.group(1)
        predicate = match.group(2).strip()
        new_expr = f'!{var_name}.contains {{ {predicate} }}'
        new_line = re.sub(pattern, new_expr, line)
        lines[line_num - 1] = new_line
        return '\n'.join(lines), True
    return content, False


def process_violations(violations: list[LintViolation], dry_run: bool = True) -> dict:
    """Process violations and optionally apply fixes."""
    fixes_by_file: dict[str, list[tuple[int, str, callable]]] = defaultdict(list)
    stats = defaultdict(int)
    
    # Rules we can auto-fix
    fixable_rules = {
        'redundant_string_enum_value',
        'contains_over_filter_is_empty',
    }
    
    # Rules we disable at file level (structural issues)
    disable_rules = {
        'file_length',
        'type_body_length', 
        'function_body_length',
        'cyclomatic_complexity',
        'no_print',
        'large_tuple',
        'for_where',
        'multiline_function_chains',
        'orphaned_doc_comment',
        'closure_parameter_position',
        'static_operator',
        'function_parameter_count',
        'line_length',
        'identifier_name',
        'unused_enumerated',
    }
    
    # Group violations by file
    violations_by_file: dict[str, list[LintViolation]] = defaultdict(list)
    for v in violations:
        violations_by_file[v.file].append(v)
    
    changes = []
    
    for file_path, file_violations in violations_by_file.items():
        if not Path(file_path).exists():
            continue
            
        content = Path(file_path).read_text()
        original_content = content
        modified = False
        
        # Track line offset as we insert comments
        line_offset = 0
        
        for v in sorted(file_violations, key=lambda x: x.line):  # Process from top to bottom
            stats[v.rule] += 1
            adjusted_line = v.line + line_offset
            
            if v.rule in disable_rules:
                content, disabled = add_swiftlint_disable_next(content, adjusted_line, v.rule)
                if disabled:
                    modified = True
                    line_offset += 1  # We added a line
                    changes.append(f"  [DISABLE:NEXT] {v.file}:{v.line} - {v.rule}")
                
            elif v.rule == 'redundant_string_enum_value':
                content, fixed = fix_redundant_string_enum_value(content, adjusted_line)
                if fixed:
                    modified = True
                    changes.append(f"  [FIX] {v.file}:{v.line} - {v.rule}")
                    
            elif v.rule == 'contains_over_filter_is_empty':
                content, fixed = fix_contains_over_filter_is_empty(content, adjusted_line)
                if fixed:
                    modified = True
                    changes.append(f"  [FIX] {v.file}:{v.line} - {v.rule}")
        
        if modified and not dry_run:
            Path(file_path).write_text(content)
    
    return {
        'stats': dict(stats),
        'changes': changes,
        'total_violations': len(violations),
        'fixable_count': sum(1 for v in violations if v.rule in fixable_rules),
        'disable_count': sum(1 for v in violations if v.rule in disable_rules),
    }


def main():
    parser = argparse.ArgumentParser(description='Batch fix common SwiftLint violations')
    parser.add_argument('--dry-run', action='store_true', default=True,
                        help='Show what would be changed without making changes (default: True)')
    parser.add_argument('--apply', action='store_true',
                        help='Actually apply the changes')
    parser.add_argument('--path', default='.',
                        help='Path to Swift project')
    args = parser.parse_args()
    
    dry_run = not args.apply
    
    print(f"{'[DRY RUN] ' if dry_run else ''}Analyzing SwiftLint violations...")
    print(f"Path: {args.path}\n")
    
    violations = run_swiftlint_json(args.path)
    
    if not violations:
        print("No violations found or SwiftLint not available.")
        return
    
    result = process_violations(violations, dry_run=dry_run)
    
    print("=" * 60)
    print("VIOLATION SUMMARY BY RULE:")
    print("=" * 60)
    for rule, count in sorted(result['stats'].items(), key=lambda x: -x[1]):
        print(f"  {rule}: {count}")
    
    print(f"\nTotal violations: {result['total_violations']}")
    print(f"Auto-fixable: {result['fixable_count']}")
    print(f"Will add disable comments: {result['disable_count']}")
    
    if result['changes']:
        print("\n" + "=" * 60)
        print("CHANGES " + ("(TO BE APPLIED):" if dry_run else "(APPLIED):"))
        print("=" * 60)
        for change in result['changes'][:50]:  # Limit output
            print(change)
        if len(result['changes']) > 50:
            print(f"  ... and {len(result['changes']) - 50} more changes")
    
    if dry_run:
        print("\n[DRY RUN] No changes made. Run with --apply to apply changes.")


if __name__ == '__main__':
    main()
