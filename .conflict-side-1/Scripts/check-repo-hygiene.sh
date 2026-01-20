#!/bin/bash
# check-repo-hygiene.sh
# Fails if macOS artifacts (.DS_Store, __MACOSX/) are found in the repo
# Used in CI to prevent accidental inclusion of OS-specific files

set -e

echo "🔍 Checking for macOS artifacts..."

# Check for .DS_Store files
DS_STORE_FILES=$(find . -name ".DS_Store" -not -path "./.git/*" 2>/dev/null || true)
if [ -n "$DS_STORE_FILES" ]; then
    echo "❌ Found .DS_Store files:"
    echo "$DS_STORE_FILES"
    exit 1
fi

# Check for __MACOSX directories
MACOSX_DIRS=$(find . -name "__MACOSX" -type d -not -path "./.git/*" 2>/dev/null || true)
if [ -n "$MACOSX_DIRS" ]; then
    echo "❌ Found __MACOSX directories:"
    echo "$MACOSX_DIRS"
    exit 1
fi

echo "✅ No macOS artifacts found"
exit 0
