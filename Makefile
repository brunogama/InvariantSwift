# FunctionalTesting Makefile

.PHONY: test-linux test-macos test-ios test-swift test-tvos format test-all clean

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
		-scheme FunctionalTesting \
		-destination platform="macOS" \
		| xcbeautify

# Test on iOS Simulator  
test-ios:
	set -o pipefail && \
	xcodebuild test \
		-scheme FunctionalTesting \
		-destination platform="iOS Simulator,name=iPhone 15 Pro,OS=latest" \
		| xcbeautify

# Platform-specific targets for CI
test-IOS:
	$(MAKE) test-ios

test-MACOS:
	$(MAKE) test-macos

test-TVOS:
	$(MAKE) test-tvos

# Test with Swift Package Manager
test-swift:
	swift test | xcbeautify

# Test on tvOS Simulator
test-tvos:
	set -o pipefail && \
	xcodebuild test \
		-scheme FunctionalTesting \
		-destination platform="tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest" \
		| xcbeautify

# Test on watchOS Simulator  
test-watchos:
	set -o pipefail && \
	xcodebuild test \
		-scheme FunctionalTesting \
		-destination platform="watchOS Simulator,name=Apple Watch Series 9 (45mm),OS=latest" \
		| xcbeautify

# Format code using swift-format
format:
	swift-format -i --configuration .swift-format --recursive \
		./Package.swift ./Sources ./Tests

# Build the package
build:
	swift build

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Generate documentation
docs:
	swift package generate-documentation

# Run linting
lint:
	swiftlint lint --strict

# Run all tests (excluding platform-specific Docker tests)
test-all: test-swift test-macos test-ios test-tvos

# Full validation (lint, format check, tests)
validate: lint test-swift

# Install dependencies
setup:
	brew install swiftlint swift-format xcbeautify

# Coverage report
coverage:
	swift test --enable-code-coverage
	xcrun llvm-cov export -format="lcov" \
		.build/debug/FunctionalTestingPackageTests.xctest/Contents/MacOS/FunctionalTestingPackageTests \
		-instr-profile .build/debug/codecov/default.profdata > coverage.lcov

# Help target
help:
	@echo "FunctionalTesting Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  test-linux    - Test on Linux using Docker"
	@echo "  test-macos    - Test on macOS"  
	@echo "  test-ios      - Test on iOS Simulator"
	@echo "  test-swift    - Test with Swift Package Manager"
	@echo "  test-tvos     - Test on tvOS Simulator"
	@echo "  test-watchos  - Test on watchOS Simulator"
	@echo "  test-all      - Run all platform tests"
	@echo "  format        - Format code with swift-format"
	@echo "  build         - Build the package"
	@echo "  clean         - Clean build artifacts"
	@echo "  docs          - Generate documentation"
	@echo "  lint          - Run SwiftLint"
	@echo "  validate      - Run lint and tests"
	@echo "  setup         - Install development dependencies"
	@echo "  coverage      - Generate coverage report"
	@echo "  help          - Show this help message"