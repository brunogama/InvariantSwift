# InvariantSwift Quick Start

Get up and running with InvariantSwift in 10 minutes.

## Prerequisites

- Swift 6.0+
- Xcode 16.0+ (for macOS/iOS development)
- Homebrew (for installing tools)

## 1. Clone and Setup (2 minutes)

```bash
# Clone repository
git clone https://github.com/your-org/InvariantSwift.git
cd InvariantSwift

# Install development tools
/usr/bin/make setup

# Install git hooks
pip install pre-commit
pre-commit install
```

## 2. Verify Installation (3 minutes)

```bash
# Run tests
swift test | xcbeautify

# Check linting
swiftlint lint --strict

# Verify formatting
swift-format --configuration .swift-format --recursive ./Sources ./Tests
```

If all commands pass, your environment is ready. ✅

## 3. Your First Property Test (5 minutes)

Create `Tests/FunctionalTesting/MyFirstTest.swift`:

```swift
import Testing
import InvariantSwift

@PropertyTest
func testAdditionIsCommutative(a: Int, b: Int) {
  #expect(a + b == b + a)
}

@PropertyTest
func testStringConcatenation(s1: String, s2: String) {
  let result = s1 + s2
  #expect(result.hasPrefix(s1))
  #expect(result.hasSuffix(s2))
}
```

Run it:

```bash
swift test --filter MyFirstTest | xcbeautify
```

**That's it!** You've written your first property tests. The framework automatically:
- Generated 100+ test cases for each property
- Explored edge cases
- Found minimal counterexamples if any fail

## 4. Common Commands

```bash
# Test specific target
swift test --filter FunctionalTesting

# Run all tests
swift test | xcbeautify

# Generate coverage report
/usr/bin/make coverage

# Format code
/usr/bin/make format

# Lint code
swiftlint lint --strict

# Build package
swift build

# View documentation
swift package generate-documentation
open .build/documentation/InvariantSwift/InvariantSwift.doccarchive
```

## 5. Next Steps

- Read full onboarding guide: `docs/ONBOARDING.md`
- Review examples: `Examples/` directory
- Check API documentation: `README.md`
- Read contributing guidelines: `CONTRIBUTING.md`
- Explore architecture: `docs/architecture/`

## Key Concepts

**Property Testing:** Specify invariants that should always hold:

```swift
@PropertyTest
func property(input: T) {
  #expect(invariant(input))  // Must be true for all generated inputs
}
```

**Generators:** Define how to create test data:

```swift
Gen.int                         // Random Int
Gen.string                      // Random String
Gen.array(Gen.int)              // [Int]
Gen.oneOf(Gen.bool, Gen.int)    // Either Bool or Int
```

**Advanced:** Model-based, async, coverage-guided, and more in full onboarding guide.

## Troubleshooting

**Swift test fails?**
```bash
swift package resolve
swift package clean
rm -rf .build
swift test
```

**Missing tools?**
```bash
/usr/bin/make setup
```

**Pre-commit issues?**
```bash
pre-commit run --all-files
```

## Documentation

- **Quick Reference:** This file
- **Full Guide:** `docs/ONBOARDING.md`
- **Contributing:** `CONTRIBUTING.md`
- **Architecture:** `docs/architecture/InvariantSwift-architecture.md`

---

Ready to dive deeper? See `docs/ONBOARDING.md` for the complete guide.
