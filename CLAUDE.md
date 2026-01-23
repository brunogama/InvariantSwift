<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# CLAUDE.md - InvariantSwift

This file provides authoritative guidance to Claude Code when working with this repository.

## Project Overview

| Attribute | Value |
|-----------|-------|
| **Type** | Swift Package (single project) |
| **Stack** | Swift 6.0, SwiftSyntax 600.0.1+, SwiftPM |
| **Purpose** | Property-based testing framework with generators, shrinking, and macros |
| **Platforms** | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ |

This CLAUDE.md is the authoritative source for Claude Code guidance. See [AGENTS.md](AGENTS.md) for general AI agent conventions.

---

## Universal Development Rules

### Code Quality (MUST)

- **MUST** use Swift 6 with strict concurrency (`Sendable` conformance)
- **MUST** compile with zero warnings: `swift build -Xswiftc -warnings-as-errors`
- **MUST** pass all tests before PR: `swift test`
- **MUST** run linting in strict mode: `swiftlint lint --strict`
- **MUST** format code: `swift-format -i --configuration .swift-format --recursive ./Sources ./Tests`
- **MUST NOT** commit secrets, API keys, or tokens

### Best Practices (SHOULD)

- **SHOULD** use 2-space indentation (configured in `.swift-format`)
- **SHOULD** keep lines under 100 characters
- **SHOULD** follow Google Swift Style Guide
- **SHOULD** use Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`)
- **SHOULD** prefer `guard let` over force unwrap (`!`)
- **SHOULD** make illegal states unrepresentable (no `fatalError` in library code)

### Anti-Patterns (MUST NOT)

- **MUST NOT** use `any` type without explicit justification
- **MUST NOT** bypass TypeScript errors with `@ts-ignore` equivalent
- **MUST NOT** use string interpolation for macro code generation (use SwiftSyntax AST builders)
- **MUST NOT** push directly to main branch

---

## Core Commands

### Development

```bash
# Build
swift build                              # Debug build
swift build -c release                   # Release build
swift build -Xswiftc -warnings-as-errors # Strict build

# Test
swift test                               # All tests
swift test --filter InvariantSwiftTests  # Core library tests
swift test --filter InvariantSwiftMacroTests  # Macro tests

# Lint & Format
swiftlint lint --strict                  # SwiftLint
make format                              # swift-format all files
make lint                                # Run linting
```

### Platform-Specific Testing

```bash
make test-swift     # SPM tests with xcbeautify
make test-macos     # Xcode macOS tests
make test-ios       # iOS Simulator tests
make test-tvos      # tvOS Simulator tests
make test-linux     # Linux Docker tests
make test-safe      # SIGTRAP-protected tests (beta SDK)
```

### Quality Gates (run before PR)

```bash
swift build -Xswiftc -warnings-as-errors && \
swiftlint lint --strict && \
swift test
```

Or simply: `make validate`

---

## Project Structure

### Source Targets

| Path | Purpose | Details |
|------|---------|---------|
| [`Sources/InvariantSwift/`](Sources/InvariantSwift/CLAUDE.md) | Main library | Gen, Property, Shrink, Faker, Ghostwriter |
| [`Sources/InvariantSwiftMacros/`](Sources/InvariantSwiftMacros/CLAUDE.md) | Macro implementations | @PropertyTest, @Arbitrary, @StateMachine |
| `Sources/FuncTestCLI/` | CLI tool | Single-file entry point |

### Test Targets

| Path | Purpose |
|------|---------|
| [`Tests/`](Tests/CLAUDE.md) | Test guidance |
| `Tests/InvariantSwiftTests/` | Core library tests (47 files) |
| `Tests/InvariantSwiftMacroTests/` | Macro expansion tests (11 files) |
| `Tests/PerformanceTests/` | Benchmarks |
| `Tests/CoverageIntegrationTests/` | Integration tests |

### Plugins

| Path | Command | Purpose |
|------|---------|---------|
| `Plugins/InvariantSwiftPlugin/` | `swift package invariant` | Run property tests |
| `Plugins/GhostwriterPlugin/` | `swift package ghostwrite` | Auto-generate tests |

### Documentation

| Path | Content |
|------|---------|
| `docs/proposals/` | ISP-0001 through ISP-0010 |
| `docs/COOKBOOK.md` | Usage patterns and recipes |
| `docs/ONBOARDING.md` | New contributor guide |
| `docs/MACROS.md` | Macro documentation |

---

## Quick Find Commands (JIT Index)

### Find Code Patterns

```bash
# Find a type/struct/class/enum
rg -n "^(public |)struct |^(public |)class |^(public |)enum " Sources/

# Find a generator definition
rg -n "static (func|var)" Sources/InvariantSwift/Generators/

# Find macro definition
rg -n "struct.*Macro.*:.*Macro" Sources/InvariantSwiftMacros/

# Find property test patterns
rg -n "@PropertyTest|checkProperty" .

# Find all public API
rg -n "^public " Sources/ --type swift
```

### Find Tests

```bash
# Find test for a component
rg -n "@Test.*ComponentName" Tests/

# Find all test suites
rg -n "@Suite" Tests/

# Count total tests
rg -c "@Test" Tests/ | awk -F: '{sum += $2} END {print sum}'
```

### Find Documentation

```bash
# Find proposal by number
ls docs/proposals/ISP-*.md

# Find all CLAUDE.md files
find . -name "CLAUDE.md" -not -path "./.build/*"

# Find all AGENTS.md files
find . -name "AGENTS.md" -not -path "./.build/*"
```

---

## Security & Secrets

### Secrets Management

- **NEVER** commit tokens, API keys, or credentials
- Use `.env.local` for local secrets (already in .gitignore)
- No PII in test fixtures
- See `SECURITY.md` for vulnerability reporting

### Safe Operations

- Review generated bash commands before execution
- **Confirm before**: `git push -f`, `rm -rf`, database operations
- Use staging environment for risky operations

### Protected Files

Do not auto-edit without explicit user request:
- `.env`, `.env.local` (secrets)
- `Package.resolved` (let SPM manage)
- `.github/workflows/*.yml` (require review)
- `SECURITY.md`, `LICENSE` (legal docs)

---

## Git Workflow

- Branch from `main` for features: `feature/description`
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`
- PRs require: passing CI, type checks, lint, and 1 approval
- Squash commits on merge
- Delete branches after merge

### Commit Message Examples

```bash
feat(generators): add UUID generator
fix(shrink): prevent infinite loop in array shrinking
docs(readme): update installation instructions
refactor(macros): extract common AST builders
test(property): add edge case tests for empty arrays
```

---

## Testing Strategy

### Coverage Requirements

- **99%+ code coverage** target for library code
- All public APIs must have tests
- Mathematical laws must be verified with property tests

### Test Patterns

```swift
// Swift Testing format (preferred)
import Testing
@testable import InvariantSwift

@Suite("Generator Tests")
struct GeneratorTests {
  @Test("Integer generator produces values in range")
  func integerInRange() {
    // test body
  }
}
```

### Running Tests

```bash
# All tests
swift test

# Specific test file
swift test --filter GeneratorTests

# Specific test method
swift test --filter "PropertyTests/testPropertyHolds"

# With coverage
swift test --enable-code-coverage
```

---

## Available Tools

### Standard Tools

- `swift`, `swiftc` - Swift compiler
- `rg` (ripgrep) - Fast search
- `git` - Version control
- `make` - Build automation (see Makefile)

### Development Tools

- `swiftlint` - Linting
- `swift-format` - Formatting
- `xcbeautify` - Pretty test output
- `xcrun` - Xcode tooling

### Tool Permissions

| Action | Permission |
|--------|------------|
| Read any file | ✅ Allowed |
| Write code files | ✅ Allowed |
| Run tests, linters | ✅ Allowed |
| Edit .env files | ⚠️ Ask first |
| Force push | ❌ Ask first |
| Delete directories | ❌ Ask first |

---

## Specialized Context

When working in specific directories, refer to their CLAUDE.md for detailed guidance:

- **Main library development**: [Sources/InvariantSwift/CLAUDE.md](Sources/InvariantSwift/CLAUDE.md)
- **Macro development**: [Sources/InvariantSwiftMacros/CLAUDE.md](Sources/InvariantSwiftMacros/CLAUDE.md)
- **Testing**: [Tests/CLAUDE.md](Tests/CLAUDE.md)

---

## Key Files to Understand

| File | Purpose |
|------|---------|
| `Package.swift` | Target definitions, dependencies |
| `Makefile` | All build/test/lint commands |
| `.swiftlint.yml` | Linting rules (Google style) |
| `.swift-format` | Formatting config (2-space indent) |
| `.pre-commit-config.yaml` | Git hooks |
| `AGENTS.md` | General AI agent conventions |

---

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| swift-syntax | 600.0.1+ | Macro implementation |
| swift-custom-dump | 1.3.3+ | Pretty-printing for test output |
| SwiftLint | latest | Linting |
| swift-format | latest | Formatting |

---

## Common Gotchas

1. **Sendable conformance**: All generators use `@unchecked Sendable` because closures capture mutable RNG
2. **Size parameter**: Always pass through `Size` for recursive generators to prevent infinite depth
3. **Shrink termination**: Ensure shrink functions eventually return `[]` to prevent infinite loops
4. **Macro trivia**: Preserve leading/trailing trivia in AST for proper formatting
5. **SwiftSyntax versions**: Pin to 600.0.1 for Swift 6.0/6.1/6.2 compatibility
6. **No runtime deps in macros**: Macro targets cannot import InvariantSwift library

---

## Definition of Done

Before creating a PR, ensure:

1. ✅ `swift build -Xswiftc -warnings-as-errors` passes
2. ✅ `swift test` passes all tests
3. ✅ `swiftlint lint --strict` reports zero violations
4. ✅ Code is formatted: `make format`
5. ✅ Documentation updated for API changes
6. ✅ CHANGELOG.md updated (if user-facing change)

**Quick check**: `make validate`
