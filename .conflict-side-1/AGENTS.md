# AGENTS.md - InvariantSwift

> **Hierarchical AGENTS.md** - This is the root file. Sub-packages have their own AGENTS.md with more detail.

## Project Snapshot

- **Type:** Single Swift Package (not monorepo)
- **Stack:** Swift 6.0+, SwiftSyntax macros, Swift Package Manager
- **Purpose:** Property-based testing framework with generators, shrinking, and automatic test generation
- **Sub-AGENTS.md files:** [Sources/InvariantSwift](Sources/InvariantSwift/AGENTS.md), [Sources/InvariantSwiftMacros](Sources/InvariantSwiftMacros/AGENTS.md), [Tests](Tests/AGENTS.md), [docs](docs/AGENTS.md), [Plugins](Plugins/AGENTS.md)

---

## Root Setup Commands

```bash
# Install dev tools
make setup                               # Installs swiftlint, swift-format, xcbeautify

# Build
swift build                              # Debug build
swift build -c release                   # Release build

# Test (choose one)
swift test                               # All tests
make test-swift                          # SPM tests with xcbeautify
make test-safe                           # Tests with SIGTRAP crash protection (beta SDK)

# Lint & Format
make lint                                # SwiftLint strict mode
make format                              # swift-format all files
```

---

## Universal Conventions

| Rule | Enforcement |
|------|-------------|
| **Indentation** | 2 spaces (no tabs) |
| **Line length** | 100 characters max |
| **Code style** | Google Swift Style Guide |
| **Commits** | Conventional Commits (`feat:`, `fix:`, `docs:`) |
| **Zero warnings** | `swift build -Xswiftc -warnings-as-errors` |
| **No force unwrap** | `!` is forbidden; use `guard let` |
| **No fatalError** | Enforce invariants in initializers |
| **Macros** | Pure SwiftSyntax builders only; NO string interpolation |

---

## Security & Secrets

- **Never** commit API tokens, keys, or credentials
- Secrets go in `.env` files (gitignored)
- No PII in test fixtures
- See `SECURITY.md` for vulnerability reporting

---

## JIT Index - Directory Map

### Source Targets

| Path | Purpose | AGENTS.md |
|------|---------|-----------|
| `Sources/InvariantSwift/` | Main library (Gen, Property, Shrink) | [→ AGENTS.md](Sources/InvariantSwift/AGENTS.md) |
| `Sources/InvariantSwiftMacros/` | Swift macro implementations | [→ AGENTS.md](Sources/InvariantSwiftMacros/AGENTS.md) |
| `Sources/FuncTestCLI/` | CLI tool | Single file, no sub-AGENTS |

### Test Targets

| Path | Purpose |
|------|---------|
| `Tests/FunctionalTesting/` | Core library unit tests (47 files) |
| `Tests/InvariantSwiftMacroTests/` | Macro expansion tests (11 files) |
| `Tests/PerformanceTests/` | Benchmarks |
| `Tests/CoverageIntegrationTests/` | Integration tests |

→ See [Tests/AGENTS.md](Tests/AGENTS.md) for test patterns and commands

### Plugins

| Path | Purpose |
|------|---------|
| `Plugins/InvariantSwiftPlugin/` | SPM plugin (`swift package invariant`) |
| `Plugins/GhostwriterPlugin/` | Auto-generate tests (`swift package ghostwrite`) |

→ See [Plugins/AGENTS.md](Plugins/AGENTS.md) for plugin development

### Documentation

| Path | Purpose |
|------|---------|
| `docs/proposals/` | ISP proposals (ISP-0001 through ISP-0010) - all implemented |
| `docs/ONBOARDING.md` | New contributor guide |
| `docs/COOKBOOK.md` | Usage patterns and recipes |

→ See [docs/AGENTS.md](docs/AGENTS.md) for documentation guidelines

---

## Quick Find Commands

```bash
# Find a type/struct/class
rg -n "^(public |)struct |^(public |)class |^(public |)enum " Sources/

# Find a macro definition
rg -n "struct.*Macro.*:.*Macro" Sources/InvariantSwiftMacros/

# Find test for a component
rg -n "@Test.*ComponentName" Tests/

# Find a generator
rg -n "static func|static var" Sources/InvariantSwift/Generators/

# Find proposal by number
ls docs/proposals/ISP-*.md

# Find all AGENTS.md files
rg -l "AGENTS.md" --files
```

---

## Definition of Done

Before creating a PR, ensure:

1. `swift build -Xswiftc -warnings-as-errors` ✓
2. `swift test` passes all tests ✓
3. `make lint` reports zero violations ✓
4. Documentation updated for API changes ✓
5. CHANGELOG.md updated ✓

**Quick check:** `make validate`

---

## Key Files to Understand

| File | Purpose |
|------|---------|
| `Package.swift` | Target definitions, dependencies |
| `Makefile` | All build/test/lint commands |
| `.swiftlint.yml` | Linting rules |
| `.swift-format` | Formatting config |
| `.pre-commit-config.yaml` | Git hooks configuration |
| `docs/proposals/README.md` | Proposal process |

---

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| swift-syntax | 600.0.1+ | Macro implementation |
| swift-custom-dump | 1.3.3+ | Pretty-printing for test output |
| SwiftLint | latest | Linting |
| swift-format | latest | Formatting |

---

## Platform Support

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 17.0+ |
| macOS | 14.0+ |
| tvOS | 17.0+ |
| watchOS | 10.0+ |
| Linux | Swift 6.0+ |

---

## Pre-PR Single Command

```bash
swift build -Xswiftc -warnings-as-errors && swift test && make lint
```
