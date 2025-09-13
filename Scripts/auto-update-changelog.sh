#!/bin/bash

# Auto-update changelog script for pre-commit hooks
# This script automatically updates CHANGELOG.md when Swift source files are modified

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHANGELOG_FILE="CHANGELOG.md"
TEMP_CHANGELOG="/tmp/changelog_temp_$$"

echo -e "${BLUE}📝 Auto-updating CHANGELOG.md...${NC}"

# Exit early if no CHANGELOG.md exists
if [[ ! -f "$CHANGELOG_FILE" ]]; then
    echo -e "${YELLOW}ℹ️ No CHANGELOG.md found, skipping auto-update${NC}"
    exit 0
fi

# Get list of staged Swift files (excluding tests)
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.swift$' | grep -v '^Tests/' | grep -v '\.disabled$' | head -20 || true)

if [[ -z "$STAGED_SWIFT_FILES" ]]; then
    echo -e "${YELLOW}ℹ️ No non-test Swift files staged, skipping changelog update${NC}"
    exit 0
fi

echo -e "${BLUE}🔍 Analyzing staged Swift files...${NC}"

# Function to analyze file changes and generate changelog entries
generate_changelog_entries() {
    local entries=()
    local today=$(date +"%Y-%m-%d")
    
    while IFS= read -r file; do
        if [[ -z "$file" ]]; then
            continue
        fi
        
        echo "  📄 Analyzing: $file" >&2
        
        # Determine change type based on git status
        local status=$(git diff --cached --name-status "$file" | cut -f1)
        local entry=""
        
        case "$status" in
            A)
                # New file
                if [[ "$file" =~ Sources/.*\.swift$ ]]; then
                    local module=$(echo "$file" | sed 's|Sources/\([^/]*\)/.*|\1|')
                    local filename=$(basename "$file" .swift)
                    entry="- **Added**: New $filename implementation in $module module"
                elif [[ "$file" =~ .*Generator.*\.swift$ ]]; then
                    entry="- **Added**: New generator implementation"
                elif [[ "$file" =~ .*Property.*\.swift$ ]]; then
                    entry="- **Added**: New property-based testing features"
                elif [[ "$file" =~ .*Macro.*\.swift$ ]]; then
                    entry="- **Added**: New macro functionality"
                else
                    local filename=$(basename "$file" .swift)
                    entry="- **Added**: New $filename implementation"
                fi
                ;;
            M)
                # Modified file
                # Analyze the actual changes to generate better descriptions
                local changes=$(git diff --cached "$file" | grep '^+' | grep -v '^+++' | head -5)
                
                if echo "$changes" | grep -q 'func\|class\|struct\|enum\|protocol'; then
                    if [[ "$file" =~ .*Generator.*\.swift$ ]]; then
                        entry="- **Enhanced**: Generator functionality improvements"
                    elif [[ "$file" =~ .*Property.*\.swift$ ]]; then
                        entry="- **Enhanced**: Property testing capabilities"
                    elif [[ "$file" =~ .*Macro.*\.swift$ ]]; then
                        entry="- **Enhanced**: Macro implementation improvements"
                    elif [[ "$file" =~ Sources/.*\.swift$ ]]; then
                        local module=$(echo "$file" | sed 's|Sources/\([^/]*\)/.*|\1|')
                        entry="- **Enhanced**: Core functionality in $module module"
                    else
                        local filename=$(basename "$file" .swift)
                        entry="- **Enhanced**: $filename implementation"
                    fi
                elif echo "$changes" | grep -q 'fix\|Fix\|bug\|Bug\|error\|Error'; then
                    entry="- **Fixed**: Bug fixes and error handling improvements"
                elif echo "$changes" | grep -q 'test\|Test\|coverage\|Coverage'; then
                    entry="- **Enhanced**: Test coverage and validation improvements"
                elif echo "$changes" | grep -q 'performance\|Performance\|optimize\|Optimize'; then
                    entry="- **Optimized**: Performance improvements"
                elif echo "$changes" | grep -q 'doc\|Doc\|comment\|Comment'; then
                    entry="- **Documented**: Improved documentation and code comments"
                else
                    if [[ "$file" =~ Sources/.*\.swift$ ]]; then
                        local module=$(echo "$file" | sed 's|Sources/\([^/]*\)/.*|\1|')
                        entry="- **Updated**: Improvements to $module module"
                    else
                        local filename=$(basename "$file" .swift)
                        entry="- **Updated**: $filename enhancements"
                    fi
                fi
                ;;
            R*)
                # Renamed file
                entry="- **Refactored**: File organization improvements"
                ;;
            D)
                # Deleted file - should be rare for Swift files
                entry="- **Removed**: Deprecated functionality cleanup"
                ;;
        esac
        
        if [[ -n "$entry" ]]; then
            entries+=("$entry")
        fi
    done <<< "$STAGED_SWIFT_FILES"
    
    # Remove duplicates and format entries
    printf '%s\n' "${entries[@]}" | sort -u
}

# Generate the changelog entries
CHANGELOG_ENTRIES=$(generate_changelog_entries)

if [[ -z "$CHANGELOG_ENTRIES" ]]; then
    echo -e "${YELLOW}ℹ️ No significant changes detected for changelog${NC}"
    exit 0
fi

echo -e "${GREEN}📝 Generated changelog entries:${NC}"
echo "$CHANGELOG_ENTRIES" | while IFS= read -r line; do
    echo -e "${GREEN}  $line${NC}"
done

# Get current date and version info
TODAY=$(date +"%Y-%m-%d")
CURRENT_VERSION=$(grep -E '^## \[.*\]' "$CHANGELOG_FILE" | head -1 | sed 's/## \[\(.*\)\].*/\1/' || echo "Unreleased")

# Check if there's already an unreleased section for today
if grep -q "## \[Unreleased\] - $TODAY" "$CHANGELOG_FILE"; then
    echo -e "${BLUE}📌 Adding to existing unreleased section for $TODAY${NC}"
    
    # Insert entries after the existing unreleased header
    awk -v entries="$CHANGELOG_ENTRIES" -v today="$TODAY" '
    /^## \[Unreleased\] - '"$TODAY"'/ {
        print $0
        if (getline > 0 && $0 !~ /^$/) print $0
        print entries
        print ""
        next
    }
    { print }
    ' "$CHANGELOG_FILE" > "$TEMP_CHANGELOG"
    
elif grep -q "## \[Unreleased\]" "$CHANGELOG_FILE"; then
    echo -e "${BLUE}📌 Adding to existing unreleased section${NC}"
    
    # Add entries to existing unreleased section
    awk -v entries="$CHANGELOG_ENTRIES" '
    /^## \[Unreleased\]/ {
        print $0
        if (getline > 0) print $0
        print entries
        print ""
        next
    }
    { print }
    ' "$CHANGELOG_FILE" > "$TEMP_CHANGELOG"
    
else
    echo -e "${BLUE}📌 Creating new unreleased section${NC}"
    
    # Create new unreleased section at the top
    {
        # Keep header if it exists
        if head -1 "$CHANGELOG_FILE" | grep -q '^# '; then
            head -1 "$CHANGELOG_FILE"
            echo ""
        fi
        
        echo "## [Unreleased] - $TODAY"
        echo ""
        echo "$CHANGELOG_ENTRIES"
        echo ""
        
        # Add rest of file, skipping the header if we already printed it
        if head -1 "$CHANGELOG_FILE" | grep -q '^# '; then
            tail -n +2 "$CHANGELOG_FILE"
        else
            cat "$CHANGELOG_FILE"
        fi
    } > "$TEMP_CHANGELOG"
fi

# Replace the original file
mv "$TEMP_CHANGELOG" "$CHANGELOG_FILE"

# Add the updated changelog to the staging area
git add "$CHANGELOG_FILE"

echo -e "${GREEN}✅ CHANGELOG.md updated successfully!${NC}"
echo -e "${BLUE}📄 Updated changelog has been staged for commit${NC}"

# Show a preview of what was added
echo -e "${YELLOW}📋 Preview of changelog update:${NC}"
echo -e "${YELLOW}$CHANGELOG_ENTRIES${NC}"

exit 0