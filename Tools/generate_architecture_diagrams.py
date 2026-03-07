#!/usr/bin/env python3
"""
Architecture Diagram Generator for Swift Projects

Parses Package.swift and source files to generate Mermaid diagrams:
1. Package structure (targets and products)
2. Module dependencies (target dependencies)
3. Import graph (Swift import statements)

Usage:
    python3 Scripts/generate_architecture_diagrams.py [--output-dir DIR]
"""
import argparse
import os
import re
from pathlib import Path
from dataclasses import dataclass, field


@dataclass
class Target:
    """Represents a Swift package target."""
    name: str
    target_type: str  # target, macro, executableTarget, testTarget, plugin
    dependencies: list = field(default_factory=list)
    path: str = ""


@dataclass
class Product:
    """Represents a Swift package product."""
    name: str
    product_type: str  # library, executable, plugin
    targets: list = field(default_factory=list)


def parse_package_swift(package_path: str) -> tuple:
    """
    Parse Package.swift to extract targets, products, and dependencies.
    Returns (targets, products, external_deps)
    """
    with open(package_path, "r", encoding="utf-8") as f:
        content = f.read()

    targets = []
    products = []
    external_deps = []

    # Extract external package dependencies
    ext_pattern = re.compile(
        r'\.package\s*\(\s*url:\s*"([^"]+)"',
        re.MULTILINE
    )
    for match in ext_pattern.finditer(content):
        url = match.group(1)
        # Extract package name from URL
        name = url.rstrip("/").split("/")[-1].replace(".git", "")
        external_deps.append(name)

    # Extract products
    prod_pattern = re.compile(
        r"\.(library|executable|plugin)\s*\(\s*name:\s*\"(\w+)\"(?:.*?targets:\s*\[([^\]]*)\])?",
        re.DOTALL
    )
    for match in prod_pattern.finditer(content):
        prod_type = match.group(1)
        name = match.group(2)
        targets_str = match.group(3) or ""
        prod_targets = re.findall(r'"(\w+)"', targets_str)
        products.append(Product(name=name, product_type=prod_type, targets=prod_targets))

    # Extract targets
    target_pattern = re.compile(
        r"\.(target|macro|executableTarget|testTarget|plugin)\s*\(\s*"
        r"name:\s*\"(\w+)\"[^)]*?"
        r"(?:dependencies:\s*\[([^\]]*)\])?"
        r"[^)]*?"
        r"(?:path:\s*\"([^\"]+)\")?",
        re.DOTALL
    )

    for match in target_pattern.finditer(content):
        target_type = match.group(1)
        name = match.group(2)
        deps_str = match.group(3) or ""
        path = match.group(4) or ""

        # Parse dependencies (both string refs and .product refs)
        deps = []
        # Simple string dependencies
        for dep in re.findall(r'"(\w+)"', deps_str):
            deps.append(dep)
        # Product dependencies
        for dep in re.findall(r'\.product\s*\(\s*name:\s*"(\w+)"', deps_str):
            deps.append(dep)

        targets.append(Target(
            name=name,
            target_type=target_type,
            dependencies=deps,
            path=path
        ))

    return targets, products, external_deps


def scan_imports(sources_dir: str) -> dict:
    """
    Scan Swift sources to build import graph.
    Returns dict[module_name] -> set of imported modules
    """
    imports = {}

    for root, dirs, files in os.walk(sources_dir):
        # Skip hidden directories
        dirs[:] = [d for d in dirs if not d.startswith(".")]

        # Determine module from path
        rel_path = os.path.relpath(root, sources_dir)
        module = rel_path.split(os.sep)[0] if rel_path != "." else "Unknown"

        if module not in imports:
            imports[module] = set()

        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()

                # Extract import statements
                for match in re.finditer(r"^import\s+(\w+)", content, re.MULTILINE):
                    imported = match.group(1)
                    # Skip standard library
                    if imported not in ("Foundation", "Swift", "Combine", "Darwin", "os"):
                        imports[module].add(imported)

    return imports


def generate_package_diagram(targets: list, products: list) -> str:
    """Generate Mermaid diagram showing package structure."""
    lines = [
        "```mermaid",
        "graph TB",
        '    subgraph "Products"',
    ]

    for prod in products:
        icon = "📦" if prod.product_type == "library" else "🔧" if prod.product_type == "executable" else "🔌"
        lines.append(f'        {prod.name}["{icon} {prod.name}"]')

    lines.append("    end")
    lines.append("")
    lines.append('    subgraph "Library Targets"')

    lib_targets = [t for t in targets if t.target_type in ("target", "macro")]
    for target in lib_targets:
        icon = "🧩" if target.target_type == "macro" else "📚"
        lines.append(f'        {target.name}["{icon} {target.name}"]')

    lines.append("    end")
    lines.append("")
    lines.append('    subgraph "Executable Targets"')

    exec_targets = [t for t in targets if t.target_type == "executableTarget"]
    for target in exec_targets:
        lines.append(f'        {target.name}["🖥️ {target.name}"]')

    lines.append("    end")
    lines.append("")
    lines.append('    subgraph "Test Targets"')

    test_targets = [t for t in targets if t.target_type == "testTarget"]
    for target in test_targets:
        lines.append(f'        {target.name}["🧪 {target.name}"]')

    lines.append("    end")

    # Add product -> target relationships
    lines.append("")
    for prod in products:
        for target in prod.targets:
            lines.append(f"    {prod.name} --> {target}")

    lines.append("```")
    return "\n".join(lines)


def generate_dependency_diagram(targets: list, external_deps: list) -> str:
    """Generate Mermaid diagram showing target dependencies."""
    lines = [
        "```mermaid",
        "graph LR",
        '    subgraph "External Dependencies"',
    ]

    for dep in external_deps:
        safe_name = dep.replace("-", "_")
        lines.append(f'        {safe_name}["{dep}"]')

    lines.append("    end")
    lines.append("")
    lines.append('    subgraph "Internal Targets"')

    for target in targets:
        icon = {"target": "📚", "macro": "🧩", "executableTarget": "🖥️",
                "testTarget": "🧪", "plugin": "🔌"}.get(target.target_type, "📦")
        lines.append(f'        {target.name}["{icon} {target.name}"]')

    lines.append("    end")
    lines.append("")

    # Add dependency arrows
    for target in targets:
        for dep in target.dependencies:
            safe_dep = dep.replace("-", "_")
            lines.append(f"    {target.name} --> {safe_dep}")

    lines.append("```")
    return "\n".join(lines)


def generate_module_layers_diagram(targets: list) -> str:
    """Generate layered architecture diagram."""
    lines = [
        "```mermaid",
        "graph TB",
        '    subgraph "Presentation Layer"',
        '        CLI["FuncTestCLI<br/>CLI Interface"]',
        '        Plugins["Plugins<br/>SPM Integration"]',
        "    end",
        "",
        '    subgraph "Core Library"',
        '        InvariantSwift["InvariantSwift<br/>Main API"]',
        "    end",
        "",
        '    subgraph "Macro Infrastructure"',
        '        Macros["InvariantSwiftMacros<br/>Code Generation"]',
        "    end",
        "",
        '    subgraph "External Dependencies"',
        '        SwiftSyntax["swift-syntax"]',
        '        CustomDump["swift-custom-dump"]',
        "    end",
        "",
        "    CLI --> InvariantSwift",
        "    CLI --> CustomDump",
        "    Plugins --> CLI",
        "    InvariantSwift --> Macros",
        "    Macros --> SwiftSyntax",
        "```",
    ]
    return "\n".join(lines)


def generate_architecture_doc(
    targets: list,
    products: list,
    external_deps: list,
    imports: dict
) -> str:
    """Generate complete architecture documentation."""
    doc = [
        "# InvariantSwift Architecture Diagrams",
        "",
        "_Auto-generated by `Scripts/generate_architecture_diagrams.py`_",
        "",
        "## Package Structure",
        "",
        "Overview of products and their target mappings:",
        "",
        generate_package_diagram(targets, products),
        "",
        "## Target Dependencies",
        "",
        "How targets depend on each other and external packages:",
        "",
        generate_dependency_diagram(targets, external_deps),
        "",
        "## Layered Architecture",
        "",
        "Conceptual layers of the framework:",
        "",
        generate_module_layers_diagram(targets),
        "",
        "## Target Summary",
        "",
        "| Target | Type | Dependencies |",
        "|--------|------|--------------|",
    ]

    for target in targets:
        deps = ", ".join(target.dependencies) if target.dependencies else "_none_"
        doc.append(f"| {target.name} | {target.target_type} | {deps} |")

    doc.extend([
        "",
        "## External Dependencies",
        "",
        "| Package | Purpose |",
        "|---------|---------|",
        "| swift-syntax | Macro expansion and code analysis |",
        "| swift-custom-dump | Pretty-printing and diff output |",
        "",
        "---",
        "",
        f"_Generated: Auto-updated on package changes_",
    ])

    return "\n".join(doc)


def main():
    parser = argparse.ArgumentParser(
        description="Generate architecture diagrams from Package.swift"
    )
    parser.add_argument(
        "--output-dir",
        default="docs/architecture",
        help="Output directory for generated diagrams",
    )
    parser.add_argument(
        "--package",
        default="Package.swift",
        help="Path to Package.swift",
    )
    args = parser.parse_args()

    # Parse Package.swift
    package_path = args.package
    if not os.path.exists(package_path):
        print(f"❌ Package.swift not found at: {package_path}")
        return 1

    print("📦 Parsing Package.swift...")
    targets, products, external_deps = parse_package_swift(package_path)
    print(f"   Found {len(targets)} targets, {len(products)} products")

    # Scan imports
    print("🔍 Scanning source imports...")
    imports = scan_imports("Sources")

    # Generate documentation
    print("📊 Generating architecture diagrams...")
    doc = generate_architecture_doc(targets, products, external_deps, imports)

    # Ensure output directory exists
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Write generated diagrams
    output_path = output_dir / "generated-diagrams.md"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(doc)

    print(f"✅ Generated: {output_path}")
    print(f"   - Package structure diagram")
    print(f"   - Target dependencies diagram")
    print(f"   - Layered architecture diagram")

    return 0


if __name__ == "__main__":
    exit(main())
