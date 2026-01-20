# Claude Code Hooks

This directory contains custom hook scripts for automating quality checks and fixes in the InvariantSwift project.

## Available Hooks

### swiftlint-fix-and-check.sh

**Purpose**: Automatically fix SwiftLint violations and enforce strict checking after editing Swift files.

**Trigger**: PostToolUse hook on `Write`, `Edit`, or `MultiEdit` operations for `.swift` files.

**Behavior**:

1. **Silent Auto-Fix Phase**
   - Runs `swiftlint --fix --quiet` on the edited file
   - Automatically fixes violations that have auto-fix support
   - Runs silently without output

2. **Strict Check Phase**
   - Runs `swiftlint lint --strict --quiet` on the edited file
   - Treats warnings as violations in strict mode
   - Analyzes output to determine severity

3. **Result Handling**

   | Condition | Exit Code | Behavior |
   |-----------|-----------|----------|
   | No violations | 0 | Silent success, continue workflow |
   | Warnings only | 1 | Display warnings, allow continuation |
   | Errors present | 2 | Display errors, block until fixed |

**Exit Code Meanings**:

- **Exit 0**: Success - no violations or all violations auto-fixed
- **Exit 1**: Warnings found - agent is notified but workflow continues
- **Exit 2**: Errors found - workflow blocked, agent must fix manually

**Output Examples**:

```
❌ SwiftLint ERRORS detected in: Sources/Core/Gen.swift

Sources/Core/Gen.swift:42:1: error: Line Length Violation: Line should be 100 characters or less; currently it is 127 characters (line_length)
Sources/Core/Gen.swift:58:5: error: Force Cast Violation: Force casts should be avoided (force_cast)

⚠️  ACTION REQUIRED: Fix these errors before proceeding.
    SwiftLint auto-fix has been applied where possible.
    Manual fixes are required for remaining violations.
```

```
⚠️  SwiftLint warnings in: Sources/Core/Property.swift

Sources/Core/Property.swift:23:3: warning: Trailing Whitespace: Lines should not have trailing whitespace (trailing_whitespace)

ℹ️  These are warnings only - you may proceed.
   Consider addressing them to maintain code quality.
```

## Hook Configuration

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$CLAUDE_FILE_PATHS\" =~ \\.(swift)$ ]] && [[ ! \"$CLAUDE_FILE_PATHS\" =~ \\.build/ ]]; then swift-format -i --configuration .swift-format \"$CLAUDE_FILE_PATHS\" 2>/dev/null || true; fi"
          },
          {
            "type": "command",
            "command": ".claude/hooks/swiftlint-fix-and-check.sh"
          }
        ]
      }
    ]
  }
}
```

## Hook Execution Order

After editing a Swift file, hooks run in this order:

1. **swift-format**: Auto-format with Google Swift Style (2-space indent)
2. **swiftlint-fix-and-check.sh**: Auto-fix violations, then strict check

## Environment Variables

The hook script uses these environment variables provided by Claude Code:

- `CLAUDE_FILE_PATHS`: The file path(s) that were edited
- `CLAUDE_TOOL_INPUT`: The full tool input (used by PreToolUse hooks)

## Testing Hooks

To test the SwiftLint hook manually:

```bash
# Test on a specific file
export CLAUDE_FILE_PATHS="Sources/Core/Gen.swift"
.claude/hooks/swiftlint-fix-and-check.sh
echo "Exit code: $?"

# Test with a file that has violations
export CLAUDE_FILE_PATHS="path/to/file/with/violations.swift"
.claude/hooks/swiftlint-fix-and-check.sh
```

## Bypassing Hooks

**Important**: Hooks are quality gates. Bypass only when absolutely necessary.

For pre-commit hooks, use `SKIP` to bypass specific checks:

```bash
# Skip specific pre-commit check
SKIP=swiftlint git commit -m "message"

# Skip multiple checks
SKIP=swiftlint,swift-format git commit -m "message"
```

**Never use `--no-verify`**: This is blocked by PreToolUse hooks as it bypasses ALL quality gates.

## Adding New Hooks

1. Create script in `.claude/hooks/`
2. Make executable: `chmod +x .claude/hooks/your-hook.sh`
3. Add to `.claude/settings.json` in appropriate hook array
4. Document in this README

## Troubleshooting

**Hook not executing:**
- Check file is executable: `ls -l .claude/hooks/swiftlint-fix-and-check.sh`
- Verify path in settings.json is correct
- Check hook matcher regex matches your file type

**SwiftLint not found:**
- Install SwiftLint: `brew install swiftlint`
- Verify in PATH: `which swiftlint`

**Hook exits with error but no output:**
- Run hook manually with debugging: `bash -x .claude/hooks/swiftlint-fix-and-check.sh`
- Check SwiftLint config exists: `ls -la .swiftlint.yml`

## References

- SwiftLint documentation: https://github.com/realm/SwiftLint
- Claude Code hooks documentation: https://docs.anthropic.com/claude-code/hooks
- InvariantSwift linting rules: `.swiftlint.yml`
