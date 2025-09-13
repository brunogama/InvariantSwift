# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: FunctionalTesting

A comprehensive property-based testing framework for Swift 6 with category theory principles, macro-based test generation, and 99% coverage requirements.

## Essential Commands

### Testing & Validation
```bash
# Run tests with beautified output (ALWAYS use this)
swift test | xcbeautify

# Run specific test
swift test --filter testFunctionName

# Full validation (lint + test) - RUN BEFORE ANY COMMIT
make validate

# Coverage report generation
make coverage

# Platform-specific testing
make test-swift    # SPM testing
make test-macos    # macOS platform
make test-ios      # iOS Simulator
```

### Code Quality
```bash
# Lint with strict mode (MUST pass with zero warnings)
swiftlint lint --strict

# Format code (2-space indent, 100 char limit)
swift-format -i --configuration .swift-format --recursive ./Sources ./Tests
```

### Build & Documentation
```bash
# Build all targets
swift build

# Generate DocC documentation
swift package generate-documentation

# Run CLI tool
swift run functest --help
swift run functest --coverage --iterations 1000
```

## High-Level Architecture

### Core Design Principles
The framework is built on **mathematical foundations**:
- **Protocol-Witness Pattern**: All core abstractions use protocol witnesses for type safety and composability
- **Category Theory**: Functors, Applicatives, and Monads provide the theoretical foundation for generators
- **Coverage-Guided Generation**: Intelligent test case generation biased toward uncovered code paths
- **Macro-Driven Testing**: SwiftSyntax macros enable compile-time test generation from function signatures

### Key Architectural Components

#### 1. Generator System (`Sources/FunctionalTesting/Core/Generator.swift`)
- Built as a monad with `map`, `flatMap`, and `pure` operations
- Deterministic generation via `Seed` and `RandomNumberGenerator`
- Composable through functor and applicative operations
- Size-based generation for controlled complexity growth

#### 2. Property Testing Engine (`Sources/FunctionalTesting/Core/Property.swift`)
- Executes properties with configurable iterations and timeouts
- Automatic shrinking to find minimal counterexamples
- Async/await support for concurrent property testing
- Integration with Swift Testing framework

#### 3. Macro System (`Sources/FunctionalTestingMacros/`)
- `@PropertyTest`: Generates test functions from signatures
- `@BusinessRule`: Validates business logic invariants
- SwiftSyntax AST manipulation for code generation
- **CRITICAL**: Macro expansions use SwiftSyntax AST, not raw strings

#### 4. Coverage Tracking (`Sources/FunctionalTesting/Coverage/`)
- Real-time coverage analysis during test execution
- Symbol-based tracking for targeted testing
- Integration with LLVM coverage tools
- Bayesian optimization for uncovered path targeting

### Cross-Module Dependencies
```
FunctionalTesting (main library)
    ├── depends on → FunctionalTestingMacros (compile-time generation)
    └── integrates with → Swift Testing Framework

FuncTestCLI (command-line tool)
    └── depends on → FunctionalTesting + CustomDump

FuncTestPlugin (SPM plugin)
    └── executes → FuncTestCLI
```

## Critical Requirements

### Coverage Standards
- **99% minimum coverage** for all production code
- **100% coverage** for dog food tests (framework testing itself)
- Coverage failures block merges - NO EXCEPTIONS

### Code Quality Rules
- **Zero warnings policy**: Code must compile without any warnings
- **Macro annotations**: Always on separate lines from declarations
- **Documentation**: All public APIs require `///` DocC comments
- **Mathematical concepts**: Must include law verification and external references

### Testing Patterns
```swift
// ALWAYS use @PropertyTest macro for property-based tests
@PropertyTest
func testProperty(input: Type) {
    #expect(invariant(input))
}

// Mathematical laws MUST be verified
@PropertyTest
func testFunctorIdentity<T>(value: T?) {
    #expect(value.map { $0 } == value)  // Identity law
}

// Coverage-guided testing for complex paths
let (result, coverage) = await runner.runPropertyWithCoverageTracking(
    property,
    knownSymbols: ["targetFunction"]
)
```

## Current Development Context

### Active Branch: `epic/no-math-macros`
- Refactoring macro system to handle edge cases
- Focus on `MacroEdgeCaseTests.swift`
- Multiple uncommitted changes in macro implementations

### Known Issues
- Macro edge cases being addressed
- Some generators need modernization
- Documentation gaps in advanced features

## Workflow Integration

### Pre-Commit Checklist
1. Run `make validate` - MUST pass
2. Check coverage meets 99% threshold
3. Ensure zero compiler warnings
4. Update CHANGELOG.md for any changes
5. Verify DocC comments for new public APIs

### When Adding Features
1. Write property tests using `@PropertyTest`
2. Verify mathematical laws if applicable
3. Add coverage tracking for complex logic
4. Document with examples and references
5. Update dog food tests to cover new functionality

## Performance Expectations
- **10,000+ generations/second** for primitive types
- **Linear scaling** with CPU cores
- **Sub-100ms shrinking** for typical failures
- **~10% overhead** for coverage tracking

## Special Considerations

### SwiftSyntax Macro Development
- Use AST manipulation, never string concatenation
- Test macro expansions thoroughly
- Handle all edge cases in macro diagnostics
- Verify generated code compiles without warnings

### Mathematical Verification
- Implement law tests for all algebraic structures
- Include Wikipedia/academic references
- Document mathematical foundations in detail
- Use property-based testing to verify laws hold

### Dog Food Testing
- Framework must test itself with 100% coverage
- Update dog food tests when adding any feature
- Use coverage integration tests to validate

## Quick Reference

### File Locations
- **Generators**: `Sources/FunctionalTesting/Generators/`
- **Macros**: `Sources/FunctionalTestingMacros/`
- **Tests**: `Tests/FunctionalTestingTests/`
- **Coverage Tests**: `Tests/CoverageIntegrationTests/`
- **CLI**: `Sources/FuncTestCLI/main.swift`

### Common Tasks
- **Add generator**: Create in Generators/, add tests, document laws
- **Fix macro issue**: Check MacroEdgeCaseTests, use SwiftSyntax AST
- **Improve coverage**: Run coverage report, add targeted tests
- **Debug shrinking**: Enable verbose output in PropertyConfig

---

# Archon Integration (Task Management)

**CRITICAL**: Use Archon MCP server as PRIMARY task management system. TodoWrite is secondary only.

## Task Workflow
1. Check current task: `mcp__archon__get_task(task_id="...")`
2. Update to doing: `mcp__archon__update_task(task_id="...", status="doing")`
3. Research if needed: `mcp__archon__perform_rag_query(query="...")`
4. Implement based on research
5. Update to review: `mcp__archon__update_task(task_id="...", status="review")`
6. Get next task: `mcp__archon__list_tasks(filter_by="status", filter_value="todo")`

## Status Progression
`todo` → `doing` → `review` → `done`

---

# Development Method: RIPER

Follow the RIPER method for all development:

1. **Research**: Analyze requirements, codebase, constraints
2. **Identify**: Map dependencies, constraints, integration points
3. **Plan**: Design implementation strategy with milestones
4. **Execute**: Implement following standards and patterns
5. **Review**: Validate implementation, performance, coverage

---

# Critical Reminders

**NEVER**:
- Commit code with warnings
- Skip tests or coverage requirements
- Use raw strings in macro expansions
- Downgrade existing functionality
- Ignore mathematical law verification

**ALWAYS**:
- Run `make validate` before commits
- Maintain 99% coverage minimum
- Document public APIs with DocC
- Verify laws for FP concepts
- Update CHANGELOG.md

---

# Other reading suggestions

- [ONBOARDING.md](ONBOARDING.md)
- [QUICKSTART.md](QUICKSTART.md)
- [README_SUGGESTIONS.md](README_SUGGESTIONS.md)