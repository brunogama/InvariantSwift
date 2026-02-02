#!/usr/bin/env python3
"""
API Reference Generator for Swift Projects

Extracts public symbols from Swift source files and generates
comprehensive API reference documentation in Markdown format.

Features:
- Organizes by module/directory
- Extracts DocC comments
- Groups by symbol type (structs, enums, protocols, functions)
- Generates cross-reference links

Usage:
    python3 Scripts/generate_api_reference.py [--output FILE]
"""
import argparse
import os
import re
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Symbol:
    """Represents a public Swift symbol."""
    name: str
    symbol_type: str  # struct, class, enum, func, var, let, init, actor, protocol
    declaration: str
    file_path: str
    line_number: int
    doc_summary: str = ""
    doc_full: str = ""
    generic_params: list = field(default_factory=list)
    parameters: list = field(default_factory=list)
    return_type: str = ""


def extract_doc_comment(lines: list, end_index: int) -> tuple:
    """
    Extract DocC comment above a declaration.
    Returns (summary, full_doc)
    """
    doc_lines = []
    j = end_index - 1

    while j >= 0:
        stripped = lines[j].strip()
        if stripped.startswith("///"):
            doc_lines.insert(0, stripped[3:].strip())
            j -= 1
        elif stripped == "" or stripped.startswith("@"):
            j -= 1
        else:
            break

    if not doc_lines:
        return "", ""

    # First non-empty line is summary
    summary = ""
    for line in doc_lines:
        if line.strip():
            summary = line.strip()
            break

    full_doc = "\n".join(doc_lines)
    return summary, full_doc


def extract_generic_params(declaration: str) -> list:
    """Extract generic type parameters from declaration."""
    match = re.search(r"<([^>]+)>", declaration)
    if match:
        params = match.group(1).split(",")
        return [p.strip().split(":")[0].strip() for p in params]
    return []


def extract_func_signature(declaration: str) -> tuple:
    """Extract function parameters and return type."""
    params = []
    return_type = ""

    # Extract parameters
    paren_match = re.search(r"\(([^)]*)\)", declaration)
    if paren_match:
        params_str = paren_match.group(1)
        if params_str.strip():
            # Split by comma but respect nested generics
            depth = 0
            current = ""
            for char in params_str:
                if char in "<([":
                    depth += 1
                elif char in ">)]":
                    depth -= 1
                elif char == "," and depth == 0:
                    if current.strip():
                        params.append(current.strip())
                    current = ""
                    continue
                current += char
            if current.strip():
                params.append(current.strip())

    # Extract return type
    arrow_match = re.search(r"->\s*(.+)$", declaration)
    if arrow_match:
        return_type = arrow_match.group(1).strip()
        # Remove trailing braces if present
        return_type = re.sub(r"\s*\{.*$", "", return_type).strip()

    return params, return_type


def parse_swift_file(file_path: str) -> list:
    """Parse a Swift file and extract all public symbols."""
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    symbols = []

    # Pattern for public declarations
    public_pattern = re.compile(
        r"^(?:@\w+(?:\([^)]*\))?\s+)*"
        r"public\s+"
        r"(struct|class|enum|func|var|let|init|actor|protocol|extension|typealias)"
    )

    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        match = public_pattern.match(stripped)

        if match:
            symbol_type = match.group(1)

            # Handle multi-line declarations
            declaration = stripped
            brace_depth = declaration.count("{") - declaration.count("}")
            paren_depth = declaration.count("(") - declaration.count(")")

            # Continue reading if declaration spans multiple lines
            j = i + 1
            while j < len(lines) and (brace_depth > 0 or paren_depth > 0 or not declaration.rstrip().endswith(("{", "}"))):
                if "{" in lines[j]:
                    break
                declaration += " " + lines[j].strip()
                brace_depth += lines[j].count("{") - lines[j].count("}")
                paren_depth += lines[j].count("(") - lines[j].count(")")
                j += 1
                if brace_depth >= 0 and paren_depth <= 0:
                    break

            # Clean up declaration
            declaration = re.sub(r"\s+", " ", declaration)
            declaration = re.sub(r"\s*\{.*$", "", declaration)

            # Extract name
            name = "unknown"
            name_patterns = [
                (r"(?:struct|class|enum|actor|protocol)\s+(\w+)", 1),
                (r"func\s+(\w+)", 1),
                (r"(?:var|let)\s+(\w+)", 1),
                (r"typealias\s+(\w+)", 1),
                (r"extension\s+(\w+)", 1),
                (r"init\s*[\(<]", None),  # init
            ]

            for pattern, group in name_patterns:
                m = re.search(pattern, declaration)
                if m:
                    name = m.group(group) if group else "init"
                    break

            # Skip extensions (they're not really "symbols")
            if symbol_type == "extension":
                i += 1
                continue

            # Extract documentation
            doc_summary, doc_full = extract_doc_comment(lines, i)

            # Extract additional info
            generic_params = extract_generic_params(declaration)
            params, return_type = [], ""
            if symbol_type in ("func", "init"):
                params, return_type = extract_func_signature(declaration)

            symbol = Symbol(
                name=name,
                symbol_type=symbol_type,
                declaration=declaration[:200],
                file_path=file_path,
                line_number=i + 1,
                doc_summary=doc_summary,
                doc_full=doc_full,
                generic_params=generic_params,
                parameters=params,
                return_type=return_type,
            )
            symbols.append(symbol)

        i += 1

    return symbols


def group_symbols_by_module(symbols: list) -> dict:
    """Group symbols by their module (first-level directory under Sources)."""
    by_module = defaultdict(list)

    for symbol in symbols:
        # Extract module from path
        parts = Path(symbol.file_path).parts
        try:
            sources_idx = parts.index("Sources")
            if sources_idx + 1 < len(parts):
                module = parts[sources_idx + 1]
            else:
                module = "Unknown"
        except ValueError:
            module = "Unknown"

        by_module[module].append(symbol)

    return dict(by_module)


def render_symbol_table(symbols: list, symbol_type: str) -> str:
    """Render a table of symbols of a given type."""
    filtered = [s for s in symbols if s.symbol_type == symbol_type]
    if not filtered:
        return ""

    type_emoji = {
        "struct": "📦",
        "class": "🏛️",
        "enum": "🔢",
        "protocol": "📋",
        "actor": "🎭",
        "func": "⚡",
        "var": "📊",
        "let": "🔒",
        "typealias": "🏷️",
        "init": "🔨",
    }

    emoji = type_emoji.get(symbol_type, "📄")
    lines = [
        f"### {emoji} {symbol_type.title()}s",
        "",
        "| Name | Description |",
        "|------|-------------|",
    ]

    for s in sorted(filtered, key=lambda x: x.name):
        summary = s.doc_summary or "_No documentation_"
        # Truncate long summaries
        if len(summary) > 80:
            summary = summary[:77] + "..."
        lines.append(f"| `{s.name}` | {summary} |")

    lines.append("")
    return "\n".join(lines)


def render_detailed_section(symbols: list, symbol_type: str) -> str:
    """Render detailed documentation for symbols of a given type."""
    filtered = [s for s in symbols if s.symbol_type == symbol_type]
    if not filtered:
        return ""

    lines = []
    for s in sorted(filtered, key=lambda x: x.name):
        lines.append(f"#### `{s.name}`")
        lines.append("")

        if s.doc_summary:
            lines.append(f"_{s.doc_summary}_")
            lines.append("")

        # Show declaration
        lines.append("```swift")
        lines.append(s.declaration)
        lines.append("```")
        lines.append("")

        # Show file location
        lines.append(f"📁 `{s.file_path}:{s.line_number}`")
        lines.append("")

    return "\n".join(lines)


def generate_api_reference(symbols_by_module: dict) -> str:
    """Generate complete API reference document."""
    doc = [
        "# InvariantSwift API Reference",
        "",
        "_Auto-generated API documentation_",
        "",
        "## Table of Contents",
        "",
    ]

    # Generate TOC
    for module in sorted(symbols_by_module.keys()):
        doc.append(f"- [{module}](#{module.lower().replace(' ', '-')})")

    doc.extend(["", "---", ""])

    # Generate per-module sections
    for module in sorted(symbols_by_module.keys()):
        symbols = symbols_by_module[module]
        doc.append(f"## {module}")
        doc.append("")

        # Count by type
        type_counts = defaultdict(int)
        for s in symbols:
            type_counts[s.symbol_type] += 1

        count_str = ", ".join(f"{c} {t}s" for t, c in sorted(type_counts.items()))
        doc.append(f"_{count_str}_")
        doc.append("")

        # Render tables by type
        for symbol_type in ["protocol", "struct", "class", "enum", "actor", "func"]:
            table = render_symbol_table(symbols, symbol_type)
            if table:
                doc.append(table)

        doc.append("---")
        doc.append("")

    # Summary statistics
    total_symbols = sum(len(s) for s in symbols_by_module.values())
    doc.extend([
        "## Summary",
        "",
        f"**Total Public Symbols:** {total_symbols}",
        "",
        "| Module | Symbols |",
        "|--------|---------|",
    ])

    for module in sorted(symbols_by_module.keys()):
        doc.append(f"| {module} | {len(symbols_by_module[module])} |")

    doc.extend([
        "",
        "---",
        "",
        "_Generated by `Scripts/generate_api_reference.py`_",
    ])

    return "\n".join(doc)


def main():
    parser = argparse.ArgumentParser(
        description="Generate API reference from Swift sources"
    )
    parser.add_argument(
        "--output", "-o",
        default="docs/API_REFERENCE_GENERATED.md",
        help="Output file path",
    )
    parser.add_argument(
        "--sources",
        default="Sources",
        help="Source directory to scan",
    )
    args = parser.parse_args()

    print("🔍 Scanning Swift sources...")

    all_symbols = []
    file_count = 0

    for root, dirs, files in os.walk(args.sources):
        dirs[:] = [d for d in dirs if not d.startswith(".")]

        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                symbols = parse_swift_file(file_path)
                all_symbols.extend(symbols)
                file_count += 1

    print(f"   Scanned {file_count} files")
    print(f"   Found {len(all_symbols)} public symbols")

    # Group by module
    symbols_by_module = group_symbols_by_module(all_symbols)
    print(f"   Modules: {', '.join(sorted(symbols_by_module.keys()))}")

    # Generate documentation
    print("📝 Generating API reference...")
    doc = generate_api_reference(symbols_by_module)

    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(doc)

    print(f"✅ Generated: {output_path}")

    return 0


if __name__ == "__main__":
    exit(main())
