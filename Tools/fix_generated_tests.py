#!/usr/bin/env python3
"""Fix generated test files to use proper InvariantSwift patterns."""

import os
import re
import sys

TESTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          "Tests", "Generated")

# Type mappings for generators
TYPE_GENERATORS = {
    "String": "Gen<String>.string",
    "Int": "Gen<Int>.int",
    "UInt": "Gen<UInt>.uint",
    "UInt64": "Gen<UInt64>.uint64",
    "Bool": "Gen<Bool>.bool",
    "Double": "Gen<Double>.double",
    "Float": "Gen<Float>.float",
    "Date": "Gen<Date>.date",
}

def infer_generator(type_name):
    """Get the proper generator for a type."""
    # Check if it's a known primitive
    if type_name in TYPE_GENERATORS:
        return TYPE_GENERATORS[type_name]

    # Check for Optional
    optional_match = re.match(r'Optional\((.+)\)', type_name)
    if optional_match:
        inner = infer_generator(optional_match.group(1))
        return f"Gen.optional({inner})"

    # Fallback to .arbitrary (assumes type conforms to Generatable)
    return f"{type_name}.arbitrary"


def extract_compose_block(content, start_pos):
    """Extract a Gen.compose { ... } block."""
    brace_count = 0
    in_block = False
    end_pos = start_pos

    for i in range(start_pos, len(content)):
        if content[i] == '{':
            brace_count += 1
            in_block = True
        elif content[i] == '}':
            brace_count -= 1
            if in_block and brace_count == 0:
                end_pos = i + 1
                break

    return content[start_pos:end_pos]


def transform_compose_block(match_text):
    """Transform a Gen.compose block to Gen.zip pattern."""
    # Extract the type being created and the properties
    # Pattern: Gen.compose { composer in TypeName(prop: composer.generate(...), ...) }

    # Find the type name
    type_match = re.search(r'composer in\s+(\w+)\(', match_text)
    if not type_match:
        return match_text  # Can't parse, return as-is

    type_name = type_match.group(1)

    # Extract property assignments
    prop_pattern = r'(\w+):\s*composer\.generate\(using:\s*([^)]+)\.arbitrary\)'
    props = re.findall(prop_pattern, match_text)

    if not props:
        return match_text  # Can't parse properties

    # Build the generators
    generators = [infer_generator(prop[1].strip()) for prop in props]
    prop_names = [prop[0] for prop in props]

    # Determine which zip to use
    num_props = len(props)
    if num_props == 1:
        gen_code = generators[0]
        map_params = "v0"
    elif num_props == 2:
        gen_code = f"Gen.zip({', '.join(generators)})"
        map_params = "v0, v1"
    elif num_props == 3:
        gen_code = f"Gen.zip3({', '.join(generators)})"
        map_params = "v0, v1, v2"
    elif num_props == 4:
        # Use nested zip for 4 params
        gen_code = f"Gen.zip(Gen.zip({generators[0]}, {generators[1]}), Gen.zip({generators[2]}, {generators[3]}))"
        map_params = "pair"
    elif num_props == 5:
        gen_code = f"Gen.zip(Gen.zip3({generators[0]}, {generators[1]}, {generators[2]}), Gen.zip({generators[3]}, {generators[4]}))"
        map_params = "pair"
    elif num_props == 6:
        gen_code = f"Gen.zip(Gen.zip3({generators[0]}, {generators[1]}, {generators[2]}), Gen.zip3({generators[3]}, {generators[4]}, {generators[5]}))"
        map_params = "pair"
    else:
        # Too many, return as comment with TODO
        return f"// TODO: Fix manually - too many properties ({num_props})\n    {match_text}"

    # Build initializer call
    if num_props <= 3:
        init_params = "\n        ".join([f"{prop_names[i]}: v{i}," for i in range(num_props)])
        init_params = init_params.rstrip(',')
        result = f"""{gen_code}.map {{ {map_params} in
      {type_name}(
        {init_params}
      )
    }}"""
    elif num_props == 4:
        result = f"""{gen_code}.map {{ pair in
      let (v0, v1) = pair.0
      let (v2, v3) = pair.1
      return {type_name}(
        {prop_names[0]}: v0,
        {prop_names[1]}: v1,
        {prop_names[2]}: v2,
        {prop_names[3]}: v3
      )
    }}"""
    elif num_props == 5:
        result = f"""{gen_code}.map {{ pair in
      let (v0, v1, v2) = pair.0
      let (v3, v4) = pair.1
      return {type_name}(
        {prop_names[0]}: v0,
        {prop_names[1]}: v1,
        {prop_names[2]}: v2,
        {prop_names[3]}: v3,
        {prop_names[4]}: v4
      )
    }}"""
    elif num_props == 6:
        result = f"""{gen_code}.map {{ pair in
      let (v0, v1, v2) = pair.0
      let (v3, v4, v5) = pair.1
      return {type_name}(
        {prop_names[0]}: v0,
        {prop_names[1]}: v1,
        {prop_names[2]}: v2,
        {prop_names[3]}: v3,
        {prop_names[4]}: v4,
        {prop_names[5]}: v5
      )
    }}"""

    return result


def fix_file(filepath):
    """Fix a single generated test file."""
    with open(filepath, 'r') as f:
        content = f.read()

    original = content

    # Replace Arbitrary -> Generatable (both in type and comments)
    content = re.sub(r': Arbitrary\b', ': Generatable', content)
    content = content.replace('Auto-Generated Arbitrary', 'Auto-Generated Generatable')

    # Ensure InvariantSwiftTesting import
    if 'import InvariantSwiftTesting' not in content:
        content = content.replace(
            '@testable import InvariantSwift',
            '@testable import InvariantSwift\nimport InvariantSwiftTesting'
        )

    # Find and transform Gen.compose blocks
    compose_pattern = r'Gen\.compose\s*\{[^}]*composer[^}]*\}'

    while True:
        match = re.search(r'Gen\.compose\s*\{', content)
        if not match:
            break

        start = match.start()
        block = extract_compose_block(content, start)

        if 'Gen.compose' not in block:
            break

        transformed = transform_compose_block(block)
        content = content[:start] + transformed + content[start + len(block):]

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed: {os.path.basename(filepath)}")
    else:
        print(f"No changes: {os.path.basename(filepath)}")


def main():
    if not os.path.exists(TESTS_DIR):
        print(f"Tests directory not found: {TESTS_DIR}")
        sys.exit(1)

    for filename in os.listdir(TESTS_DIR):
        if filename.endswith('.swift') and not filename.endswith('.disabled'):
            fix_file(os.path.join(TESTS_DIR, filename))

    print("Done!")


if __name__ == "__main__":
    main()
