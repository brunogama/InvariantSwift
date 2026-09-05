set default-list

# Allow explicit `just default` invocation as well as bare `just`.
default: help

# Test on Linux using Docker.
test-linux:
    docker run --rm -v "$PWD:$PWD" -w "$PWD" swift:6.0-jammy bash -c 'swift test'

# Test on macOS.
test-macos:
    #!/usr/bin/env bash
    set -o pipefail
    xcodebuild test -scheme InvariantSwift -destination platform="macOS" | xcbeautify --preserve-unbeautified -q

# Test on an iOS Simulator.
test-ios:
    #!/usr/bin/env bash
    set -o pipefail
    xcodebuild test -scheme InvariantSwift -destination platform="iOS Simulator,name=iPhone 15 Pro,OS=latest" | xcbeautify --preserve-unbeautified -q

# Test on a tvOS Simulator.
test-tvos:
    #!/usr/bin/env bash
    set -o pipefail
    xcodebuild test -scheme InvariantSwift -destination platform="tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest" | xcbeautify --preserve-unbeautified -q

# Test on a watchOS Simulator.
test-watchos:
    #!/usr/bin/env bash
    set -o pipefail
    xcodebuild test -scheme InvariantSwift -destination platform="watchOS Simulator,name=Apple Watch Series 9 (45mm),OS=latest" | xcbeautify --preserve-unbeautified -q

# Preserve CI target spellings.
alias test-IOS := test-ios
alias test-MACOS := test-macos
alias test-TVOS := test-tvos

# Test with Swift Package Manager and macro prebuilts.
test-swift:
    #!/usr/bin/env bash
    set -o pipefail
    swift test --enable-experimental-prebuilts | xcbeautify --preserve-unbeautified -q

# Run all non-Linux test suites.
test-all: test-swift test-macos test-ios test-tvos

# Test with SIGTRAP crash protection.
test-safe:
    python3 Tools/sigtrap_capture.py InvariantSwift --verbose

# Format root workspace Swift sources.
format:
    swift-format -i --configuration .swift-format --recursive ./Package.swift ./Sources ./Tests
    swiftlint --fix --quiet

# Check root workspace Swift formatting without modifying files.
format-check:
    swift-format lint --configuration .swift-format --recursive ./Package.swift ./Sources ./Tests

# Build the root package with macro prebuilts.
build:
    swift build --enable-experimental-prebuilts

# Build the core sub-package.
build-core:
    swift build --package-path Packages/InvariantSwiftCore --enable-experimental-prebuilts

# Build the macros sub-package.
build-macros:
    swift build --package-path Packages/InvariantSwiftMacros --enable-experimental-prebuilts

# Test the core sub-package.
test-core:
    swift test --package-path Packages/InvariantSwiftCore --enable-experimental-prebuilts

# Test the macros sub-package.
test-macros:
    swift test --package-path Packages/InvariantSwiftMacros --enable-experimental-prebuilts

# Build sub-packages before the root package.
ci-build: build-core build-macros
    swift build --enable-experimental-prebuilts

# Remove root build artifacts.
clean:
    swift package clean
    rm -rf .build

# Remove build artifacts from every workspace package.
clean-all:
    swift package clean
    swift package clean --package-path Packages/InvariantSwiftCore
    swift package clean --package-path Packages/InvariantSwiftMacros
    rm -rf .build Packages/*/.build

# Build the Swift Testing documentation catalog.
docs:
    docc convert Sources/InvariantSwiftTestingIntegration/InvariantSwiftTesting.docc

# Build a static documentation site.
docs-all:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf ./docs
    if command -v docc >/dev/null 2>&1; then
        docc convert Sources/InvariantSwiftTestingIntegration/InvariantSwiftTesting.docc --output-path ./docs --hosting-base-path InvariantSwift --transform-for-static-hosting
    else
        xcodebuild docbuild -scheme InvariantSwift -derivedDataPath .build/docc-build
        cp -r .build/docc-build/Build/Products/Release/InvariantSwiftTesting.doccarchive ./docs
    fi

# Run SwiftLint in strict mode.
lint:
    swiftlint lint --strict

# Run required local validation checks.
validate: format-check lint
    swift build -Xswiftc -warnings-as-errors
    swift test --enable-experimental-prebuilts

# Install development tools.
setup:
    brew install just swiftlint swift-format xcbeautify

# Run release-mode benchmarks.
benchmark:
    swift run -c release Benchmarks

# Run release-mode benchmarks with JSON output.
benchmark-json:
    swift run -c release Benchmarks --format json

# Generate an LCOV coverage report.
coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    swift test --enable-code-coverage
    test_binary="$(find .build -path '*InvariantSwiftPackageTests.xctest/Contents/MacOS/InvariantSwiftPackageTests' -type f | head -1)"
    test -n "$test_binary"
    xcrun llvm-cov export -format="lcov" "$test_binary" -instr-profile .build/debug/codecov/default.profdata > coverage.lcov

# Check documentation coverage without failing.
doc-check:
    python3 Tools/check_docs.py --verbose || true

# Check documentation coverage and fail on findings.
doc-check-strict:
    python3 Tools/check_docs.py --verbose

# Write a JSON documentation coverage report.
doc-check-json:
    python3 Tools/check_docs.py --json --output docs/coverage-report.json

# Generate architecture diagrams.
doc-diagrams:
    python3 Tools/generate_architecture_diagrams.py

# Generate the API reference.
doc-api:
    python3 Tools/generate_api_reference.py

# Validate documentation examples without failing.
doc-examples:
    python3 Tools/validate_doc_examples.py --verbose || true

# Generate architecture diagrams and the API reference.
docs-gen: doc-diagrams doc-api
    @echo "All documentation generated"

# Run the current documentation validation sequence.
docs-validate: doc-check doc-examples docs-gen
    @echo "Documentation validation complete"

# Show available recipes.
help:
    just --list
