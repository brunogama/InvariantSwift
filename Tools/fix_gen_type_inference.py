#!/usr/bin/env python3
"""
Fix Gen.array type inference issues by adding explicit generic types.
Transforms Gen.array(Gen.int) to Gen<[Int]>.array(Gen<Int>.int)
"""

import re
from pathlib import Path

TEST_DIRS = [
    "Tests/FunctionalTesting",
    "Tests/CoverageIntegrationTests",
    "Tests/PerformanceTests",
]

# Patterns to fix
PATTERNS = [
    # Gen.array(Gen.int) -> Gen<[Int]>.array(Gen<Int>.int)
    (r'Gen\.array\(Gen\.int\)', r'Gen<[Int]>.array(Gen<Int>.int)'),
    (r'Gen\.array\(Gen<Int>\.int\)', r'Gen<[Int]>.array(Gen<Int>.int)'),

    # Gen.array(Gen.string) -> Gen<[String]>.array(Gen<String>.string)
    (r'Gen\.array\(Gen\.string\)', r'Gen<[String]>.array(Gen<String>.string)'),
    (r'Gen\.array\(Gen<String>\.string\)', r'Gen<[String]>.array(Gen<String>.string)'),

    # Gen.array(Gen.bool) -> Gen<[Bool]>.array(Gen<Bool>.bool)
    (r'Gen\.array\(Gen\.bool\)', r'Gen<[Bool]>.array(Gen<Bool>.bool)'),
    (r'Gen\.array\(Gen<Bool>\.bool\)', r'Gen<[Bool]>.array(Gen<Bool>.bool)'),

    # Gen.array(Gen.double) -> Gen<[Double]>.array(Gen<Double>.double)
    (r'Gen\.array\(Gen\.double\)', r'Gen<[Double]>.array(Gen<Double>.double)'),

    # Gen.int(in: ...) -> Gen<Int>.int(in: ...)
    (r'(?<!Gen<Int>.)Gen\.int\(in:', r'Gen<Int>.int(in:'),

    # Gen.string alone -> Gen<String>.string
    (r'(?<!<String>.)Gen\.string(?!\()', r'Gen<String>.string'),

    # Gen.bool alone -> Gen<Bool>.bool
    (r'(?<!<Bool>.)Gen\.bool(?!\()', r'Gen<Bool>.bool'),

    # Gen.int alone (not followed by parens) -> Gen<Int>.int
    (r'(?<!<Int>.)Gen\.int(?!\()', r'Gen<Int>.int'),
]

def process_file(filepath: Path) -> bool:
    """Process a single Swift file. Returns True if modified."""
    content = filepath.read_text()
    original = content

    for pattern, replacement in PATTERNS:
        content = re.sub(pattern, replacement, content)

    if content != original:
        filepath.write_text(content)
        return True
    return False

def main():
    root = Path(__file__).parent.parent
    modified_count = 0

    for test_dir in TEST_DIRS:
        dir_path = root / test_dir
        if not dir_path.exists():
            continue

        for swift_file in dir_path.glob("**/*.swift"):
            if process_file(swift_file):
                print(f"✓ Fixed: {swift_file.relative_to(root)}")
                modified_count += 1

    print(f"\n✅ Modified {modified_count} files")

if __name__ == "__main__":
    main()
