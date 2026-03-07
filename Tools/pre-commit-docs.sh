#!/bin/bash

# Pre-commit documentation generation script
# This script generates Swift documentation for the project

set -e

echo "📚 Generating Swift documentation..."

# Check if we have any Swift files to document
if ! find Sources -name "*.swift" | grep -q .; then
    echo "ℹ️ No Swift source files found, skipping documentation generation"
    exit 0
fi

# Try to generate documentation with swift-docc-plugin
if swift package plugin --list | grep -q "SwiftDocCPlugin"; then
    echo "🔍 Using SwiftDocCPlugin for documentation generation..."
    swift package generate-documentation --target FunctionalTesting
elif command -v swift-doc >/dev/null 2>&1; then
    echo "🔍 Using swift-doc for documentation generation..."
    swift-doc generate Sources/FunctionalTesting --output Documentation
else
    echo "⚠️ No documentation tool found. Skipping documentation generation."
    echo "💡 Consider installing SwiftDocCPlugin or swift-doc for automatic documentation."
fi

echo "✅ Documentation generation completed"
