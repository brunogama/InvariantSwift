# FunctionalTesting - Quick Start Guide

Get up and running with FunctionalTesting in 5 minutes!

## Prerequisites

- Swift 6.0+
- macOS 14+ or Linux

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/FunctionalTesting.git
   cd FunctionalTesting
   ```

2. **Install dependencies**
   ```bash
   swift package resolve
   ```

3. **Install development tools** (macOS)
   ```bash
   brew install swiftlint swift-format xcbeautify
   ```

## Essential Commands

### Build
```bash
swift build
```

### Run Tests
```bash
swift test | xcbeautify
```

### Run with Coverage
```bash
swift test --enable-code-coverage
```

### Format Code
```bash
make format
```

### Lint Code
```bash
swiftlint lint --strict
```

### Run CLI Tool
```bash
swift run functest --help
```

## Your First Property Test

Create a test file and add:

```swift
import Testing
import FunctionalTesting

@PropertyTest
func testStringReverse(s: String) {
    #expect(String(s.reversed().reversed()) == s)
}
```

Run it:
```bash
swift test --filter testStringReverse
```

## Project Structure

```
FunctionalTesting/
├── Sources/
│   ├── FunctionalTesting/     # Main library
│   ├── FunctionalTestingMacros/ # Macro implementations
│   └── FuncTestCLI/           # CLI tool
├── Tests/                     # Test suites
├── Examples/                  # Usage examples
└── Package.swift             # Package manifest
```

## Key Makefile Targets

```bash
make test-swift    # Run tests with SPM
make test-macos    # Run on macOS
make test-ios      # Run on iOS Simulator
make validate      # Lint and test
make coverage      # Generate coverage report
make docs          # Generate documentation
```

## Common Workflows

### Add a New Test
1. Create test with @PropertyTest macro
2. Run: `swift test`
3. Ensure 99% coverage maintained

### Fix a Bug
1. Write failing test first
2. Fix the bug
3. Verify: `make validate`
4. Update CHANGELOG.md

### Submit Changes
1. Create feature branch
2. Make changes with tests
3. Run: `make validate`
4. Commit with conventional format
5. Open pull request

## Help & Resources

- **Full Onboarding**: See ONBOARDING.md
- **Contributing**: See CONTRIBUTING.md
- **Examples**: Check Examples/ directory
- **Documentation**: Run `make docs`

## Next Steps

1. ✅ Environment is set up
2. ✅ Tests are running
3. 📖 Read ONBOARDING.md for detailed guide
4. 🔍 Explore Examples/ directory
5. 🚀 Start contributing!

## Troubleshooting

**Build fails?**
```bash
swift package clean && swift build
```

**Tests fail?**
```bash
swift test -v  # Verbose output
```

**Need help?**
- Check GitHub Issues
- Read documentation
- Ask in Discussions

Happy Testing! 🎯