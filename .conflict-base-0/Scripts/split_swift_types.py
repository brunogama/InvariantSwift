#!/usr/bin/env python3
"""
Swift Type Extractor and File Splitter

Extracts public/internal types from large Swift files into separate files.
Uses SourceKitten for accurate AST-based parsing.

Usage:
    python3 split_swift_types.py [--dry-run] [--path PATH] [--min-types 2]
"""

import subprocess
import json
import re
import sys
import argparse
from pathlib import Path
from typing import NamedTuple, Optional
from dataclasses import dataclass, field


@dataclass
class SwiftType:
    """Represents a Swift type declaration."""
    name: str
    kind: str  # class, struct, enum, actor, protocol
    access_level: str  # public, internal, private, fileprivate, open
    start_line: int
    end_line: int
    content: str
    leading_comments: str = ""
    attributes: list[str] = field(default_factory=list)


def run_sourcekitten(file_path: str) -> Optional[dict]:
    """Run SourceKitten to get AST structure."""
    try:
        result = subprocess.run(
            ["sourcekitten", "structure", "--file", file_path],
            capture_output=True,
            text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            return json.loads(result.stdout)
    except FileNotFoundError:
        print("Warning: SourceKitten not found. Using regex fallback.")
    except Exception as e:
        print(f"SourceKitten error: {e}")
    return None


def extract_types_with_regex(content: str) -> list[SwiftType]:
    """
    Fallback regex-based type extraction when SourceKitten unavailable.
    Handles common Swift type declarations.
    """
    types = []
    lines = content.split('\n')
    
    # Pattern for type declarations
    type_pattern = re.compile(
        r'^(\s*)((?:@\w+(?:\([^)]*\))?\s+)*)'  # Attributes
        r'(public|internal|private|fileprivate|open)?\s*'  # Access level
        r'(final\s+)?'  # Final modifier
        r'(class|struct|enum|actor|protocol)\s+'  # Type keyword
        r'(\w+)'  # Type name
        r'([^{]*)'  # Generic parameters, inheritance
        r'\{'  # Opening brace
    )
    
    i = 0
    while i < len(lines):
        line = lines[i]
        match = type_pattern.match(line)
        
        if match:
            indent = match.group(1)
            attributes = match.group(2).strip()
            access_level = match.group(3) or 'internal'
            kind = match.group(5)
            name = match.group(6)
            
            # Only process top-level types (no indentation or single level)
            if len(indent) > 2:
                i += 1
                continue
            
            start_line = i + 1
            
            # Find matching closing brace
            brace_count = 1
            j = i + 1
            while j < len(lines) and brace_count > 0:
                for char in lines[j]:
                    if char == '{':
                        brace_count += 1
                    elif char == '}':
                        brace_count -= 1
                        if brace_count == 0:
                            break
                j += 1
            
            end_line = j
            
            # Extract leading comments
            leading_comments = []
            k = i - 1
            while k >= 0:
                stripped = lines[k].strip()
                if stripped.startswith('///') or stripped.startswith('//'):
                    leading_comments.insert(0, lines[k])
                    k -= 1
                elif stripped == '':
                    k -= 1
                else:
                    break
            
            # Extract type content
            type_lines = lines[i:end_line]
            type_content = '\n'.join(type_lines)
            
            types.append(SwiftType(
                name=name,
                kind=kind,
                access_level=access_level,
                start_line=start_line,
                end_line=end_line,
                content=type_content,
                leading_comments='\n'.join(leading_comments),
                attributes=[a.strip() for a in attributes.split() if a.strip()]
            ))
            
            i = end_line
        else:
            i += 1
    
    return types


def extract_types_with_sourcekitten(file_path: str, content: str) -> list[SwiftType]:
    """Extract types using SourceKitten AST."""
    ast = run_sourcekitten(file_path)
    if not ast:
        return extract_types_with_regex(content)
    
    types = []
    lines = content.split('\n')
    
    def process_substructure(items: list, depth: int = 0):
        if depth > 0:  # Only process top-level
            return
            
        for item in items:
            kind = item.get('key.kind', '')
            
            # Map SourceKitten kinds to our types
            kind_map = {
                'source.lang.swift.decl.class': 'class',
                'source.lang.swift.decl.struct': 'struct',
                'source.lang.swift.decl.enum': 'enum',
                'source.lang.swift.decl.protocol': 'protocol',
                'source.lang.swift.decl.extension': 'extension',
            }
            
            if kind in kind_map:
                name = item.get('key.name', 'Unknown')
                offset = item.get('key.offset', 0)
                length = item.get('key.length', 0)
                
                # Calculate line numbers from offset
                current_offset = 0
                start_line = 1
                for i, line in enumerate(lines):
                    if current_offset >= offset:
                        start_line = i + 1
                        break
                    current_offset += len(line) + 1  # +1 for newline
                
                end_offset = offset + length
                end_line = start_line
                current_offset = sum(len(l) + 1 for l in lines[:start_line-1])
                for i in range(start_line - 1, len(lines)):
                    current_offset += len(lines[i]) + 1
                    if current_offset >= end_offset:
                        end_line = i + 1
                        break
                
                # Get access level
                accessibility = item.get('key.accessibility', 'source.lang.swift.accessibility.internal')
                access_map = {
                    'source.lang.swift.accessibility.public': 'public',
                    'source.lang.swift.accessibility.internal': 'internal',
                    'source.lang.swift.accessibility.private': 'private',
                    'source.lang.swift.accessibility.fileprivate': 'fileprivate',
                    'source.lang.swift.accessibility.open': 'open',
                }
                access_level = access_map.get(accessibility, 'internal')
                
                # Extract content
                type_content = content[offset:offset+length]
                
                # Extract leading comments
                leading_comments = []
                k = start_line - 2
                while k >= 0:
                    stripped = lines[k].strip()
                    if stripped.startswith('///') or stripped.startswith('//'):
                        leading_comments.insert(0, lines[k])
                        k -= 1
                    elif stripped == '':
                        k -= 1
                    else:
                        break
                
                types.append(SwiftType(
                    name=name,
                    kind=kind_map[kind],
                    access_level=access_level,
                    start_line=start_line,
                    end_line=end_line,
                    content=type_content,
                    leading_comments='\n'.join(leading_comments)
                ))
            
            # Process nested (but don't extract nested types)
            if 'key.substructure' in item:
                process_substructure(item['key.substructure'], depth + 1)
    
    if 'key.substructure' in ast:
        process_substructure(ast['key.substructure'])
    
    return types if types else extract_types_with_regex(content)


def extract_imports(content: str) -> str:
    """Extract import statements from file."""
    imports = []
    for line in content.split('\n'):
        stripped = line.strip()
        if stripped.startswith('import '):
            imports.append(line)
        elif stripped.startswith('@_exported import'):
            imports.append(line)
    return '\n'.join(imports)


def extract_file_header(content: str) -> str:
    """Extract file header comments."""
    lines = content.split('\n')
    header_lines = []
    
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('//') or stripped == '':
            header_lines.append(line)
        elif stripped.startswith('import'):
            break
        else:
            break
    
    # Stop at first non-comment, non-empty line before imports
    return '\n'.join(header_lines).rstrip()


def generate_new_file_content(
    type_info: SwiftType,
    imports: str,
    original_file: str
) -> str:
    """Generate content for extracted type file."""
    parts = []
    
    # File header comment
    parts.append(f"// Extracted from {Path(original_file).name}")
    parts.append("")
    
    # Imports
    if imports:
        parts.append(imports)
        parts.append("")
    
    # Type documentation
    if type_info.leading_comments:
        parts.append(type_info.leading_comments)
    
    # Type content
    parts.append(type_info.content)
    parts.append("")
    
    return '\n'.join(parts)


def should_extract_type(type_info: SwiftType) -> bool:
    """Determine if a type should be extracted to its own file."""
    # Only extract public/internal types
    if type_info.access_level not in ('public', 'internal', 'open'):
        return False
    
    # Skip small types (less than 20 lines)
    type_lines = type_info.end_line - type_info.start_line
    if type_lines < 20:
        return False
    
    return True


def process_file(file_path: str, dry_run: bool = True, min_types: int = 2) -> dict:
    """Process a single Swift file and split types if needed."""
    path = Path(file_path)
    if not path.exists() or path.suffix != '.swift':
        return {'skipped': True, 'reason': 'Not a Swift file'}
    
    content = path.read_text()
    types = extract_types_with_sourcekitten(file_path, content)
    
    # Filter to extractable types
    extractable = [t for t in types if should_extract_type(t)]
    
    if len(extractable) < min_types:
        return {
            'skipped': True,
            'reason': f'Only {len(extractable)} extractable types (need {min_types}+)',
            'types_found': len(types)
        }
    
    imports = extract_imports(content)
    changes = []
    
    for type_info in extractable[1:]:  # Keep first type in original file
        new_file_name = f"{type_info.name}.swift"
        new_file_path = path.parent / new_file_name
        
        # Skip if file already exists
        if new_file_path.exists():
            changes.append({
                'action': 'skip',
                'type': type_info.name,
                'reason': f'{new_file_name} already exists'
            })
            continue
        
        new_content = generate_new_file_content(type_info, imports, file_path)
        
        changes.append({
            'action': 'create',
            'type': type_info.name,
            'kind': type_info.kind,
            'file': str(new_file_path),
            'lines': type_info.end_line - type_info.start_line,
            'content_preview': new_content[:200] + '...' if len(new_content) > 200 else new_content
        })
        
        if not dry_run:
            new_file_path.write_text(new_content)
    
    return {
        'file': file_path,
        'types_found': len(types),
        'extractable': len(extractable),
        'changes': changes
    }


def find_large_swift_files(path: str, min_lines: int = 400) -> list[str]:
    """Find Swift files that exceed the line limit."""
    large_files = []
    
    for swift_file in Path(path).rglob('*.swift'):
        # Skip test files and build artifacts
        if '.build' in str(swift_file) or 'Tests' in str(swift_file):
            continue
            
        try:
            line_count = len(swift_file.read_text().split('\n'))
            if line_count >= min_lines:
                large_files.append((str(swift_file), line_count))
        except Exception:
            pass
    
    return sorted(large_files, key=lambda x: -x[1])


def main():
    parser = argparse.ArgumentParser(
        description='Extract public/internal types from large Swift files'
    )
    parser.add_argument('--dry-run', action='store_true', default=True,
                        help='Show what would be extracted without making changes')
    parser.add_argument('--apply', action='store_true',
                        help='Actually extract types to new files')
    parser.add_argument('--path', default='Sources',
                        help='Path to scan for Swift files')
    parser.add_argument('--min-types', type=int, default=2,
                        help='Minimum types in file to trigger extraction')
    parser.add_argument('--min-lines', type=int, default=400,
                        help='Minimum lines in file to consider')
    parser.add_argument('--file', help='Process a specific file')
    args = parser.parse_args()
    
    dry_run = not args.apply
    
    print(f"{'[DRY RUN] ' if dry_run else ''}Swift Type Extractor")
    print("=" * 60)
    
    if args.file:
        files = [(args.file, 0)]
    else:
        print(f"Scanning {args.path} for files with {args.min_lines}+ lines...\n")
        files = find_large_swift_files(args.path, args.min_lines)
    
    if not files:
        print("No large Swift files found.")
        return
    
    print(f"Found {len(files)} large file(s):\n")
    
    total_extractions = 0
    
    for file_path, line_count in files:
        print(f"\n📄 {file_path} ({line_count} lines)")
        print("-" * 50)
        
        result = process_file(file_path, dry_run=dry_run, min_types=args.min_types)
        
        if result.get('skipped'):
            print(f"   ⏭️  Skipped: {result.get('reason')}")
            continue
        
        print(f"   Types found: {result['types_found']}")
        print(f"   Extractable: {result['extractable']}")
        
        for change in result.get('changes', []):
            if change['action'] == 'create':
                total_extractions += 1
                print(f"\n   ✨ Would extract: {change['type']} ({change['kind']}, {change['lines']} lines)")
                print(f"      → {change['file']}")
            elif change['action'] == 'skip':
                print(f"   ⏭️  Skip: {change['type']} - {change['reason']}")
    
    print("\n" + "=" * 60)
    print(f"Total extractions: {total_extractions}")
    
    if dry_run and total_extractions > 0:
        print("\n[DRY RUN] No changes made. Run with --apply to extract types.")


if __name__ == '__main__':
    main()
