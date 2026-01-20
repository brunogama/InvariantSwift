# Regenerate Macro Expansion Golden Files

Regenerate golden files for macro expansion tests after macro changes.

## Steps

1. **Identify Macro** from `$ARGUMENTS`:
   - Macro name: `ArbitraryMacro`, `PropertyTestMacro`, etc.
   - No args: Regenerate all golden files

2. **Locate Golden Files**:
   ```bash
   find Tests/InvariantSwiftMacroTests/Resources/Golden -name "*.golden.swift"
   ```

3. **Run Macro Tests to Generate**:
   ```bash
   # Macro tests regenerate golden files on failure
   swift test --filter InvariantSwiftMacroTests 2>&1 | tee /tmp/macro-test-output.txt
   ```

4. **Verify Generation**:
   - Check for "Writing golden file" messages in output
   - Diff generated vs existing: `git diff Tests/InvariantSwiftMacroTests/Resources/Golden/`
   - Show changes to user for approval

5. **Review Changes**:
   - Read generated golden files
   - Verify expansions look correct
   - Check for proper trivia preservation
   - Ensure no runtime InvariantSwift library imports in macro code

## Usage

```
/generate-golden ArbitraryMacro         # Specific macro
/generate-golden                        # All macros
```

## Golden File Structure

```
Tests/InvariantSwiftMacroTests/Resources/Golden/
├── Arbitrary/
│   ├── Struct.swift          # Input
│   ├── Struct.golden.swift   # Expected expansion
│   ├── Enum.swift
│   └── Enum.golden.swift
├── PropertyTest/
└── StateMachine/
```

## Notes

- Golden files are version-controlled (commit after verification)
- SwiftSyntax AST changes may require regeneration
- Never edit golden files directly (use this command)
- PostToolUse hooks warn when editing golden files manually
