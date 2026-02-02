# InvariantSwift Developer Onboarding Guide

Welcome to **InvariantSwift** – a comprehensive property-based testing framework for Swift 6 designed with category theory principles and mathematical rigor.

This guide provides everything you need to understand, set up, and contribute to the project.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Repository Structure](#repository-structure)
3. [Getting Started](#getting-started)
4. [Development Workflow](#development-workflow)
5. [Key Components](#key-components)
6. [Testing Strategy](#testing-strategy)
7. [Code Style & Standards](#code-style--standards)
8. [Common Tasks](#common-tasks)
9. [Architecture Decisions](#architecture-decisions)
10. [Troubleshooting](#troubleshooting)
11. [Resources](#resources)

---

## Project Overview

### What is InvariantSwift?

InvariantSwift is a production-grade property-based testing framework that:

- **Generates test cases automatically** from high-level property specifications
- **Finds edge cases** through intelligent shrinking and counterexample minimization
- **Verifies mathematical laws** for functional programming patterns
- **Supports advanced testing** patterns: async properties, model-based testing, coverage-guided generation, invariant mining, and more
- **Integrates seamlessly** with Swift Testing framework and SPM ecosystem

### Key Features

**Core Testing Capabilities**
- Property-based testing with automatic test case generation
- Comprehensive generators for all Swift types
- Deterministic seed-based reproducibility
- Integrated shrinking with tree-based algorithms
- Mathematical law verification for functional types

**Advanced Features**
- Coverage-guided generation targeting 99% code coverage
- Async/concurrent property testing with actor isolation
- Model-based testing for stateful systems
- Lens/Prism/Traversal system for compositional testing
- DICE (Distributed Integrated Coverage Engine) for advanced coverage analysis
- Invariant mining and automatic invariant discovery
- Linearizability testing for concurrent algorithms
- Metamorphic relation testing
- SMT solver integration for constraint-based testing
- Flaky test detection and reliability analysis

**Developer Experience**
- `@PropertyTest` macro for automatic test generation
- `@BusinessRule` macro for business-friendly testing
- `functest` CLI tool for command-line testing
- SPM plugin integration (`swift package functest`)
- Comprehensive documentation and examples

### Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **Swift** | 6.0+ | Language (strict concurrency compliance) |
| **Xcode** | 16.0+ | IDE for iOS/macOS development |
| **Swift Testing** | Latest | Test framework integration |
| **SwiftSyntax** | 509.0.0–602.0.0 | Macro implementations |
| **swift-custom-dump** | 1.3.3+ | Pretty printing |
| **SwiftLint** | Latest | Code linting |
| **swift-format** | Latest | Code formatting |
| **xcbeautify** | Latest | Test output formatting |

### Platform Support

- **iOS** 18.0+
- **macOS** 15.0+
- **tvOS** 18.0+
- **watchOS** 11.0+
- **macCatalyst** 18.0+
- **Linux** (Swift 6.0+ compatible distributions)

---

## Repository Structure

### Top-Level Organization

```
InvariantSwift/
├── Sources/                      # Main source code
│   ├── InvariantSwift/          # Core library (33 files, 13 modules)
│   ├── InvariantSwiftMacros/    # SwiftSyntax macros (5 files)
│   └── FuncTestCLI/             # CLI tool (1 file)
├── Tests/                        # Test suite (4 test targets, 27 files)
│   ├── FunctionalTesting/       # Core tests (20 files)
│   ├── InvariantSwiftMacroTests/# Macro tests (2 files)
│   ├── CoverageIntegrationTests/# Coverage tests (4 files)
│   └── PerformanceTests/        # Performance tests (1 file)
├── Plugins/                      # SPM Plugin
│   └── FuncTestPlugin/          # Build-time integration
├── Examples/                     # Usage examples
├── docs/                         # Architecture documentation
├── scripts/                      # Build and utility scripts
├── Package.swift                # SPM manifest
├── Makefile                      # Build targets
├── .github/                      # CI/CD workflows
├── .swift-format                # Code formatter config
├── .swiftlint.yml              # Linter config
├── .pre-commit-config.yaml     # Git hooks
├── .gitmessage                  # Commit message template
└── Configuration & Documentation
    ├── README.md                # Project README
    ├── CONTRIBUTING.md          # Contributing guidelines
    ├── CODE_OF_CONDUCT.md      # Community standards
    ├── SECURITY.md              # Security policy
    ├── LICENSE                  # MIT license
    └── CHANGELOG.md             # Version history
```

### Source Code Organization

**Sources/InvariantSwift/** (Core Library – 13 Modules)

| Module | Responsibility | Key Files |
|--------|-----------------|-----------|
| **Core** | Fundamental types and execution | Generator.swift, Property.swift, Seed.swift, ModelTesting.swift |
| **Generators** | Data generation | PrimitiveGenerators.swift, NumericGenerators.swift, CollectionGenerators.swift, etc. |
| **Advanced** | Specialized testing | CoverageGuided.swift, AsyncProperties.swift, LensSystem.swift, DICE.swift, InvariantMining.swift, etc. |
| **Coverage** | Coverage tracking | ClassificationCoverage.swift |
| **Database** | Example storage | ExampleDB.swift, ExampleDatabase.swift |
| **Observability** | Monitoring | TelemetrySystem.swift |
| **Presentation** | Result formatting | PrettyPrint.swift |
| **Reliability** | Flake detection | FlakeHunter.swift |
| **SwiftTesting** | Framework integration | PropertyTestIntegration.swift |
| **Macros** | Macro declarations | BusinessRuleMacroDeclaration.swift |

**Sources/InvariantSwiftMacros/** (Compile-Time Code Generation)

| File | Purpose |
|------|---------|
| `PropertyMacro.swift` | `@PropertyTest` macro for automatic test generation |
| `BusinessRuleMacro.swift` | `@BusinessRule` macro for business-friendly testing |
| `LawCheckedMacro.swift` | Mathematical law verification macros |
| `DeriveGenMacro.swift` | `@DeriveGen` macro for custom type generators |
| `MacroPlugin.swift` | Macro plugin orchestration |

### Test Organization

**FunctionalTesting/** (20 Core Test Files)

Tests for generators, properties, and framework functionality:
- Generator tests: `PrimitiveGenerators`, `NumericGenerators`, `CollectionGenerators`, `ComprehensiveGenerators`
- Property tests: `PropertyTests`, `AsyncPropertyTests`, `PropertyTestIntegrationTests`
- Advanced features: `CoverageGuidedTests`, `LensSystemTests`, `InvariantMiningOptimizationTests`
- Coverage: `DogfoodPropertyTests`, `ErrorPathCoverageTests`, `CoverageCompletionTests`
- Specialties: `ModelBasedTests`, `MathematicalLawTests`, `MetaPropertyTests`, `RecursiveShrinkingTests`

**InvariantSwiftMacroTests/** (2 Files)

- `PropertyMacroTests.swift` – Macro expansion and error handling
- `BusinessRuleMacroTests.swift` – Business rule macro verification

**CoverageIntegrationTests/** (4 Files)

- `CoverageValidationTests.swift` – Coverage metrics
- `AutomatedCoverageTests.swift` – Automated analysis
- `FinalCoverageValidationTests.swift` – Final validation
- `LLVMCoverageRunner.swift` – LLVM coverage integration

**PerformanceTests/** (1 File)

- `PropertyPerformanceTests.swift` – Performance regression tests

---

## Getting Started

### Prerequisites

**Required**
- **Swift 6.0+** (download from swift.org)
- **Xcode 16.0+** (if developing for iOS/macOS)
- **macOS 13.0+** or Linux with Swift 6.0+

**Recommended for Development**
- **Homebrew** for installing tools
- **Git** for version control
- **Docker** for Linux testing

### Installation & Setup

#### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/InvariantSwift.git
cd InvariantSwift
```

#### Step 2: Install Development Dependencies

**On macOS:**

```bash
# Install build tools via Homebrew
/usr/bin/make setup
# or manually:
brew install swiftlint swift-format xcbeautify
```

**On Linux:**

```bash
# Swift should be pre-installed
# Install additional tools as needed:
apt-get install -y shellcheck
```

#### Step 3: Install Git Hooks

```bash
# Install pre-commit framework
pip install pre-commit

# Install project hooks (will run on every commit)
pre-commit install

# Test hooks are installed:
pre-commit run --all-files
```

#### Step 4: Verify Installation

```bash
# Run the test suite (should pass completely)
swift test | xcbeautify

# Run linting (should pass with no warnings)
swiftlint lint --strict

# Verify code formatting
swift-format --configuration .swift-format --recursive ./Sources ./Tests

# Build the package
swift build
```

If all commands succeed, your development environment is ready.

### First-Time Setup Checklist

- [ ] Clone repository: `git clone https://github.com/your-org/InvariantSwift.git`
- [ ] Navigate to directory: `cd InvariantSwift`
- [ ] Install dependencies: `/usr/bin/make setup`
- [ ] Install pre-commit hooks: `pre-commit install`
- [ ] Run tests: `swift test | xcbeautify`
- [ ] Verify linting: `swiftlint lint --strict`
- [ ] Check formatting: `swift-format --configuration .swift-format --recursive ./Sources ./Tests`
- [ ] Review README.md and CONTRIBUTING.md
- [ ] Explore examples in `Examples/` directory
- [ ] Read architecture documentation in `docs/`

---

## Development Workflow

### Daily Development Routine

**Start of Day**
1. Pull latest changes: `git pull origin main`
2. Run tests to ensure everything passes: `swift test | xcbeautify`
3. Check any new documentation or architecture decisions

**During Development**

#### Creating a Feature or Bugfix

1. **Create a feature branch** using conventional naming:
   ```bash
   # Feature: feat/my-feature-name
   # Bugfix: fix/my-bug-fix
   # Documentation: docs/my-docs-update

   git checkout -b feat/my-feature-name
   ```

2. **Write tests first** (TDD approach):
   - Add test case in appropriate test file
   - Property-based tests are preferred
   - Include edge cases and error scenarios

3. **Implement the feature**:
   - Follow code style guidelines (see Code Style & Standards)
   - Run tests frequently: `swift test | xcbeautify`
   - Ensure code passes linting: `swiftlint lint --strict`

4. **Format your code** before committing:
   ```bash
   swift-format -i --configuration .swift-format --recursive ./Sources ./Tests
   ```

#### Git Workflow

**Commit Messages** (Conventional Commits format)

```
type(scope): description

[optional body]

[optional footer]
```

**Type Examples:**
- `feat(generators)` – New feature
- `fix(shrinking)` – Bug fix
- `test(coverage)` – Test additions
- `docs(readme)` – Documentation
- `refactor(api)` – Code restructuring
- `perf(generation)` – Performance improvement
- `chore(deps)` – Dependency updates

**Examples:**
```bash
git commit -m "feat(generators): add UUID generator"
git commit -m "fix(shrinking): handle empty arrays correctly"
git commit -m "test(coverage): add tests for edge cases"
```

**Push and Create PR**

```bash
git push origin feat/my-feature-name
# Then create a pull request on GitHub
```

### Pre-Commit Hooks (Automatic Validation)

The project uses 13 pre-commit hooks that run automatically before every commit:

**Code Quality Hooks:**
- `swift-format` – Auto-formats code
- `swiftlint` – Auto-fixes linting issues
- `swift-package-tests` – Runs test suite (blocks commit if tests fail)
- `swift-coverage-guard` – Enforces 99% coverage (blocks commit if coverage drops)
- `swift-warning-guard` – Checks for compiler warnings (blocks commit if warnings exist)

**Process Hooks:**
- `branch-guardian` – Prevents direct commits to main/dev branches
- `license-year-updater` – Updates LICENSE year
- `changelog-enforcer` – Ensures CHANGELOG.md is updated
- `prevent-swift-disabled-files` – Prevents .swift.disabled files from being committed
- `shellcheck-scripts` – Validates shell scripts

**Standard Hooks:**
- `trailing-whitespace` – Removes trailing whitespace
- `end-of-file-fixer` – Adds final newlines
- `check-yaml`, `check-merge-conflict`, etc.

**Important Notes:**
- Hooks will block commits if critical checks fail (tests, coverage, warnings)
- If a hook fails, fix the issue and try committing again
- Never use `--no-verify` to skip hooks – this violates project standards
- The CHANGELOG.md must be updated for all non-chore commits

### Pull Request Process

1. **Create PR** from your feature branch to `main`
2. **PR Title** should follow Conventional Commits format
3. **PR Description** should include:
   - What changes were made and why
   - How to test the changes
   - Any breaking changes
   - Links to related issues
4. **Wait for CI checks** to pass (tests, linting, formatting, coverage)
5. **Request review** from maintainers
6. **Address feedback** and push updates
7. **Merge** once approved (use "Squash and merge" for cleaner history)

### CI/CD Pipeline

The project has comprehensive GitHub Actions workflows:

**On Push to main:**
- `swift-test-linux` – Tests on Linux (Swift 6.0-jammy)
- `xcodebuild-latest` – Tests on macOS/iOS/tvOS with Xcode 16.4
- `lint` – SwiftLint validation
- `format-check` – swift-format validation
- `coverage` – Code coverage analysis and upload to Codecov

**Key Points:**
- All CI checks must pass before merging
- Coverage reports are uploaded to Codecov
- Build cache optimizes CI performance
- Concurrency prevents redundant runs on the same branch

---

## Key Components

### Core Module

**Generator.swift** – The heart of the framework

```swift
public struct Gen<T> {
  public func generate(_ rng: inout SystemRandomNumberGenerator, _ size: Int) -> T
}
```

- Generates random values of type `T`
- Supports functor (`map`), applicative (`zip`, `apply`), and monad (`flatMap`) operations
- Deterministic when given same seed
- Performance: 10,000+ generations/second for primitive types

**Key Generators:**
```swift
Gen.bool                          // Random Bool
Gen.int                           // Random Int
Gen.int(in: 0...100)              // Int in range
Gen.string                        // Random String
Gen.array(Gen.int)                // [Int]
Gen.dictionary(Gen.string, Gen.int) // [String: Int]
```

**Property.swift** – Test specifications

```swift
public struct Property<T> {
  let generator: Gen<T>
  let predicate: (T) -> Bool
}
```

- Combines a generator with a boolean predicate
- PropertyRunner executes properties and shrinks failures
- Result includes shrunk counterexample if property fails

**Seed.swift** – Deterministic randomness

```swift
public struct Seed {
  private var state: UInt64

  mutating func next() -> UInt64
}
```

- 64-bit linear congruential generator
- Enables reproducible test runs: use same seed to reproduce failures
- Used internally by `SystemRandomNumberGenerator`

**ModelTesting.swift** – Stateful testing

```swift
protocol Command {
  associatedtype System
  func run(on system: inout System) -> Bool
}
```

- Framework for testing stateful systems
- Compares model implementation against real implementation
- Detects state invariant violations

### Advanced Module Highlights

**CoverageGuided.swift** – Bias generation toward uncovered code

```swift
coverage-guided property runner biases generation based on:
- Execution paths taken in previous runs
- Uncovered branches in target code
- Coverage goals (99% target)
```

**AsyncProperties.swift** – Async/concurrent testing

```swift
@PropertyTest
func testAsyncOperation(input: String) async {
  let result = await asyncFunction(input)
  #expect(result.isValid)
}
```

- Full Swift 6 strict concurrency support
- Actor isolation for thread safety
- Concurrent property test execution

**LensSystem.swift** – Compositional property testing

```swift
let nameLens = Lens<Person, String>(
  get: { $0.name },
  set: { person, name in Person(name: name, age: person.age) }
)
```

- Immutable focus/update pattern (Lens, Prism, Traversal)
- Enables compositional testing of nested structures
- Supports property-based focusing

**ShrinkTrees.swift** – Counterexample minimization

```swift
let shrinks: Shrink<Array<Int>> = array(int).shrink(value: [5, 3, 1, 2])
// Produces minimal counterexample: [1]
```

- Tree-based shrinking algorithm
- Finds minimal failing test cases
- Efficient pruning of search space

### Macro System

**@PropertyTest** – Automatic test generation

```swift
@PropertyTest
func testAddition(a: Int, b: Int) {
  #expect((a + b) - a == b)
}
```

Macro automatically generates:
- Test function with proper signature
- Generator for each parameter type
- Property runner configuration
- Result validation

**@BusinessRule** – Business-friendly testing

```swift
@BusinessRule("Customer discount increases with purchase amount")
func testDiscountRule(amount: Double) {
  let discount = calculateDiscount(amount)
  #expect(discount >= 0)
}
```

Creates business rule documentation alongside tests.

---

## Testing Strategy

### Coverage Requirements

**Target: 99% Code Coverage**

This project has strict coverage requirements because:
- Framework quality depends on testing the framework itself ("dog food tests")
- Property-based testing should exercise all code paths
- Coverage-guided generation requires baseline coverage

**Coverage Validation:**
```bash
/usr/bin/make coverage           # Generate LLVM coverage report
swift test --enable-code-coverage  # With coverage collection
```

### Test Types

| Test Type | Purpose | Location | Example |
|-----------|---------|----------|---------|
| **Unit Tests** | Test individual generators | `*GeneratorTests.swift` | `testIntGeneratorRange` |
| **Property Tests** | Specify invariants to verify | `PropertyTests.swift` | `@PropertyTest func testAddition(a: Int, b: Int)` |
| **Mathematical Law Tests** | Verify functor/monad laws | `MathematicalLawTests.swift` | `testOptionalFunctorIdentity` |
| **Model-Based Tests** | Test stateful systems | `ModelBasedTests.swift` | `testStackCommands` |
| **Async Tests** | Test concurrent operations | `AsyncPropertyTests.swift` | `testAsyncProperty` async |
| **Coverage Tests** | Validate coverage metrics | `CoverageGuidedTests.swift` | Coverage-guided execution |
| **Integration Tests** | Test framework integration | `PropertyTestIntegrationTests.swift` | Swift Testing integration |
| **Performance Tests** | Benchmark regression | `PropertyPerformanceTests.swift` | Generation speed tests |

### Running Tests

```bash
# Run all tests with formatted output
swift test | xcbeautify

# Run specific test target
swift test --filter FunctionalTesting

# Run specific test function
swift test --filter testAddition

# Run with verbose output
swift test --verbose

# Run on specific platform via Makefile
/usr/bin/make test-macos       # macOS tests
/usr/bin/make test-ios         # iOS Simulator
/usr/bin/make test-linux       # Linux (Docker)
/usr/bin/make test-all         # All platforms
```

### Debugging Tests

**Enable Verbose Output:**
```bash
swift test --verbose
```

**Reproduce Failed Test:**
```swift
// Use the seed from failure to reproduce:
let property = Property(..., config: PropertyConfig(seed: 12345))
```

**Run Specific Test:**
```bash
swift test --filter testPropertyName
```

---

## Code Style & Standards

### Overview

The project enforces strict code quality standards:

- **Warnings as Errors:** Zero warnings allowed
- **Coverage Target:** 99% code coverage required
- **Line Length:** 100 characters maximum
- **Indentation:** 2 spaces
- **Naming:** camelCase for variables/functions, PascalCase for types
- **Documentation:** All public APIs require DocC comments

### Swift Format Configuration (.swift-format)

```json
{
  "lineLength": 100,
  "indentation": { "spaces": 2 },
  "lineBreakBeforeEachArgument": true,
  "lineBreakBeforeEachGenericRequirement": true
}
```

**Auto-Formatting:**
```bash
swift-format -i --configuration .swift-format --recursive ./Sources ./Tests
```

### SwiftLint Rules (.swiftlint.yml)

Based on Google Swift Style Guide with 50+ opt-in rules:

**Readability Rules:**
- `closure_spacing`, `closure_end_indentation`
- `attributes`, `modifier_order`
- `implicit_return`, `fallthrough`

**Performance Rules:**
- `contains_over_filter_count`
- `sorted_first_last`
- `reduce_into`

**Style Rules:**
- `lower_acl_than_parent` (enforce access control)
- `type_contents_order` (organize type members)
- `vertical_whitespace_between_cases`

**Custom Rules:**
- `prefer_struct` – Prefer struct over class
- `no_print` – No print statements in production code

**Run Linting:**
```bash
swiftlint lint --strict              # Check only
swiftlint --fix                      # Auto-fix issues
```

### Documentation Standards

**Public API Documentation (Required)**

```swift
/// Generates random integers within a specified range.
///
/// - Parameter range: The range of integers to generate from
/// - Returns: A generator that produces integers in the given range
/// - Complexity: O(1)
public static func int(in range: ClosedRange<Int>) -> Gen<Int> {
  // Implementation
}
```

**Key Requirements:**
- All public APIs must have `///` documentation comments
- Include parameter descriptions and return value documentation
- Provide usage examples for complex APIs
- Document throwing errors if applicable
- Reference external resources for mathematical concepts

**Example Structure:**
```swift
/// <One-line summary>
///
/// <Detailed explanation if needed>
///
/// - Parameter paramName: Description
/// - Returns: Description
/// - Throws: Error types if applicable
///
/// # Example
/// ```swift
/// let value = someFunction(parameter: 42)
/// ```
public func someFunction(parameter: Int) -> Bool {
  // Implementation
}
```

### Commit Message Standards

Follow Conventional Commits 1.0.0:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat` – New feature
- `fix` – Bug fix
- `docs` – Documentation
- `style` – Formatting (swift-format, swiftlint)
- `refactor` – Code restructuring
- `perf` – Performance improvement
- `test` – Test additions/updates
- `build` – Build system changes
- `ci` – CI/CD changes
- `chore` – Maintenance tasks
- `revert` – Revert previous commit

**Scopes:**
- `api` – Public API changes
- `core` – Core functionality
- `generators` – Generator implementations
- `macros` – Macro implementations
- `coverage` – Coverage features
- `docs` – Documentation
- `tests` – Test changes
- `ci` – CI/CD changes

**Examples:**
```
feat(generators): add UUID generator for domain objects
fix(shrinking): prevent infinite loops in array shrinking
docs(readme): add async property testing examples
test(coverage): add tests for edge cases in shrinking
perf(generation): optimize numeric generator with caching
```

---

## Common Tasks

### Adding a New Generator

**Example: Custom Type Generator**

1. **Create the generator function:**

```swift
// In Sources/InvariantSwift/Generators/DomainGenerators.swift

/// Generates random User instances.
public static func user() -> Gen<User> {
  Gen.zip(Gen.string, Gen.int)
    .map { (name, age) in User(name: name, age: age) }
}
```

2. **Write comprehensive tests:**

```swift
// In Tests/FunctionalTesting/CollectionGeneratorTests.swift

@Test("User generator produces valid instances")
func testUserGeneratorValid() {
  let property = Property(generator: Gen.user()) { user in
    !user.name.isEmpty && user.age >= 0
  }

  try checkProperty(property, config: PropertyConfig(iterations: 1000))
}
```

3. **Update documentation:**
   - Add to README.md Generators section
   - Include usage example
   - Document any special behavior

4. **Verify coverage:**
```bash
swift test --enable-code-coverage
/usr/bin/make coverage  # Must reach 99%
```

### Writing a Property Test

**Example: Testing Array Operations**

```swift
@PropertyTest
func testArrayReverse(array: [Int]) {
  // Two properties about array reversal:
  #expect(array.reversed().reversed() == array)  // Identity
  #expect(array.reversed().count == array.count)  // Count preservation
}
```

**With Custom Configuration:**

```swift
@Test("Array properties")
func testArrayProperties() {
  let property = Property<[Int]>(
    generator: Gen.array(Gen.int(in: -100...100))
  ) { array in
    array.reversed().reversed() == array
  }

  let config = PropertyConfig(
    iterations: 10000,
    maxSize: 1000,
    maxShrinks: 5000,
    seed: 42  // For reproducibility
  )

  try checkProperty(property, config: config)
}
```

### Creating a Model-Based Test

**Example: Testing a Stack Implementation**

```swift
struct StackCommand {
  enum Operation {
    case push(Int)
    case pop
    case peek
  }

  let operation: Operation

  func executeOnModel(_ model: inout [Int]) -> Int? {
    switch operation {
    case .push(let value):
      model.append(value)
      return nil
    case .pop:
      return model.popLast()
    case .peek:
      return model.last
    }
  }

  func executeOnImpl(_ impl: inout Stack<Int>) -> Int? {
    switch operation {
    case .push(let value):
      impl.push(value)
      return nil
    case .pop:
      return impl.pop()
    case .peek:
      return impl.peek()
    }
  }
}

@Test("Stack model-based test")
func testStack() {
  let commands = Gen.array(
    Gen.oneOf(
      Gen.int.map(StackCommand.Operation.push),
      Gen.pure(.pop),
      Gen.pure(.peek)
    ).map { StackCommand(operation: $0) }
  )

  let property = Property(generator: commands) { commands in
    var model: [Int] = []
    var impl = Stack<Int>()

    for command in commands {
      let modelResult = command.executeOnModel(&model)
      let implResult = command.executeOnImpl(&impl)

      guard modelResult == implResult else { return false }
    }

    return true
  }

  try checkProperty(property)
}
```

### Running Performance Benchmarks

```bash
# Run performance tests only
swift test --filter PerformanceTests

# Benchmark generation speed
# Expected: 10,000+ generations/second for primitive types
```

### Updating Dependencies

```bash
# Resolve dependencies
swift package update

# Review changes to Package.resolved
git diff Package.resolved

# Test with new versions
swift test | xcbeautify

# Commit updates
git commit -m "build(deps): update swift-syntax to X.Y.Z"
```

### Generating Documentation

```bash
# Generate DocC documentation
swift package generate-documentation

# View generated docs (build outputs to .build/)
open .build/documentation/InvariantSwift/InvariantSwift.doccarchive

# For CI/CD: documentation.yml workflow handles this
```

---

## Architecture Decisions

### Core Architectural Patterns

**1. Protocol-Witness Pattern**

The framework uses protocol-witness design for `Gen<T>`:

```swift
public struct Gen<T> {
  // Witness: the generate function
  private let _generate: (inout Seed) -> T

  public func generate(_ rng: inout Seed) -> T {
    _generate(&rng)
  }
}
```

**Rationale:**
- Type-safe abstraction without inheritance overhead
- Composable through protocol conformance
- Supports functor/applicative/monad operations

**2. Functor/Applicative/Monad Hierarchy**

```swift
// Gen<T> implements:
// - Functor: map (_ -> _)
// - Applicative: zip, apply
// - Monad: flatMap (>>=)
// - Plus: oneOf (multiple alternatives)
```

**Rationale:**
- Standard functional programming patterns
- Enables compositional generator design
- Verifiable through mathematical law tests

**3. Actor-Based Concurrency**

```swift
actor PropertyRunner {
  nonisolated let config: PropertyConfig

  func run<T>(_ property: Property<T>) async -> PropertyResult<T>
}
```

**Rationale:**
- Swift 6 strict concurrency compliance
- Thread-safe parallel test execution
- No data races or race conditions

**4. Coalgebraic Shrinking**

Shrinking represents destructive operations on values:

```swift
struct Shrink<T> {
  let shrink: (T) -> [T]  // Generate smaller candidates
}
```

**Rationale:**
- Finds minimal counterexamples efficiently
- Represents all possible simplifications
- Lazy evaluation reduces memory usage

**5. Coverage-Guided Generation**

```swift
class CoverageGuided {
  // Track executed paths during property tests
  // Bias future generation toward uncovered branches
  // Target: 99% code coverage automatically
}
```

**Rationale:**
- Focuses property test generation on unexercised code
- Achieves high coverage automatically
- DICE algorithm for distributed coverage

### Design Decisions

**Why Property-Based Testing?**

Traditional property testing finds bugs that unit tests miss by:
- Generating thousands of test cases automatically
- Exploring edge cases systematically
- Providing minimal failing examples through shrinking

**Why Macros for Test Generation?**

The `@PropertyTest` macro eliminates boilerplate by:
- Inferring generator types from function parameters
- Automating property runner configuration
- Reducing test code by 70%+

**Why Model-Based Testing?**

For stateful systems (queues, stacks, caches), model-based testing:
- Compares implementation against simple model
- Detects state invariant violations
- Finds complex interaction bugs

**Why Coverage-Guided Generation?**

Automatic coverage targeting ensures:
- All code paths are exercised
- Adaptive generation finds untested branches
- Achieves 99% coverage goal systematically

---

## Troubleshooting

### Common Setup Issues

**Issue: `swift test` fails with "Module not found"**

```
error: <module>: No such module
```

**Solution:**
```bash
# Ensure dependencies are resolved
swift package resolve
swift package update

# Clean build artifacts
swift package clean
rm -rf .build

# Try again
swift test | xcbeautify
```

**Issue: Pre-commit hooks fail on first install**

```
error: swift-format: command not found
```

**Solution:**
```bash
# Install missing tools
/usr/bin/make setup

# Or manually:
brew install swiftlint swift-format xcbeautify

# Test hooks:
pre-commit run --all-files
```

**Issue: SwiftLint conflicts with swift-format**

```
error: file has violations and -fix is not specified
```

**Solution:**
```bash
# Run both in sequence:
swift-format -i --configuration .swift-format --recursive ./Sources ./Tests
swiftlint --fix

# Or use Makefile:
/usr/bin/make format
```

### Common Development Issues

**Issue: Tests timeout**

```
error: fatal timeout after 300 seconds
```

**Solution:**
```swift
// Increase timeout in config:
let config = PropertyConfig(
  timeout: 600.0  // Increase from default 30
)

// Or check for infinite loops in property predicates
```

**Issue: Coverage fails at 98.5%**

```
error: coverage 98.5% is below target 99%
```

**Solution:**
```bash
# Generate coverage report to find uncovered lines
/usr/bin/make coverage

# Add tests for uncovered branches
# Coverage report shows exact lines in .build/

# Verify coverage after adding tests:
swift test --enable-code-coverage
```

**Issue: Shrinking produces large counterexamples**

```
// Shrinking stops early instead of finding minimal example
```

**Solution:**
```swift
// Increase max shrinks in config:
let config = PropertyConfig(
  maxShrinks: 5000  // Increase from default 1000
)
```

### Platform-Specific Issues

**Issue: iOS/tvOS tests fail with "No simulator available"**

```bash
# List available simulators:
xcrun simctl list devices available

# Select specific simulator in Makefile or use:
xcodebuild test -scheme InvariantSwift \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest'
```

**Issue: Linux tests fail in Docker**

```bash
# Run Linux tests directly:
/usr/bin/make test-linux

# Or manually:
docker run --rm -v "$(PWD):$(PWD)" -w "$(PWD)" swift:6.0-jammy swift test
```

---

## Resources

### Documentation

**Official Project Docs**
- `README.md` – Project overview and quick start
- `CONTRIBUTING.md` – Contribution guidelines
- `CODE_OF_CONDUCT.md` – Community standards
- `SECURITY.md` – Security policy
- `docs/architecture/` – Architecture documentation

**Generated Documentation**
```bash
swift package generate-documentation
open .build/documentation/InvariantSwift/InvariantSwift.doccarchive
```

### External References

**Swift Resources**
- [Swift 6.0 Language Guide](https://docs.swift.org/swift-book/6.0/introduction)
- [Swift Testing Framework](https://developer.apple.com/documentation/testing)
- [SwiftSyntax Documentation](https://github.com/swiftlang/swift-syntax)

**Property-Based Testing**
- [QuickCheck (Haskell)](https://hackage.haskell.org/package/QuickCheck)
- [Hypothesis (Python)](https://hypothesis.readthedocs.io/)
- [Property-Based Testing (Wikipedia)](https://en.wikipedia.org/wiki/Property-based_testing)

**Category Theory & Functional Programming**
- [Functor Laws](https://wiki.haskell.org/Functor)
- [Monad Laws](https://wiki.haskell.org/Monad_laws)
- [Lens (Optics)](https://github.com/ekmett/lens)

### Key Files to Review

1. **Start Here:** `README.md` (overview) → `CONTRIBUTING.md` (workflow)
2. **Core Concepts:** `Sources/InvariantSwift/FunctionalTesting.swift` (public API)
3. **Implementation:** `Sources/InvariantSwift/Core/` (fundamental types)
4. **Testing:** `Tests/FunctionalTesting/PropertyTests.swift` (test patterns)
5. **Architecture:** `docs/architecture/InvariantSwift-architecture.md`

### Getting Help

- **GitHub Issues** – Report bugs or request features
- **GitHub Discussions** – Ask questions and share ideas
- **Code Review** – Submit a PR and get feedback
- **Local Testing** – Run full test suite and check logs

---

## Next Steps

**For New Contributors:**

1. ✅ Complete Getting Started setup
2. ✅ Read this entire onboarding guide
3. ✅ Review `CONTRIBUTING.md` for PR process
4. ✅ Explore examples in `Examples/` directory
5. ✅ Pick a good first issue (labeled "good first issue")
6. ✅ Create a feature branch and make a contribution
7. ✅ Submit a pull request

**Recommended Reading Order:**

1. This document (you are here)
2. `README.md` – Feature overview
3. `CONTRIBUTING.md` – Development process
4. `docs/architecture/InvariantSwift-architecture.md` – Architecture details
5. `Sources/InvariantSwift/Core/Generator.swift` – Core types
6. Example code in `Examples/` directory
7. Test files in `Tests/FunctionalTesting/` – Testing patterns

**First Contribution Suggestions:**

- **Easy:** Add a new primitive generator (e.g., `UUID`, `Date`)
- **Medium:** Add property tests for existing generators
- **Medium:** Improve documentation or examples
- **Hard:** Implement new advanced feature (coverage tracking, invariant mining)

---

## Summary

You now have everything needed to:

- ✅ Set up your development environment
- ✅ Understand the project structure
- ✅ Follow the development workflow
- ✅ Write tests and implement features
- ✅ Contribute to the project
- ✅ Debug issues and troubleshoot problems

Welcome to the InvariantSwift community! We're excited to have you contribute.

If you have questions, open an issue or start a discussion on GitHub. Happy testing! 🚀
