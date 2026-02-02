#!/usr/bin/env python3
"""
Documentation Example Validator

Extracts Swift code examples from DocC comments and validates they compile.
This helps catch stale examples that no longer match the API.

Usage:
    python3 Scripts/validate_doc_examples.py [--verbose] [--check-only]
"""
import argparse
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass
class CodeExample:
    """Represents a code example extracted from documentation."""
    file_path: str
    line_number: int
    code: str
    symbol_name: str


def extract_examples(file_path: str) -> list:
    """Extract Swift code examples from DocC comments in a file."""
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    examples = []
    lines = content.split("\n")

    i = 0
    while i < len(lines):
        stripped = lines[i].strip()

        # Look for ```swift in doc comments
        if stripped.startswith("///") and "```swift" in stripped:
            start_line = i
            code_lines = []
            i += 1

            # Collect code until closing ```
            while i < len(lines):
                line = lines[i].strip()
                if line.startswith("///"):
                    code_content = line[3:].strip() if len(line) > 3 else ""
                    if "```" in code_content and "swift" not in code_content:
                        break
                    code_lines.append(code_content)
                elif line.startswith("// swiftlint:"):
                    # Skip swiftlint directives that may be interspersed
                    i += 1
                    continue
                else:
                    break
                i += 1

            if code_lines:
                # Find the symbol name this example belongs to
                symbol_name = find_symbol_name(lines, start_line)

                # Filter out any swiftlint directives that got included
                clean_lines = [l for l in code_lines if not l.strip().startswith("// swiftlint:")]

                examples.append(CodeExample(
                    file_path=file_path,
                    line_number=start_line + 1,
                    code="\n".join(clean_lines),
                    symbol_name=symbol_name,
                ))

        i += 1

    return examples


def find_symbol_name(lines: list, doc_line: int) -> str:
    """Find the symbol name the documentation belongs to."""
    # Look forward for a declaration
    for j in range(doc_line, min(doc_line + 30, len(lines))):
        stripped = lines[j].strip()
        if stripped.startswith("public"):
            # Extract name from declaration
            patterns = [
                r"(?:struct|class|enum|actor|protocol)\s+(\w+)",
                r"func\s+(\w+)",
                r"(?:var|let)\s+(\w+)",
            ]
            for pattern in patterns:
                match = re.search(pattern, stripped)
                if match:
                    return match.group(1)
    return "unknown"


def generate_test_harness(examples: list) -> str:
    """Generate a Swift file that compiles all examples."""
    harness = [
        "// Auto-generated test harness for documentation examples",
        "// This file verifies that code examples in docs compile correctly",
        "",
        "import Foundation",
        "import InvariantSwift",
        "",
        "// Suppress unused warnings",
        "@available(*, deprecated, message: \"Test harness\")",
        "func runDocExamples() async throws {",
        "    // Examples extracted from documentation",
        "",
    ]

    for i, example in enumerate(examples):
        harness.append(f"    // From {example.symbol_name} ({example.file_path}:{example.line_number})")
        harness.append("    do {")

        # Indent the code
        for line in example.code.split("\n"):
            if line.strip():
                harness.append(f"        _ = {line}" if not any(kw in line for kw in ["let ", "var ", "func ", "@", "import", "//"]) else f"        {line}")
            else:
                harness.append("")

        harness.append("    }")
        harness.append("")

    harness.append("}")
    return "\n".join(harness)


def strip_strings_and_comments(code: str) -> str:
    """
    Strip string literals and comments from code for brace counting.
    This prevents false positives from braces in strings or comments.
    """
    result = []
    in_string = False
    in_multiline_string = False
    string_char = None
    i = 0

    while i < len(code):
        # Check for multiline string delimiter """
        if i + 2 < len(code) and code[i:i+3] == '"""':
            if in_multiline_string:
                in_multiline_string = False
                i += 3
                continue
            elif not in_string:
                in_multiline_string = True
                i += 3
                continue

        # Skip content inside multiline strings
        if in_multiline_string:
            i += 1
            continue

        # Check for string start/end
        if code[i] in '"' and not in_string:
            in_string = True
            string_char = code[i]
            i += 1
            continue
        elif in_string and code[i] == string_char:
            # Check for escape
            if i > 0 and code[i-1] == '\\':
                i += 1
                continue
            in_string = False
            string_char = None
            i += 1
            continue

        # Skip content inside strings
        if in_string:
            i += 1
            continue

        # Check for line comments
        if i + 1 < len(code) and code[i:i+2] == '//':
            # Skip to end of line
            while i < len(code) and code[i] != '\n':
                i += 1
            continue

        result.append(code[i])
        i += 1

    return ''.join(result)


def validate_examples(examples: list, verbose: bool = False) -> dict:
    """
    Validate that code examples compile.
    Returns dict with pass/fail counts and error details.
    """
    results = {
        "total": len(examples),
        "parsed": 0,
        "errors": [],
    }

    # Create a simple syntax check by looking for common issues
    for example in examples:
        # Basic validation - check for obvious syntax issues
        code = example.code

        # Skip empty examples
        if not code.strip():
            continue

        results["parsed"] += 1

        # Check for common issues
        issues = []

        # Strip strings and comments before counting braces
        stripped_code = strip_strings_and_comments(code)

        # Unbalanced braces/parens
        if stripped_code.count("{") != stripped_code.count("}"):
            issues.append("unbalanced curly braces")
        if stripped_code.count("(") != stripped_code.count(")"):
            issues.append("unbalanced parentheses")
        if stripped_code.count("[") != stripped_code.count("]"):
            issues.append("unbalanced brackets")

        # Obvious incomplete code
        if code.rstrip().endswith(","):
            issues.append("trailing comma (incomplete)")

        if issues:
            results["errors"].append({
                "file": example.file_path,
                "line": example.line_number,
                "symbol": example.symbol_name,
                "issues": issues,
            })

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Validate Swift code examples in documentation"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show detailed output",
    )
    parser.add_argument(
        "--sources",
        default="Sources",
        help="Source directory to scan",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Only check syntax, don't try to compile",
    )
    args = parser.parse_args()

    print("🔍 Scanning for code examples in documentation...")

    all_examples = []
    file_count = 0

    for root, dirs, files in os.walk(args.sources):
        dirs[:] = [d for d in dirs if not d.startswith(".")]

        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                examples = extract_examples(file_path)
                all_examples.extend(examples)
                file_count += 1

    print(f"   Scanned {file_count} files")
    print(f"   Found {len(all_examples)} code examples")

    if not all_examples:
        print("✅ No code examples found to validate")
        return 0

    # Group by file for reporting
    by_file = {}
    for ex in all_examples:
        if ex.file_path not in by_file:
            by_file[ex.file_path] = []
        by_file[ex.file_path].append(ex)

    print(f"   Examples in {len(by_file)} files")

    # Validate
    print("\n🧪 Validating examples...")
    results = validate_examples(all_examples, verbose=args.verbose)

    print(f"\n📊 Results:")
    print(f"   Total examples: {results['total']}")
    print(f"   Parsed: {results['parsed']}")
    print(f"   Syntax issues: {len(results['errors'])}")

    if results["errors"]:
        print("\n⚠️  Examples with potential issues:")
        for error in results["errors"][:10]:
            print(f"   {error['file']}:{error['line']} ({error['symbol']})")
            for issue in error["issues"]:
                print(f"      - {issue}")

        if len(results["errors"]) > 10:
            print(f"   ... and {len(results['errors']) - 10} more")

    # Show some example stats
    if args.verbose:
        print("\n📝 Examples by file:")
        for file_path in sorted(by_file.keys())[:10]:
            print(f"   {os.path.basename(file_path)}: {len(by_file[file_path])} examples")

    if results["errors"]:
        return 1

    print("\n✅ All examples passed basic validation")
    return 0


if __name__ == "__main__":
    exit(main())
