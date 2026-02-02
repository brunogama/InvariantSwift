# Fix SwiftLint Violations

Auto-fix SwiftLint violations in the current context or specified files.

## Steps

1. **Identify Target Files**:
   - If `$ARGUMENTS` provided: Use those specific files
   - If no args: Ask user which files need linting
   - Common targets: Recently edited files, files in current conversation

2. **Run SwiftLint Auto-Fix**:
   ```bash
   swiftlint lint --fix --config .swiftlint.yml $FILES
   ```

3. **Verify Strict Mode**:
   ```bash
   swiftlint lint --strict --config .swiftlint.yml $FILES
   ```

4. **Report Results**:
   - Show fixed violations count
   - Show remaining violations (if any) with file:line references
   - Suggest manual fixes for complex violations

## Usage

```
/fix-lint                                    # Interactive file selection
/fix-lint Sources/InvariantSwift/Core/Gen.swift
/fix-lint Sources/InvariantSwiftMacros/      # Directory
```

## Notes

- Respects `.swiftlint.yml` configuration (Google Swift Style)
- Some violations require manual fixes (complexity, file length)
- PostToolUse hooks already auto-fix on Edit/Write
- Use this command for batch fixing multiple files
