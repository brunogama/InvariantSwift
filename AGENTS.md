# AGENTS.md - InvariantSwift

> **Hierarchical AGENTS.md** - This is the root file. Sub-packages have their own AGENTS.md with more detail.

## Project Snapshot
- **Type:** Single Swift Package (not monorepo)
- **Stack:** Swift 6.0, SwiftSyntax macros, Swift Package Manager
- **Purpose:** Property-based testing framework with generators, shrinking, and automatic test generation
- **Sub-AGENTS.md files:** See `Sources/InvariantSwiftMacros/AGENTS.md`, `Sources/InvariantSwift/AGENTS.md`

---

## Root Setup Commands

```bash
# Install dev tools
make setup                               # Installs swiftlint, swift-format, xcbeautify

# Build
swift build                              # Debug build
swift build -c release                   # Release build

# Test
swift test                               # All tests
make test-swift                          # SPM tests with xcbeautify
make test-macos                          # Xcode macOS tests
make test-ios                            # iOS Simulator tests

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
| `Sources/InvariantSwift/` | Main library (Gen, Property, Shrink) | [→ Sources/InvariantSwift/AGENTS.md](Sources/InvariantSwift/AGENTS.md) |
| `Sources/InvariantSwiftMacros/` | Swift macro implementations | [→ Sources/InvariantSwiftMacros/AGENTS.md](Sources/InvariantSwiftMacros/AGENTS.md) |
| `Sources/FuncTestCLI/` | CLI tool | Single file, no sub-AGENTS |

### Test Targets
| Path | Purpose |
|------|---------|
| `Tests/FunctionalTesting/` | Core library unit tests |
| `Tests/InvariantSwiftMacroTests/` | Macro expansion tests |
| `Tests/PerformanceTests/` | Benchmarks |
| `Tests/CoverageIntegrationTests/` | Integration tests |

### Plugins
| Path | Purpose |
|------|---------|
| `Plugins/InvariantSwiftPlugin/` | SPM plugin (`swift package invariant`) |
| `Plugins/GhostwriterPlugin/` | Auto-generate tests (`swift package ghostwrite`) |

### Documentation
| Path | Purpose |
|------|---------|
| `docs/proposals/` | ISP proposals (ISP-0001 through ISP-0010) |
| `docs/ONBOARDING.md` | New contributor guide |
| `docs/COOKBOOK.md` | Usage patterns and recipes |

---

## Quick Find Commands

```bash
# Find a type/struct/class
rg -n "^(public |)struct |^(public |)class |^(public |)enum " Sources/

# Find a macro definition
rg -n "@_macro|MacroDeclaration|ExpressionMacro" Sources/InvariantSwiftMacros/

# Find test for a component
rg -n "@Test.*ComponentName" Tests/

# Find a generator
rg -n "static func|static var" Sources/InvariantSwift/Generators/

# Find proposal by number
ls docs/proposals/ISP-*.md

# Find all AGENTS.md files
find . -name "AGENTS.md" -not -path "./.build/*"
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
