#!/usr/bin/env python3
import os
import re
import sys

def check_documentation(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    issues = []

    for i, line in enumerate(lines):
        stripped = line.strip()

        # Check for public declarations
        if re.match(r'^public\s+(struct|class|enum|func|var|let|init|actor|protocol)', stripped):
            # Check if previous line has documentation
            prev_line = lines[i-1].strip() if i > 0 else ""

            # Look for /// documentation in previous lines
            has_docs = False
            j = i - 1
            while j >= 0 and (lines[j].strip().startswith('///') or lines[j].strip() == ''):
                if lines[j].strip().startswith('///'):
                    has_docs = True
                    break
                elif lines[j].strip() != '':
                    break
                j -= 1

            if not has_docs:
                issues.append((i + 1, stripped))

    return issues

def main():
    total_issues = 0
    files_with_issues = 0

    for root, dirs, files in os.walk('Sources'):
        for file in files:
            if file.endswith('.swift'):
                file_path = os.path.join(root, file)
                issues = check_documentation(file_path)

                if issues:
                    files_with_issues += 1
                    print(f"\n📄 {file_path}")
                    print("=" * len(file_path))

                    for line_num, declaration in issues:
                        print(f"  ❌ Line {line_num}: {declaration}")

                    total_issues += len(issues)

    print(f"\n📊 SUMMARY:")
    print(f"Files with documentation issues: {files_with_issues}")
    print(f"Total missing documentation: {total_issues}")

    if total_issues > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
