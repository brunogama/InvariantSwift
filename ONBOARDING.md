# FunctionalTesting - Developer Onboarding Guide

Welcome to FunctionalTesting! This comprehensive guide will help you get up to speed with our advanced property-based testing framework for Swift 6.

## 1. Project Overview

### Project Name & Purpose
**FunctionalTesting** - A comprehensive property-based testing framework for Swift 6, designed with category theory principles and focusing on mathematical law verification.

### Main Functionality
- Property-based testing with automatic test case generation
- Macro-based test generation (@PropertyTest, @BusinessRule)
- Coverage-guided testing with 99% target coverage
- Mathematical law verification for functional programming patterns
- Model-based testing for complex state machines
- CLI tool (functest) and SPM plugin for build integration

### Tech Stack
- **Language**: Swift 6.0+
- **Frameworks**: 
  - SwiftSyntax (509.0.0..<602.0.0) for macro implementations
  - swift-custom-dump (1.3.3+) for CLI pretty printing
  - Swift Testing framework for test integration
- **Build System**: Swift Package Manager
- **Platforms**: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, Linux

### Architecture Pattern
- **Protocol-witness pattern** for core architecture
- **Category theory principles** (functors, monads, lenses)
- **Actor-based concurrency** for Swift 6 strict compliance
- **Macro-driven code generation** for test automation

### Key Dependencies
- `swift-syntax`: Powers the macro system for @PropertyTest annotations
- `swift-custom-dump`: Enhanced debugging output for CLI tool
- Built-in Swift Testing framework integration

## 2. Repository Structure

### Top-Level Directories
```
FunctionalTesting/
├── .claude/           # Claude Code AI agent configurations
├── .github/           # GitHub Actions workflows and templates
├── DerivedData/       # Xcode build artifacts (gitignored)
├── Examples/          # Usage examples (Basic, Intermediate, Advanced)
├── Plugins/           # FuncTestPlugin - SPM plugin for build integration
├── Scripts/           # Build and automation scripts
├── Sources/           # Main source code
├── Tests/             # Test suites
└── TODO/              # Project task tracking
```

### Source Code Organization
```
Sources/
├── FuncTestCLI/               # Command-line tool implementation
├── FunctionalTesting/         # Main library
│   ├── Core/                  # Generator, Property, Seed, ModelTesting
│   ├── Generators/            # Primitive, Numeric, Collection generators
│   ├── Advanced/              # Coverage guidance, async properties, lenses
│   ├── SwiftTesting/          # Swift Testing framework integration
│   ├── Observability/         # Telemetry and monitoring
│   ├── Coverage/              # Coverage tracking implementation
│   ├── Database/              # Test corpus management
│   ├── Reliability/           # Flake detection and reliability
│   └── FunctionalTesting.docc/ # DocC documentation
└── FunctionalTestingMacros/   # SwiftSyntax macro implementations
```

### Test Organization
```
Tests/
├── FunctionalTestingTests/      # Core functionality tests
├── FunctionalTestingMacroTests/ # Macro expansion tests
├── PerformanceTests/            # Performance benchmarks
└── CoverageIntegrationTests/   # Coverage validation tests
```

### Unique Patterns
- **Macro-driven testing**: Heavy use of SwiftSyntax macros for test generation
- **Dog food testing**: Framework tests itself with 100% coverage requirement
- **Mathematical rigor**: Tests verify mathematical laws (functor laws, monad laws)
- **Coverage guidance**: Intelligent test generation biased toward uncovered paths

## 3. Getting Started

### Prerequisites
- **Swift**: 6.0+ (check with `swift --version`)
- **Xcode**: 16.0+ (for iOS/macOS development)
- **Tools**: 
  ```bash
  # Install development tools
  brew install swiftlint swift-format xcbeautify
  ```

### Environment Setup
1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-org/FunctionalTesting.git
   cd FunctionalTesting
   ```

2. **Install dependencies**:
   ```bash
   swift package resolve
   ```

3. **Verify setup**:
   ```bash
   swift --version  # Should show Swift 6.0+
   swiftlint --version
   swift-format --version
   ```

### Configuration Files
- `.swiftlint.yml` - Linting rules (strict mode enabled)
- `.swift-format` - Code formatting configuration (2-space indent)
- `.pre-commit-config.yaml` - Pre-commit hooks for code quality
- `spi.yml` - Swift Package Index configuration

### Running the Project

#### Run Tests
```bash
# Standard test run with beautified output
swift test | xcbeautify

# Run with coverage tracking
swift test --enable-code-coverage

# Platform-specific testing
make test-swift    # SPM testing
make test-macos    # macOS testing
make test-ios      # iOS Simulator testing
```

#### Build the Project
```bash
# Build all targets
swift build

# Build specific target
swift build --target FunctionalTesting
```

#### Run the CLI Tool
```bash
# Build and run functest CLI
swift run functest --help

# Run with specific options
swift run functest --coverage --iterations 1000
```

### Building for Production
```bash
# Release build
swift build -c release

# Generate optimized binary
swift build -c release --arch arm64 --arch x86_64
```

## 4. Key Components

### Entry Points
- **Library**: `Sources/FunctionalTesting/FunctionalTesting.swift` - Main module interface
- **CLI Tool**: `Sources/FuncTestCLI/main.swift` - Command-line interface
- **Macros**: `Sources/FunctionalTestingMacros/MacroPlugin.swift` - Macro registration

### Core Business Logic
- **Generator System**: `Sources/FunctionalTesting/Core/Generator.swift`
- **Property Testing**: `Sources/FunctionalTesting/Core/Property.swift`
- **Coverage Tracking**: `Sources/FunctionalTesting/Coverage/CoverageTracker.swift`
- **Shrinking Algorithm**: `Sources/FunctionalTesting/Advanced/ShrinkTrees.swift`

### Macro System
- **@PropertyTest**: Automatic test generation from function signatures
- **@BusinessRule**: Business logic verification macros
- Located in `Sources/FunctionalTestingMacros/`

### Configuration Management
- **PropertyConfig**: Test configuration (iterations, timeouts, seeds)
- **CoverageConfig**: Coverage tracking settings
- **TelemetryConfig**: Observability configuration

## 5. Development Workflow

### Git Branch Naming Conventions
- `feat/feature-name` - New features
- `fix/bug-description` - Bug fixes
- `refactor/component-name` - Code refactoring
- `docs/documentation-updates` - Documentation changes
- `test/test-additions` - Test improvements
- `epic/major-feature` - Large feature branches (current: `epic/no-math-macros`)

### Creating a New Feature
1. Create feature branch: `git checkout -b feat/your-feature`
2. Implement with tests (99% coverage requirement)
3. Add DocC documentation for public APIs
4. Update CHANGELOG.md
5. Run validation: `make validate`
6. Create pull request with conventional commit message

### Testing Requirements
- **99% code coverage** for production code
- **100% coverage** for dog food tests
- All tests must pass with zero warnings
- Mathematical concepts require law verification tests
- Use @PropertyTest macro for automatic test generation

### Code Style Rules
- **SwiftLint**: Strict mode enabled (warnings as errors)
- **Formatting**: 2-space indentation, 100 char line limit
- **Documentation**: Triple-slash comments for public APIs
- **Macros**: Annotations on separate lines from declarations

### PR Process
1. All tests must pass
2. Coverage requirements met (99%)
3. No compiler warnings
4. Documentation updated
5. CHANGELOG.md updated
6. Code review approval required

### CI/CD Pipeline
- **GitHub Actions** workflows in `.github/workflows/`
- **ci.yml**: Main CI pipeline (test, lint, coverage)
- **documentation.yml**: DocC generation
- **format.yml**: Code formatting checks
- **release.yml**: Release automation

## 6. Architecture Decisions

### Design Patterns
- **Protocol-Witness Pattern**: Type-safe, composable abstractions
- **Functor/Monad Pattern**: Mathematical law-based transformations
- **Actor Isolation**: Swift 6 concurrency compliance
- **Macro-Based Generation**: Compile-time test generation

### State Management
- **Seed-Based Determinism**: Reproducible test generation
- **Coverage State Tracking**: Real-time coverage analysis
- **Corpus Management**: Intelligent test case retention

### Error Handling
- **Result Types**: Explicit error propagation
- **Shrinking on Failure**: Automatic minimal counterexample finding
- **Detailed Diagnostics**: Rich error messages with context

### Logging & Monitoring
- **Telemetry System**: Built-in observability
- **Performance Metrics**: Test execution statistics
- **Coverage Reports**: Detailed coverage analysis

### Security Measures
- **Deterministic Generation**: Cryptographic-quality seeds
- **Sandbox Testing**: Isolated test execution
- **Input Validation**: Safe generator boundaries

### Performance Optimizations
- **Lazy Evaluation**: Efficient memory usage
- **Parallel Execution**: Multi-core test execution
- **Tree-Based Shrinking**: O(log n) shrinking complexity
- **10,000+ generations/second** for primitive types

## 7. Common Tasks

### Adding a New Generator
```swift
// In Sources/FunctionalTesting/Generators/CustomGenerators.swift
public extension Gen {
  static func myType() -> Gen<MyType> {
    Gen { rng, size in
      MyType(
        field1: Gen.string.generate(&rng, size),
        field2: Gen.int.generate(&rng, size)
      )
    }
  }
}
```

### Creating a Property Test
```swift
// Using the @PropertyTest macro
@PropertyTest
func testMyProperty(input: String, number: Int) {
  let result = myFunction(input, number)
  #expect(result.count == input.count + number)
}
```

### Adding Coverage Tracking
```swift
let runner = PropertyRunner()
let (result, coverage) = await runner.runPropertyWithCoverageTracking(
  property,
  knownSymbols: ["myFunction", "helperMethod"]
)
```

### Debugging Test Failures
```swift
// Enable detailed output
let config = PropertyConfig(
  iterations: 100,
  verbosity: .detailed,
  enableShrinking: true
)
try checkProperty(property, config: config)
```

### Updating Dependencies
```bash
# Update Package.resolved
swift package update

# Update specific dependency
swift package update swift-syntax
```

## 8. Potential Gotchas

### Non-Obvious Configurations
- **Coverage Threshold**: 99% is enforced, not optional
- **Macro Expansion**: Requires SwiftSyntax compilation
- **Platform Differences**: Some tests iOS/macOS specific

### Required Environment Variables
- None required for basic operation
- `FUNCTEST_COVERAGE_DIR`: Optional coverage output directory
- `FUNCTEST_TELEMETRY_ENDPOINT`: Optional telemetry URL

### External Service Dependencies
- No external services required for core functionality
- Optional telemetry server for observability

### Known Issues
- **Macro Edge Cases**: Currently addressing in `epic/no-math-macros` branch
- **Swift 6 Warnings**: Strict concurrency may flag legacy patterns
- **Coverage Calculation**: May vary slightly between platforms

### Performance Bottlenecks
- **Large Collection Generation**: O(n) for collections > 10,000 items
- **Deep Shrinking**: Complex nested structures may take time
- **Coverage Analysis**: Adds ~10% overhead to test execution

### Technical Debt Areas
- **Macro System Refactoring**: Ongoing in current epic branch
- **Legacy Generator Code**: Some generators need modernization
- **Documentation Gaps**: Some advanced features need more examples

## 9. Documentation and Resources

### Existing Documentation
- **README.md**: Project overview and quick start
- **CONTRIBUTING.md**: Contribution guidelines
- **CHANGELOG.md**: Version history
- **LICENSE**: MIT license
- **DocC Documentation**: In-code documentation (generate with `make docs`)

### API Documentation
- Generate with: `swift package generate-documentation`
- View at: `.build/documentation/functionaltesting/`

### Key Configuration Files
- **Package.swift**: Package manifest and dependencies
- **Makefile**: Build automation commands
- **.swiftlint.yml**: Linting configuration
- **.swift-format**: Formatting rules

### Team Resources
- **Code of Conduct**: CODE_OF_CONDUCT.md
- **Security Policy**: SECURITY.md
- **Issue Templates**: .github/ISSUE_TEMPLATE/
- **CI/CD Workflows**: .github/workflows/

## 10. Next Steps - New Developer Checklist

### Week 1: Environment Setup
- [ ] Set up development environment
- [ ] Install all required tools (Swift 6, SwiftLint, etc.)
- [ ] Clone and build the project successfully
- [ ] Run the full test suite
- [ ] Read through the main README and CONTRIBUTING guide

### Week 2: Exploration
- [ ] Make a small test change (add a simple test)
- [ ] Understand the generator system
- [ ] Try the @PropertyTest macro
- [ ] Run the functest CLI tool
- [ ] Explore the Examples/ directory

### Week 3: First Contribution
- [ ] Pick a "good first issue" from GitHub
- [ ] Create your first generator or property test
- [ ] Ensure 99% coverage for your code
- [ ] Submit your first pull request
- [ ] Participate in code review

### Areas to Start Contributing
1. **Test Coverage**: Help achieve 100% coverage in remaining areas
2. **Documentation**: Improve DocC comments and examples
3. **Generator Library**: Add new generators for common types
4. **Performance**: Optimize slow generators or shrinking
5. **Examples**: Create more usage examples
6. **Bug Fixes**: Address issues in the epic/no-math-macros branch

## Troubleshooting

### Common Issues

**Build Failures**
```bash
# Clean and rebuild
swift package clean
swift build
```

**Test Failures**
```bash
# Run with verbose output
swift test --enable-test-discovery -v
```

**Coverage Issues**
```bash
# Generate detailed coverage report
make coverage
open coverage.lcov
```

**Macro Compilation Errors**
```bash
# Rebuild macros specifically
swift build --target FunctionalTestingMacros
```

## Getting Help

- **GitHub Issues**: Report bugs or request features
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Check DocC and README
- **Examples**: Review Examples/ directory for patterns
- **Team**: Reach out to maintainers for guidance

## Important Project Rules

1. **No Warnings Policy**: Code must compile with zero warnings
2. **Coverage Requirements**: 99% for production, 100% for dog food tests
3. **Documentation Mandatory**: All public APIs need DocC comments
4. **Mathematical Rigor**: FP concepts need law verification
5. **Changelog Updates**: Every change needs CHANGELOG entry
6. **Test Everything**: No code without tests
7. **Clean Commits**: Follow conventional commit format

Welcome to the team! We're excited to have you contribute to making FunctionalTesting the world's most advanced property-based testing framework for Swift.