#!/bin/bash
# SwiftLint Post-Edit Hook
# Runs silent fix followed by strict check with appropriate error handling
#
# Exit codes:
#   0 - Success (no violations or warnings only)
#   1 - Warnings found (notify agent but don't block)
#   2 - Errors found (block and require agent to fix)

set -euo pipefail

# Get the edited file path from environment variable
FILE="${CLAUDE_FILE_PATHS:-}"

# Only process Swift files, skip .build directory
if [[ ! "$FILE" =~ \.swift$ ]] || [[ "$FILE" =~ \.build/ ]]; then
  exit 0
fi

# Ensure file exists
if [[ ! -f "$FILE" ]]; then
  exit 0
fi

# Step 1: Run silent auto-fix
swiftlint --fix --quiet "$FILE" 2>/dev/null || true

# Step 2: Run strict check and capture output
LINT_OUTPUT=$(swiftlint lint --strict --quiet "$FILE" 2>&1 || true)

# Parse output for warnings and errors
HAS_WARNINGS=false
HAS_ERRORS=false

if echo "$LINT_OUTPUT" | grep -q "warning:"; then
  HAS_WARNINGS=true
fi

if echo "$LINT_OUTPUT" | grep -q "error:"; then
  HAS_ERRORS=true
fi

# Handle results based on severity
if [[ "$HAS_ERRORS" == "true" ]]; then
  echo ""
  echo "❌ SwiftLint ERRORS detected in: $FILE"
  echo ""
  echo "$LINT_OUTPUT"
  echo ""
  echo "⚠️  ACTION REQUIRED: Fix these errors before proceeding."
  echo "    SwiftLint auto-fix has been applied where possible."
  echo "    Manual fixes are required for remaining violations."
  echo ""
  exit 2
elif [[ "$HAS_WARNINGS" == "true" ]]; then
  echo ""
  echo "⚠️  SwiftLint warnings in: $FILE"
  echo ""
  echo "$LINT_OUTPUT"
  echo ""
  echo "ℹ️  These are warnings only - you may proceed."
  echo "   Consider addressing them to maintain code quality."
  echo ""
  exit 1
fi

# Success - no violations
exit 0
