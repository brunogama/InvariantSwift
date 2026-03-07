#!/usr/bin/env python3
"""
Add missing imports to InvariantSwift test files.
"""

import os
from pathlib import Path

TEST_DIRS = [
    "Tests/FunctionalTesting",
    "Tests/CoverageIntegrationTests",
    "Tests/PerformanceTests",
    "Tests/InvariantSwiftMacroTests",
    "Tests/InvariantSwiftDomainGeneratorsTests",
    "Tests/Generated",
]

# Types that require InvariantSwiftTesting import
TESTING_TYPES = [
    "TestRunStatistics", "AggregateStatistics", "StatisticsCollector",
    "checkProperty", "PropertyTestResult", "FailureReporting",
]

# Types that require InvariantSwiftExperimental import
EXPERIMENTAL_TYPES = [
    "MiningConfig", "InvariantMiningEngine", "ExecutionTrace", "ExecutionState",
    "DiscoveredInvariant", "Scheduler", "FlakeHunter", "CoverageGuided",
    "InvariantMiner", "StatisticalMiner", "TemplateMiner",
]

def add_import_if_missing(lines: list[str], import_stmt: str) -> list[str]:
    """Add import statement after existing imports if not present."""
    content = '\n'.join(lines)

    # Extract module name
    module = import_stmt.replace("@testable import ", "").replace("import ", "")

    # Check if already imported (either form)
    if f"import {module}" in content:
        return lines

    # Find last import line
    last_import_idx = -1
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("import ") or stripped.startswith("@testable import "):
            last_import_idx = i

    if last_import_idx == -1:
        return lines

    # Insert after last import
    new_lines = lines[:last_import_idx + 1]
    new_lines.append(import_stmt)
    new_lines.extend(lines[last_import_idx + 1:])
    return new_lines

def process_file(filepath: Path) -> bool:
    """Process a single Swift test file. Returns True if modified."""
    content = filepath.read_text()
    lines = content.split('\n')

    # Skip non-test files
    if 'import Testing' not in content and 'import XCTest' not in content:
        return False

    modified = False

    # Always ensure InvariantSwiftCore is imported
    if 'import InvariantSwiftCore' not in content:
        lines = add_import_if_missing(lines, "import InvariantSwiftCore")
        modified = True

    # Check for types requiring InvariantSwiftTesting
    needs_testing = any(t in content for t in TESTING_TYPES)
    if needs_testing and 'import InvariantSwiftTesting' not in content:
        lines = add_import_if_missing(lines, "@testable import InvariantSwiftTesting")
        modified = True

    # Check for types requiring InvariantSwiftExperimental
    needs_experimental = any(t in content for t in EXPERIMENTAL_TYPES)
    if needs_experimental and 'import InvariantSwiftExperimental' not in content:
        lines = add_import_if_missing(lines, "@testable import InvariantSwiftExperimental")
        modified = True

    if modified:
        filepath.write_text('\n'.join(lines))

    return modified

def main():
    root = Path(__file__).parent.parent
    modified_count = 0

    for test_dir in TEST_DIRS:
        dir_path = root / test_dir
        if not dir_path.exists():
            print(f"Skipping (not found): {test_dir}")
            continue

        for swift_file in dir_path.glob("**/*.swift"):
            if process_file(swift_file):
                print(f"✓ Modified: {swift_file.relative_to(root)}")
                modified_count += 1

    print(f"\n✅ Modified {modified_count} files")

if __name__ == "__main__":
    main()
