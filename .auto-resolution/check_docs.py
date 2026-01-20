#!/usr/bin/env python3
"""
Enhanced Swift Documentation Coverage Analyzer

Validates DocC documentation completeness for public Swift APIs.
Checks for:
- Summary line (first /// comment)
- Parameter documentation (- Parameters: or - Parameter X:)
- Return documentation (- Returns:)
- Throws documentation (- Throws:)
- Code examples (```swift blocks)

Usage:
    python3 check_docs.py [--json] [--threshold N] [--verbose]
"""
import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from typing import Optional


@dataclass
class DocElements:
    """Tracks which DocC elements are present in documentation."""
    has_summary: bool = False
    has_discussion: bool = False
    has_parameters: bool = False
    has_returns: bool = False
    has_throws: bool = False
    has_example: bool = False
    has_see_also: bool = False
    parameter_names: list = field(default_factory=list)
    raw_doc: str = ""


@dataclass
class SymbolInfo:
    """Information about a documented (or undocumented) symbol."""
    file_path: str
    line_number: int
    declaration: str
    symbol_name: str
    symbol_type: str  # struct, class, enum, func, var, let, init, actor, protocol
    has_docs: bool
    doc_elements: Optional[DocElements] = None
    expected_params: list = field(default_factory=list)
    has_return_type: bool = False
    is_throwing: bool = False

    def missing_elements(self) -> list:
        """Return list of missing required DocC elements."""
        missing = []
        if not self.doc_elements:
            return ["all documentation"]

        if not self.doc_elements.has_summary:
            missing.append("summary")

        # Check parameters for functions/methods
        if self.symbol_type in ("func", "init") and self.expected_params:
            if not self.doc_elements.has_parameters:
                missing.append(f"parameters ({', '.join(self.expected_params)})")

        # Check returns for functions with return type
        if self.has_return_type and not self.doc_elements.has_returns:
            missing.append("returns")

        # Check throws for throwing functions
        if self.is_throwing and not self.doc_elements.has_throws:
            missing.append("throws")

        # Code example is highly recommended
        if not self.doc_elements.has_example:
            missing.append("example")

        return missing


def extract_doc_elements(lines: list, end_index: int) -> Optional[DocElements]:
    """
    Extract DocC elements from documentation comments above a declaration.
    Returns None if no documentation found.
    """
    doc_lines = []
    j = end_index - 1

    # Collect all /// lines going backwards
    while j >= 0:
        stripped = lines[j].strip()
        if stripped.startswith("///"):
            doc_lines.insert(0, stripped[3:].strip())
            j -= 1
        elif stripped == "" or stripped.startswith("@"):
            # Skip empty lines and attributes
            j -= 1
        else:
            break

    if not doc_lines:
        return None

    raw_doc = "\n".join(doc_lines)
    elements = DocElements(raw_doc=raw_doc)

    # Check for summary (first non-empty line)
    for line in doc_lines:
        if line.strip():
            elements.has_summary = True
            break

    # Check for discussion (multiple paragraphs)
    paragraph_breaks = sum(1 for line in doc_lines if line.strip() == "")
    elements.has_discussion = paragraph_breaks >= 1 and len(doc_lines) > 3

    # Check for parameters
    param_pattern = re.compile(r"-\s*Parameter[s]?\s*:?", re.IGNORECASE)
    param_line_pattern = re.compile(r"-\s*(\w+)\s*:", re.IGNORECASE)
    for line in doc_lines:
        if param_pattern.search(line):
            elements.has_parameters = True
        match = param_line_pattern.match(line.strip())
        if match and "parameter" in line.lower():
            elements.parameter_names.append(match.group(1))

    # Check for returns
    if re.search(r"-\s*Returns?\s*:", raw_doc, re.IGNORECASE):
        elements.has_returns = True

    # Check for throws
    if re.search(r"-\s*Throws?\s*:", raw_doc, re.IGNORECASE):
        elements.has_throws = True

    # Check for code example (```swift block or indented code)
    if "```swift" in raw_doc.lower() or "```" in raw_doc:
        elements.has_example = True

    # Check for See Also
    if re.search(r"-\s*See\s+Also\s*:", raw_doc, re.IGNORECASE):
        elements.has_see_also = True

    return elements


def extract_function_info(declaration: str) -> tuple:
    """
    Extract parameter names, return type presence, and throws from function declaration.
    Returns (param_names, has_return_type, is_throwing)
    """
    params = []
    has_return = False
    is_throwing = False

    # Extract parameters from parentheses
    paren_match = re.search(r"\(([^)]*)\)", declaration)
    if paren_match:
        params_str = paren_match.group(1)
        # Match parameter patterns: name: Type or _ name: Type
        param_pattern = re.compile(r"(?:_\s+)?(\w+)\s*:")
        params = param_pattern.findall(params_str)

    # Check for return type (-> something)
    if re.search(r"->\s*\S", declaration):
        has_return = True

    # Check for throws/async throws
    if re.search(r"\bthrows\b", declaration):
        is_throwing = True

    return params, has_return, is_throwing


def extract_symbol_name(declaration: str) -> str:
    """Extract the symbol name from a declaration."""
    # Match common patterns
    patterns = [
        r"(?:public\s+)?(?:struct|class|enum|actor|protocol)\s+(\w+)",
        r"(?:public\s+)?func\s+(\w+)",
        r"(?:public\s+)?(?:var|let)\s+(\w+)",
        r"(?:public\s+)?init\s*\(",
    ]

    for pattern in patterns:
        match = re.search(pattern, declaration)
        if match:
            return match.group(1) if match.lastindex else "init"

    return "unknown"


def check_documentation(file_path: str) -> list:
    """
    Analyze a Swift file for documentation coverage.
    Returns list of SymbolInfo for each public symbol.
    """
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    symbols = []

    # Pattern to match public declarations
    public_pattern = re.compile(
        r"^(?:@\w+(?:\([^)]*\))?\s+)*"  # Optional attributes
        r"public\s+"
        r"(struct|class|enum|func|var|let|init|actor|protocol)"
    )

    for i, line in enumerate(lines):
        stripped = line.strip()

        match = public_pattern.match(stripped)
        if match:
            symbol_type = match.group(1)
            symbol_name = extract_symbol_name(stripped)

            # Extract function-specific info
            expected_params, has_return, is_throwing = [], False, False
            if symbol_type in ("func", "init"):
                expected_params, has_return, is_throwing = extract_function_info(stripped)

            # Check for documentation
            doc_elements = extract_doc_elements(lines, i)

            symbol = SymbolInfo(
                file_path=file_path,
                line_number=i + 1,
                declaration=stripped[:100] + ("..." if len(stripped) > 100 else ""),
                symbol_name=symbol_name,
                symbol_type=symbol_type,
                has_docs=doc_elements is not None,
                doc_elements=doc_elements,
                expected_params=expected_params,
                has_return_type=has_return,
                is_throwing=is_throwing,
            )
            symbols.append(symbol)

    return symbols


def generate_report(all_symbols: list, verbose: bool = False) -> dict:
    """Generate a comprehensive documentation coverage report."""
    total = len(all_symbols)
    documented = sum(1 for s in all_symbols if s.has_docs)
    with_examples = sum(
        1 for s in all_symbols if s.doc_elements and s.doc_elements.has_example
    )

    by_type = {}
    for s in all_symbols:
        if s.symbol_type not in by_type:
            by_type[s.symbol_type] = {"total": 0, "documented": 0}
        by_type[s.symbol_type]["total"] += 1
        if s.has_docs:
            by_type[s.symbol_type]["documented"] += 1

    undocumented = [s for s in all_symbols if not s.has_docs]
    incomplete = [s for s in all_symbols if s.has_docs and s.missing_elements()]

    report = {
        "summary": {
            "total_symbols": total,
            "documented_symbols": documented,
            "coverage_percent": round(documented / total * 100, 1) if total > 0 else 100,
            "with_examples": with_examples,
            "example_coverage_percent": (
                round(with_examples / total * 100, 1) if total > 0 else 100
            ),
        },
        "by_type": by_type,
        "undocumented": [
            {
                "file": s.file_path,
                "line": s.line_number,
                "symbol": s.symbol_name,
                "type": s.symbol_type,
            }
            for s in undocumented
        ],
        "incomplete": [
            {
                "file": s.file_path,
                "line": s.line_number,
                "symbol": s.symbol_name,
                "type": s.symbol_type,
                "missing": s.missing_elements(),
            }
            for s in incomplete
        ],
    }

    return report


def print_human_report(report: dict, verbose: bool = False):
    """Print human-readable documentation coverage report."""
    summary = report["summary"]

    print("\n" + "=" * 60)
    print("📚 DOCUMENTATION COVERAGE REPORT")
    print("=" * 60)

    # Coverage bar
    coverage = summary["coverage_percent"]
    bar_width = 30
    filled = int(bar_width * coverage / 100)
    bar = "█" * filled + "░" * (bar_width - filled)
    emoji = "✅" if coverage >= 90 else "⚠️" if coverage >= 70 else "❌"

    print(f"\n{emoji} Overall Coverage: {bar} {coverage}%")
    print(f"   Documented: {summary['documented_symbols']}/{summary['total_symbols']} symbols")
    print(f"   With Examples: {summary['with_examples']} ({summary['example_coverage_percent']}%)")

    # By type breakdown
    print("\n📊 Coverage by Type:")
    for symbol_type, stats in report["by_type"].items():
        pct = round(stats["documented"] / stats["total"] * 100, 1) if stats["total"] > 0 else 100
        print(f"   {symbol_type:12} {stats['documented']:3}/{stats['total']:<3} ({pct}%)")

    # Undocumented symbols
    if report["undocumented"]:
        print(f"\n❌ Undocumented Symbols ({len(report['undocumented'])}):")
        for item in report["undocumented"][:10]:  # Limit output
            print(f"   {item['file']}:{item['line']} - {item['type']} {item['symbol']}")
        if len(report["undocumented"]) > 10:
            print(f"   ... and {len(report['undocumented']) - 10} more")

    # Incomplete documentation
    if verbose and report["incomplete"]:
        print(f"\n⚠️  Incomplete Documentation ({len(report['incomplete'])}):")
        for item in report["incomplete"][:10]:
            missing = ", ".join(item["missing"])
            print(f"   {item['file']}:{item['line']} - {item['symbol']}")
            print(f"      Missing: {missing}")
        if len(report["incomplete"]) > 10:
            print(f"   ... and {len(report['incomplete']) - 10} more")

    print("\n" + "=" * 60)


def main():
    parser = argparse.ArgumentParser(
        description="Analyze Swift documentation coverage"
    )
    parser.add_argument(
        "--json", action="store_true", help="Output report as JSON"
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=0,
        help="Minimum coverage percentage (exit 1 if below)",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Show incomplete documentation details"
    )
    parser.add_argument(
        "--output", "-o", type=str, help="Write JSON report to file"
    )
    args = parser.parse_args()

    all_symbols = []

    for root, dirs, files in os.walk("Sources"):
        # Skip hidden directories
        dirs[:] = [d for d in dirs if not d.startswith(".")]

        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                symbols = check_documentation(file_path)
                all_symbols.extend(symbols)

    report = generate_report(all_symbols, verbose=args.verbose)

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_human_report(report, verbose=args.verbose)

    # Write to file if requested
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        if not args.json:
            print(f"\n📝 Report written to: {args.output}")

    # Check threshold
    coverage = report["summary"]["coverage_percent"]
    if args.threshold > 0 and coverage < args.threshold:
        print(f"\n❌ Coverage {coverage}% is below threshold {args.threshold}%")
        sys.exit(1)

    # Exit with error if any undocumented symbols (backward compatibility)
    if report["undocumented"] and args.threshold == 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
