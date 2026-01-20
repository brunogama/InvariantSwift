# InvariantSwift Developer Onboarding Guide

> **Comprehensive onboarding for a senior developer joining this project**

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [Getting Started](#3-getting-started)
4. [Key Components](#4-key-components)
5. [Development Workflow](#5-development-workflow)
6. [Architecture Decisions](#6-architecture-decisions)
7. [Common Tasks](#7-common-tasks)
8. [Potential Gotchas](#8-potential-gotchas)
9. [Documentation and Resources](#9-documentation-and-resources)
10. [Next Steps](#10-next-steps)

---

## 1. Project Overview

### Project Name & Purpose

**InvariantSwift** is a **production-grade property-based testing framework** for Swift that:

- Generates test cases automatically from property specifications
- Finds edge cases through intelligent shrinking and counterexample minimization
- Verifies mathematical laws for functional programming patterns
- Integrates natively with Apple's Swift Testing framework

### Tech Stack

| Layer | Technology | Version |
|-------|------------|---------|
| **Language** | Swift | 6.0+ (strict concurrency) |
| **IDE** | Xcode | 16.0+ |
| **Test Framework** | Swift Testing | Latest |
| **Metaprogramming** | SwiftSyntax | 600.0.1–700.0.0 |
| **Build Tool** | Swift Package Manager | 6.1+ |

### Architecture Pattern

The framework follows a **functional programming architecture** with:

- **Protocol-Witness Pattern** for type-safe generator abstraction
- **Functor/Applicative/Monad Hierarchy** for composable generators
- **Actor-Based Concurrency** for thread-safe parallel execution
- **Coalgebraic Shrinking** for counterexample minimization

### Key Dependencies

| Dependency | Version | Type | Purpose |
|------------|---------|------|---------|
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | 600.0.1+ | Build | Macro implementations (`@PropertyTest`, `@Arbitrary`, etc.) |
| [swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump) | 1.3.3+ | Runtime | Pretty-printing and diff-based assertions |

**Dev Tools** (not package dependencies):

| Tool | Purpose | Installation |
|------|---------|--------------|
| SwiftLint | Code linting | `brew install swiftlint` |
| swift-format | Code formatting | `brew install swift-format` |
| xcbeautify | Test output formatting | `brew install xcbeautify` |
| pre-commit | Git hooks | `pip install pre-commit` |

### Platform Support

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 17.0+ |
| macOS | 14.0+ |
| tvOS | 17.0+ |
| watchOS | 10.0+ |
| macCatalyst | 17.0+ |
| Linux | Swift 6.0+ distributions |

---

## 2. Repository Structure

### Top-Level Directories

```
InvariantSwift/
├── Sources/                      # All source code
│   ├── InvariantSwift/          # Main library (17 subdirectories)
│   ├── InvariantSwiftMacros/    # SwiftSyntax macro implementations
│   ├── GhostwriterCLI/          # Auto-test generation CLI
│   └── FuncTestCLI/             # Property testing CLI
├── Tests/                        # Test suites
│   ├── FunctionalTesting/       # Core library tests (49 files)
│   ├── InvariantSwiftMacroTests/# Macro expansion tests (13 files)
│   ├── CoverageIntegrationTests/# Coverage validation (4 files)
│   ├── PerformanceTests/        # Benchmarks (1 file)
│   └── Generated/               # Auto-generated tests (1 file)
├── Plugins/                      # SPM plugins
│   ├── InvariantSwiftPlugin/    # `swift package invariant`
│   └── GhostwriterPlugin/       # `swift package ghostwrite`
├── Scripts/                      # Build/utility scripts (Python, Bash)
├── docs/                         # Documentation (20+ files)
│   ├── proposals/               # ISP proposals (10 files)
│   ├── architecture/            # Architecture docs (22 files)
│   └── examples/                # Usage examples
└── .github/workflows/            # CI/CD pipelines (6 workflows)
```

### Source Code Organization (`Sources/InvariantSwift/`)

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| **Core/** | Fundamental types | `Generator.swift`, `Property.swift`, `Seed.swift`, `ModelTesting.swift` |
| **Generators/** | Data generation | `NumericGenerators.swift`, `CollectionGenerators.swift`, `CombinatorGenerators.swift` |
| **Advanced/** | Specialized testing | `CoverageGuided.swift`, `LensSystem.swift`, `Linearizability.swift`, `Metamorphic.swift` |
| **Faker/** | Realistic data | `FakerGenerator.swift`, `FakerLocale.swift`, `FakerData.swift` |
| **Fuzzing/** | LibFuzzer integration | `LibFuzzerIntegration.swift` |
| **Contract/** | Contract testing | `ContractTesting.swift` |
| **Persistence/** | Failure banking | `RegressionBank.swift` |
| **SwiftTesting/** | Framework integration | Property-test support for Swift Testing |
| **Macros/** | Macro declarations | `@PropertyTest`, `@Arbitrary`, `@BusinessRule` |

### Non-Standard Patterns

- **AGENTS.md files**: Hierarchical documentation for AI coding agents in `Sources/`, `Tests/`, `Plugins/`, `docs/`
- **CLAUDE.md files**: Claude Code-specific context files in source directories
- **`.disabled` files**: Files excluded from build (e.g., `LawGeneration.swift.disabled`)

---

## 3. Getting Started

### Prerequisites

**Required:**
- Swift 6.0+ (`swift --version`)
- Xcode 16.0+ (macOS) or Swift toolchain (Linux)
- Git

**Recommended:**
- Homebrew (macOS package manager)
- Docker (for Linux testing)
- Python 3.x (for scripts and pre-commit)

### Step-by-Step Setup

#### 1. Clone the Repository

```bash
git clone https://github.com/brunogama/InvariantSwift.git
cd InvariantSwift
```

#### 2. Install Development Dependencies

```bash
# macOS (via Makefile)
make setup

# Or manually:
brew install swiftlint swift-format xcbeautify
pip install pre-commit
```

#### 3. Resolve Package Dependencies

```bash
swift package resolve
```

#### 4. Install Git Hooks (Recommended)

```bash
pre-commit install
pre-commit run --all-files  # Verify hooks work
```

#### 5. Build the Project

```bash
swift build
# Or with warnings-as-errors (CI standard):
swift build -Xswiftc -warnings-as-errors
```

#### 6. Run Tests

```bash
# All tests with formatted output
swift test | xcbeautify

# Or via Makefile
make test-swift
```

#### 7. Verify Linting

```bash
swiftlint lint --strict
```

### Common Setup Issues

| Issue | Solution |
|-------|----------|
| `Module not found` error | `swift package clean && rm -rf .build && swift package resolve` |
| `swift-format: command not found` | `brew install swift-format` |
| Pre-commit hooks fail | `make setup` to install missing tools |
| Xcode build fails | Ensure Xcode 16.0+ is selected: `xcode-select -p` |

### Environment Configuration

No `.env` files or secrets are required for local development. All configuration is in:

- **Package.swift** – Dependencies and targets
- **.swiftlint.yml** – Linting rules
- **.swift-format** – Formatting config
- **.pre-commit-config.yaml** – Git hooks

---

## 4. Key Components

### Entry Points

| Entry Point | Purpose | Location |
|-------------|---------|----------|
| `FunctionalTesting.swift` | Main library public API | `Sources/InvariantSwift/` |
| `main.swift` | CLI entry point | `Sources/FuncTestCLI/` |
| `GhostwriterCLI.swift` | Test generation CLI | `Sources/GhostwriterCLI/` |
| `plugin.swift` | SPM plugin entry | `Plugins/InvariantSwiftPlugin/` |

### Core Business Logic

**Generator System** (`Sources/InvariantSwift/Core/Generator.swift`):

```swift
public struct Gen<T>: Sendable {
  public func generate(_ rng: inout some RandomNumberGenerator, _ size: Int) -> T
  
  // Functor
  func map<U>(_ f: @escaping (T) -> U) -> Gen<U>
  
  // Applicative
  static func zip<A, B>(_ a: Gen<A>, _ b: Gen<B>) -> Gen<(A, B)>
  
  // Monad
  func flatMap<U>(_ f: @escaping (T) -> Gen<U>) -> Gen<U>
}
```

**Property Testing** (`Sources/InvariantSwift/Core/Property.swift`):

```swift
public struct Property<T> {
  let generator: Gen<T>
  let predicate: (T) -> Bool
}

public func checkProperty<T>(_ property: Property<T>, config: PropertyConfig) throws
```

### Database Models/Schemas

The framework includes:

- **CorpusDatabase** (`Database/CorpusDatabase.swift`) – SQLite-based test corpus storage
- **RegressionBank** (`Persistence/RegressionBank.swift`) – Failed test case persistence

### API/Route Definitions

This is a library, not a web service. Key public APIs are in `FunctionalTesting.swift`.

### Configuration Management

Configuration is handled through:

- **PropertyConfig** – Test execution settings (iterations, seed, timeout)
- **PrettyConfig** – Output formatting settings
- **Package.swift** – Build-time settings (warnings-as-errors, strict concurrency)

### External Service Integration

| Integration | Purpose | Location |
|-------------|---------|----------|
| Swift Testing | Test framework | `SwiftTesting/` |
| LLVM Coverage | Code coverage analysis | `Coverage/`, `Scripts/` |
| Codecov | CI coverage reporting | `.github/workflows/ci.yml` |

---

## 5. Development Workflow

### Git Branch Naming

```
feat/description     # New features
fix/description      # Bug fixes
docs/description     # Documentation
refactor/description # Code restructuring
test/description     # Test additions
chore/description    # Maintenance
```

### Commit Message Format

Follow [Conventional Commits](https://conventionalcommits.org):

```
type(scope): description

[optional body]

[optional footer]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`

**Scopes:** `api`, `core`, `generators`, `macros`, `coverage`, `tests`, `ci`

**Examples:**
```bash
git commit -m "feat(generators): add UUID generator"
git commit -m "fix(shrinking): handle empty arrays correctly"
git commit -m "docs(readme): update installation instructions"
```

### Testing Requirements

| Test Type | Required | Location |
|-----------|----------|----------|
| Unit tests | Yes | `Tests/FunctionalTesting/` |
| Property tests | Preferred | Use `@PropertyTest` macro |
| Macro tests | For macros | `Tests/InvariantSwiftMacroTests/` |
| Integration tests | For features | `Tests/CoverageIntegrationTests/` |

**Coverage Target:** 99%+ (enforced by pre-commit hooks)

### Code Style & Linting

| Tool | Config | Command |
|------|--------|---------|
| SwiftLint | `.swiftlint.yml` | `swiftlint lint --strict` |
| swift-format | `.swift-format` | `swift-format -i --recursive ./Sources ./Tests` |

**Key Rules:**
- 2-space indentation
- 100-character line length
- No `print` statements in production code
- All public APIs require DocC comments

### PR Process

1. Create feature branch from `main`
2. Make changes, commit with conventional commits
3. Push and create PR
4. CI checks must pass (tests, lint, format, coverage)
5. Request review
6. Squash and merge

### CI/CD Pipeline

| Workflow | Trigger | Actions |
|----------|---------|---------|
| `ci.yml` | Push/PR | Linux tests, macOS/iOS/tvOS tests, lint, format, coverage |
| `docs-check.yml` | Push/PR | Documentation validation |
| `format.yml` | Push | Format checking |
| `release.yml` | Tag | Release automation |
| `mutation-testing.yml` | Manual | Mutation testing |

### Release Strategy

- **Semantic Versioning** (MAJOR.MINOR.PATCH)
- **CHANGELOG.md** updated for all changes
- **Git tags** trigger releases

---

## 6. Architecture Decisions

### Design Patterns

| Pattern | Usage | Rationale |
|---------|-------|-----------|
| **Protocol-Witness** | `Gen<T>` structure | Type-safe abstraction without inheritance |
| **Functor/Monad** | Generator composition | Standard FP patterns, enables law testing |
| **Actor Isolation** | `PropertyRunner` | Swift 6 concurrency compliance |
| **Builder Pattern** | `PropertyConfig` | Fluent configuration API |

### State Management

- **Immutable generators** – All `Gen<T>` instances are value types
- **Seed-based RNG** – Deterministic, reproducible randomness
- **Actor isolation** – Thread-safe property execution

### Error Handling

```swift
public enum PropertyResult<T> {
  case success(iterations: Int)
  case failure(counterexample: T, shrunk: T, iterations: Int, seed: UInt64)
  case gaveUp(reason: String, iterations: Int)
}
```

- Results include all context for debugging
- No throwing in generators (invalid inputs filtered via `suchThat`)
- Graceful degradation with `gaveUp`

### Logging & Monitoring

- **TelemetrySystem** (`Observability/TelemetrySystem.swift`) – Optional observability
- **Verbosity levels** in `PropertyConfig` (`.silent`, `.normal`, `.verbose`)
- No external logging dependencies

### Security Measures

- No secret/credential handling (testing library)
- No network requests in library code
- Sandbox-safe design for iOS/macOS

### Performance Optimizations

| Optimization | Implementation |
|--------------|----------------|
| Lazy evaluation | Generators don't produce until `generate()` called |
| Shrinking pruning | Tree-based shrinking with early termination |
| Parallel execution | Actor-based concurrent test runs |
| Minimal allocations | Value types for core abstractions |

---

## 7. Common Tasks

### Adding a New Generator

```swift
// 1. In Sources/InvariantSwift/Generators/DomainGenerators.swift
public static func uuid() -> Gen<UUID> {
  Gen { rng, _ in UUID() }
}

// 2. Add tests in Tests/FunctionalTesting/
@Test("UUID generator produces valid UUIDs")
func testUUIDGenerator() throws {
  let property = Property(generator: Gen.uuid()) { uuid in
    uuid.uuidString.count == 36
  }
  try checkProperty(property)
}

// 3. Update documentation in docs/GENERATORS.md
```

### Creating a New Database Model

This library doesn't use traditional database models. For test corpus storage, extend `CorpusDatabase`:

```swift
// In Sources/InvariantSwift/Database/
actor CustomStorage {
  func save(_ item: MyType) async throws
  func load() async throws -> [MyType]
}
```

### Writing a Property Test

```swift
import Testing
import InvariantSwift

// Using @PropertyTest macro (recommended)
@PropertyTest
func testAdditionCommutative(a: Int, b: Int) {
  #expect(a + b == b + a)
}

// Manual property construction
@Test
func testArrayReversal() throws {
  let property = Property(generator: Gen.array(Gen<Int>.int)) { array in
    array.reversed().reversed() == Array(array)
  }
  try checkProperty(property, config: PropertyConfig(iterations: 1000))
}
```

### Debugging Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Property gave up" | Too many filtered values | Relax `suchThat` constraints or increase `maxTries` |
| "Shrinking timed out" | Complex counterexample | Increase `maxShrinks` in config |
| Test timeout | Slow predicate | Optimize predicate or increase `timeout` |
| Non-deterministic failure | Async side effects | Use fixed seed: `PropertyConfig(seed: 42)` |

### Updating Dependencies

```bash
swift package update
git diff Package.resolved  # Review changes
swift test | xcbeautify    # Verify tests pass
git commit -m "build(deps): update dependencies"
```

### Running Migrations/Schema Updates

Not applicable – this is a testing library without persistent schemas.

---

## 8. Potential Gotchas

### Hidden/Non-Obvious Configs

| Config | Location | Notes |
|--------|----------|-------|
| Warnings-as-errors | `Package.swift` line 8 | Build fails on any warning |
| Strict concurrency | `Package.swift` line 9-10 | Swift 6 compliance enforced |
| 99% coverage target | Pre-commit hooks | Commits blocked if coverage drops |
| Excluded files | `Package.swift` exclude arrays | Some `.swift` files are intentionally excluded |

### Required Environment Variables

None required. All configuration is file-based.

### External Service Dependencies

| Service | When Used | Fallback |
|---------|-----------|----------|
| GitHub Actions | CI/CD | Can run locally with `make` |
| Codecov | Coverage reporting | Local coverage works without it |
| Docker | Linux testing | Optional, only for cross-platform testing |

### Known Bugs/Edge Cases

| Issue | Workaround |
|-------|------------|
| macOS beta SDK SIGTRAP | Use `make test-safe` with crash protection |
| Large array shrinking | Increase `maxShrinks` or implement custom shrink |
| SwiftSyntax version conflicts | Ensure swift-syntax version matches Swift toolchain |

### Performance Bottlenecks

- **Macro expansion** – First build is slow due to swift-syntax compilation
- **Large generators** – Arrays/sets with many elements are slow to shrink
- **Coverage-guided mode** – Adds overhead for branch tracking

### Technical Debt Hotspots

| File/Area | Issue | Priority |
|-----------|-------|----------|
| `Sources/InvariantSwift/Advanced/` | Complex subsystems with limited tests | Medium |
| Macro error messages | Could be more descriptive | Low |
| Documentation examples | Some use deprecated APIs | Medium |

---

## 9. Documentation and Resources

### Internal Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| [README.md](../README.md) | Root | Project overview |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | Root | Contribution guidelines |
| [GENERATORS.md](GENERATORS.md) | docs/ | Generator reference |
| [MACROS.md](MACROS.md) | docs/ | Macro documentation |
| [ADVANCED.md](ADVANCED.md) | docs/ | Advanced features |
| [COOKBOOK.md](COOKBOOK.md) | docs/ | Usage recipes |
| [SHRINKING.md](SHRINKING.md) | docs/ | Shrinking guide |
| [FUZZING.md](FUZZING.md) | docs/ | LibFuzzer integration |
| [API_REFERENCE_GENERATED.md](API_REFERENCE_GENERATED.md) | docs/ | Full API reference |

### Architecture Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| Architecture sections | `docs/architecture/` | 22 detailed architecture files |
| Proposals | `docs/proposals/` | ISP-0001 through ISP-0010 |

### External Resources

| Resource | URL | Purpose |
|----------|-----|---------|
| Swift 6 Language Guide | [docs.swift.org](https://docs.swift.org/swift-book/) | Language reference |
| Swift Testing | [Apple Developer](https://developer.apple.com/documentation/testing) | Test framework docs |
| SwiftSyntax | [GitHub](https://github.com/swiftlang/swift-syntax) | Macro implementation |
| QuickCheck (Haskell) | [Hackage](https://hackage.haskell.org/package/QuickCheck) | Original PBT library |
| Hypothesis (Python) | [ReadTheDocs](https://hypothesis.readthedocs.io/) | Coverage-guided inspiration |

### Style Guides

- **Code Style:** Google Swift Style Guide (via SwiftLint)
- **Documentation:** DocC format with required sections for all public APIs
- **Commits:** Conventional Commits 1.0.0

---

## 10. Next Steps

### Onboarding Checklist

1. [ ] **Set up development environment**
   - Clone repository
   - Install dependencies (`make setup`)
   - Install pre-commit hooks
   
2. [ ] **Run the project locally**
   - Build: `swift build`
   - Test: `swift test | xcbeautify`
   - Lint: `swiftlint lint`

3. [ ] **Make a test change**
   - Create a branch: `git checkout -b feat/test-change`
   - Modify a test file
   - Commit and verify hooks pass

4. [ ] **Run the full test suite**
   - `make test-swift` (SPM tests)
   - `make test-macos` (Xcode tests)
   - `make lint` (linting)

5. [ ] **Walk through the main user flow**
   - Open `Tests/FunctionalTesting/PropertyTests.swift`
   - Review `@PropertyTest` macro usage
   - Trace through `Gen<T>` → `Property<T>` → `checkProperty()`

6. [ ] **Select a small area for first contribution**
   - Check GitHub issues labeled "good first issue"
   - Consider: add a new generator, improve documentation, add test coverage

### First Contribution Ideas

| Difficulty | Task |
|------------|------|
| Easy | Add documentation to an undocumented public API |
| Easy | Add test coverage for an edge case |
| Medium | Implement a new primitive generator (e.g., `Gen.ipAddress()`) |
| Medium | Improve error messages in macro expansion |
| Hard | Add a new shrinking strategy |

### Key Files to Explore First

1. `Sources/InvariantSwift/FunctionalTesting.swift` – Public API surface
2. `Sources/InvariantSwift/Core/Generator.swift` – Core abstraction
3. `Sources/InvariantSwift/Core/Property.swift` – Test specification
4. `Tests/FunctionalTesting/PropertyTests.swift` – Test patterns
5. `Sources/InvariantSwiftMacros/PropertyMacro/` – Macro implementation

---

## Summary

You now have everything needed to contribute to InvariantSwift:

- ✅ Environment setup with all necessary tools
- ✅ Understanding of project structure and architecture
- ✅ Development workflow with CI/CD integration
- ✅ Common tasks and troubleshooting guides
- ✅ Resources for deeper learning

Welcome to the InvariantSwift team! 🚀

Questions? Open a GitHub issue or check CONTRIBUTING.md for guidance.
