#!/bin/bash

# Pre-commit documentation generation script
# Generates comprehensive API documentation for Swift files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📚 Generating comprehensive API documentation...${NC}"

# Check if Swift files have been modified
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.swift$' | grep -v '^Tests/' || true)

if [[ -z "$STAGED_SWIFT_FILES" ]]; then
    echo -e "${YELLOW}ℹ️ No Swift source files modified, skipping documentation generation${NC}"
    exit 0
fi

# Check if Package.swift exists (Swift Package)
if [[ ! -f "Package.swift" ]]; then
    echo -e "${YELLOW}ℹ️ No Package.swift found, skipping documentation generation${NC}"
    exit 0
fi

echo -e "${BLUE}📄 Modified Swift files:${NC}"
echo "$STAGED_SWIFT_FILES" | while IFS= read -r file; do
    echo -e "${BLUE}  - $file${NC}"
done

# Check if any modified files have undocumented public APIs
echo -e "${BLUE}🔍 Checking for undocumented public APIs...${NC}"

UNDOCUMENTED_APIS=""
while IFS= read -r file; do
    if [[ -z "$file" ]]; then
        continue
    fi
    
    # Check for public declarations without documentation
    if grep -n 'public \(func\|var\|let\|class\|struct\|enum\|protocol\)' "$file" | grep -v '///' >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ Found potentially undocumented public APIs in: $file${NC}"
        UNDOCUMENTED_APIS="$UNDOCUMENTED_APIS $file"
    fi
done <<< "$STAGED_SWIFT_FILES"

# Generate documentation if Swift Package supports it
if command -v swift >/dev/null 2>&1; then
    echo -e "${BLUE}📖 Generating Swift documentation...${NC}"
    
    # Try to generate documentation
    if swift package generate-documentation >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Documentation generated successfully${NC}"
    else
        echo -e "${YELLOW}⚠️ Swift documentation generation failed or not supported${NC}"
        echo -e "${YELLOW}   This is non-critical and won't block the commit${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Swift command not found, skipping documentation generation${NC}"
fi

# Warning about undocumented APIs but don't fail the commit
if [[ -n "$UNDOCUMENTED_APIS" ]]; then
    echo -e "${YELLOW}📋 Reminder: Please ensure all public APIs have proper documentation${NC}"
    echo -e "${YELLOW}   Files with potential documentation gaps:${NC}"
    for file in $UNDOCUMENTED_APIS; do
        echo -e "${YELLOW}   - $file${NC}"
    done
    echo -e "${YELLOW}   Use /// comments for public API documentation${NC}"
fi

echo -e "${GREEN}📚 Documentation check completed${NC}"
exit 0