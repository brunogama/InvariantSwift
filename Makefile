# InvariantSwift Makefile

.PHONY: test-linux test-macos test-ios test-swift test-safe test-tvos format test-all clean \
	doc-check doc-check-json doc-diagrams doc-api doc-examples docs-gen docs-validate \
	benchmark benchmark-json

# Test on Linux using Docker
test-linux:
	docker run \
		--rm \
		-v "$(PWD):$(PWD)" \
		-w "$(PWD)" \
		swift:6.0-jammy \
		bash -c 'swift test'

# Test on macOS
test-macos:
	set -o pipefail && \
	xcodebuild test \
		-scheme InvariantSwift \
		-destination platform="macOS" \
		| xcbeautify

# Test on iOS Simulator
test-ios:
	set -o pipefail && \
	xcodebuild test \
		-scheme InvariantSwift \
		-destination platform="iOS Simulator,name=iPhone 15 Pro,OS=latest" \
		| xcbeautify

# Platform-specific targets for CI
test-IOS:
	$(MAKE) test-ios

test-MACOS:
	$(MAKE) test-macos

test-TVOS:
	$(MAKE) test-tvos

# Test with Swift Package Manager (with prebuilts for faster macro compilation)
test-swift:
	swift test --enable-experimental-prebuilts | xcbeautify

# Test with SIGTRAP crash handling (for macOS beta SDK)
# Use this when running on pre-release macOS SDKs that have known ABI issues
test-safe:
	@echo "🛡️  Running tests with SIGTRAP crash protection..."
	python3 sigtrap_capture.py InvariantSwift --verbose

# Test on tvOS Simulator
test-tvos:
	set -o pipefail && \
	xcodebuild test \
		-scheme InvariantSwift \
		-destination platform="tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest" \
		| xcbeautify

# Test on watchOS Simulator
test-watchos:
	set -o pipefail && \
	xcodebuild test \
		-scheme InvariantSwift \
		-destination platform="watchOS Simulator,name=Apple Watch Series 9 (45mm),OS=latest" \
		| xcbeautify

# Format code using swift-format
format:
	swift-format -i --configuration .swift-format --recursive \
		./Package.swift ./Sources ./Tests

# Build the package (with prebuilts for faster macro compilation)
build:
	swift build --enable-experimental-prebuilts

# Build individual sub-packages
.PHONY: build-core
build-core:
	swift build --package-path Packages/InvariantSwiftCore

.PHONY: build-macros
build-macros:
	swift build --package-path Packages/InvariantSwiftMacros --enable-experimental-prebuilts

# Test individual sub-packages
.PHONY: test-core
test-core:
	swift test --package-path Packages/InvariantSwiftCore

.PHONY: test-macros
test-macros:
	swift test --package-path Packages/InvariantSwiftMacros --enable-experimental-prebuilts

# Parallel CI build (builds sub-packages first, then full package)
.PHONY: ci-build
ci-build: build-core build-macros
	swift build --enable-experimental-prebuilts

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Clean all workspace packages
.PHONY: clean-all
clean-all:
	swift package clean
	swift package clean --package-path Packages/InvariantSwiftCore
	swift package clean --package-path Packages/InvariantSwiftMacros
	rm -rf .build Packages/*/.build

# Generate documentation
docs:
	@echo "Generating documentation..."
	@which docc > /dev/null 2>&1 && \
	docc convert Sources/InvariantSwift/FunctionalTesting.docc || \
	echo "Note: docc command not found. Install with: brew install apple/swift-packages/swift-docc"

# Run linting
lint:
	swiftlint lint --strict

# Run all tests (excluding platform-specific Docker tests)
test-all: test-swift test-macos test-ios test-tvos

# Full validation (lint, format check, tests with prebuilts)
validate: lint test-swift

# Install dependencies
setup:
	brew install swiftlint swift-format xcbeautify

# Run benchmarks (release mode for accurate results)
benchmark:
	swift run -c release Benchmarks

# Run benchmarks with JSON output
benchmark-json:
	swift run -c release Benchmarks --format json

# Coverage report
coverage:
	swift test --enable-code-coverage
	xcrun llvm-cov export -format="lcov" \
		.build/debug/InvariantSwiftTests.xctest/Contents/MacOS/InvariantSwiftTests \
		-instr-profile .build/debug/codecov/default.profdata > coverage.lcov

# Help target
help:
	@echo "InvariantSwift Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  test-linux    - Test on Linux using Docker"
	@echo "  test-macos    - Test on macOS"
	@echo "  test-ios      - Test on iOS Simulator"
	@echo "  test-swift    - Test with Swift Package Manager (with prebuilts)"
	@echo "  test-safe     - Test with SIGTRAP crash handling (beta SDK)"
	@echo "  test-tvos     - Test on tvOS Simulator"
	@echo "  test-watchos  - Test on watchOS Simulator"
	@echo "  test-all      - Run all platform tests"
	@echo "  format        - Format code with swift-format"
	@echo "  build         - Build the package (with prebuilts)"
	@echo "  clean         - Clean build artifacts"
	@echo "  docs          - Generate documentation"
	@echo "  lint          - Run SwiftLint"
	@echo "  validate      - Run lint and tests (with prebuilts)"
	@echo "  setup         - Install development dependencies"
	@echo "  coverage      - Generate coverage report"
	@echo ""
	@echo "Workspace targets:"
	@echo "  build-core    - Build InvariantSwiftCore package (no SwiftSyntax)"
	@echo "  build-macros  - Build InvariantSwiftMacros package (with prebuilts)"
	@echo "  test-core     - Test InvariantSwiftCore package"
	@echo "  test-macros   - Test InvariantSwiftMacros package"
	@echo "  ci-build      - Build sub-packages then full package (for CI)"
	@echo "  clean-all     - Clean all workspace packages"
	@echo ""
	@echo "Documentation tools:"
	@echo "  doc-check     - Check documentation coverage"
	@echo "  doc-diagrams  - Generate architecture diagrams"
	@echo "  doc-api       - Generate API reference"
	@echo "  doc-examples  - Validate code examples in docs"
	@echo "  docs-gen      - Generate all docs (diagrams + API)"
	@echo "  docs-validate - Full documentation validation"
	@echo ""
	@echo "  help          - Show this help message"

# Generate DocC static site for GitHub Pages
docs-all:
	@echo "Generating DocC static documentation..."
	@rm -rf ./docs
	@which docc > /dev/null 2>&1 && \
	docc convert Sources/InvariantSwift/FunctionalTesting.docc \
		--output-path ./docs \
		--hosting-base-path InvariantSwift \
		--transform-for-static-hosting || \
	(echo "Note: docc command not found. Using xcodebuild approach..."; \
	xcodebuild docbuild \
		-scheme InvariantSwift \
		-derivedDataPath .build/docc-build && \
	cp -r .build/docc-build/Build/Products/Release/InvariantSwift.doccarchive ./docs || \
	echo "⚠️  Documentation generation requires xcodebuild or docc command.")
	@if [ -d "./docs" ]; then \
		echo "✅ Documentation generated in ./docs/"; \
		echo "📖 Preview locally: open ./docs/index.html"; \
	else \
		echo "⚠️  Documentation generation skipped (docc/xcodebuild not available)"; \
	fi

# ============================================================================
# Documentation Generation Tools
# ============================================================================

# Check documentation coverage (informational, doesn't fail)
doc-check:
	@echo "📚 Checking documentation coverage..."
	@python3 check_docs.py --verbose || true

# Check documentation coverage (strict - fails if issues found, for CI)
doc-check-strict:
	@echo "📚 Checking documentation coverage (strict mode)..."
	@python3 check_docs.py --verbose

# Check documentation with JSON report
doc-check-json:
	@python3 check_docs.py --json --output docs/coverage-report.json
	@echo "✅ Report written to docs/coverage-report.json"

# Generate architecture diagrams
doc-diagrams:
	@echo "📊 Generating architecture diagrams..."
	@python3 Tools/generate_architecture_diagrams.py

# Generate API reference
doc-api:
	@echo "📖 Generating API reference..."
	@python3 Tools/generate_api_reference.py

# Validate documentation examples (informational)
doc-examples:
	@echo "🧪 Validating documentation examples..."
	@python3 Tools/validate_doc_examples.py --verbose || true

# Generate all documentation (diagrams + API reference)
docs-gen: doc-diagrams doc-api
	@echo "✅ All documentation generated"

# Full documentation check (coverage + examples + generation)
docs-validate: doc-check doc-examples docs-gen
	@echo "✅ Documentation validation complete"
