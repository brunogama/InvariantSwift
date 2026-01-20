# InvariantSwift

**Type:** Swift Package (Library)
**Language:** Swift 6.0+
**Platforms:** iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, Linux
**Purpose:** Advanced property-based testing framework for Swift, featuring automatic generation, smart shrinking, and Swift Macros integration.

---

## 🛠 Project Setup & Environment

### Prerequisites
- **Swift:** 6.0 or later
- **Xcode:** 16.0+ (for Apple platforms)
- **Tools:**
    - `swiftlint` (via Homebrew)
    - `swift-format` (via Homebrew)
    - `xcbeautify` (optional, for pretty test output)

### Installation
Install development dependencies:
```bash
make setup
```

---

## 🚀 Key Commands

The project uses a `Makefile` to standardize common tasks.

| Action | Command | Details |
| :--- | :--- | :--- |
| **Build** | `swift build` | Build the package |
| **Test (All)** | `make test-all` | Run tests on all configured platforms |
| **Test (Swift)** | `make test-swift` | Fast test run using SPM |
| **Test (macOS)** | `make test-macos` | Run tests on macOS target |
| **Format** | `make format` | Format code using `swift-format` |
| **Lint** | `make lint` | Run strict linting with `swiftlint` |
| **Validate** | `make validate` | Run full validation (lint + tests) |
| **Docs** | `make docs-gen` | Generate API and Architecture documentation |
| **Clean** | `make clean` | Remove build artifacts |

**Note:** For beta macOS SDKs with ABI issues, use `make test-safe` which employs `sigtrap_capture.py` to handle crashes gracefully.

---

## 📂 Directory Structure

| Path | Purpose |
| :--- | :--- |
| `Sources/InvariantSwift/` | **Core Library**. Contains Generators, Property logic, Shrinking, and Fuzzing integration. |
| `Sources/InvariantSwiftMacros/` | **Macros**. Implementation of `@PropertyTest`, `@Arbitrary`, and other macros using SwiftSyntax. |
| `Sources/FuncTestCLI/` | **CLI**. Source for the `functest` command-line tool. |
| `Tests/FunctionalTesting/` | **Core Tests**. The primary test suite for the library (40+ files). |
| `Tests/InvariantSwiftMacroTests/` | **Macro Tests**. Tests verifying macro expansion logic. |
| `Plugins/` | **SPM Plugins**. `InvariantSwiftPlugin` and `GhostwriterPlugin`. |
| `Scripts/` | **Tooling**. Python and Shell scripts for docs, coverage, and validation. |
| `docs/` | **Documentation**. Guides, proposals (ISP-*), and generated references. |

---

## 📝 Development Conventions

### Coding Style
- **Indentation:** 2 spaces (enforced by `.swift-format`).
- **Line Length:** 100 characters max.
- **Style Guide:** Follows Google Swift Style Guide with minor modifications.
- **Linting:** Strict mode is enabled. Zero warnings required.

### Testing Strategy
- **Framework:** Uses native `Testing` (Swift Testing) framework.
- **Coverage:** Target **99%+** for library code.
- **Pattern:**
    - **Unit Tests:** For individual generators and logic.
    - **Property Tests:** Use InvariantSwift to test InvariantSwift (dogfooding).
    - **Integration:** `Tests/CoverageIntegrationTests/` for end-to-end flows.
- **Macros:** Must be tested using `SwiftSyntaxMacrosTestSupport`.

### Git Workflow
- **Branching:** Create feature branches from `main`.
- **Commits:** Follow **Conventional Commits** (e.g., `feat:`, `fix:`, `docs:`).
- **PRs:** Require passing `make validate` (lint + tests) before merge.

---

## ⚠️ Common Gotchas & Troubleshooting

1.  **Sendable Conformance:** Generators use `@unchecked Sendable` because closures capture mutable RNG state. This is intentional.
2.  **Macro Trivia:** When modifying macros, ensure leading/trailing trivia (whitespace) is preserved in the AST to maintain correct formatting.
3.  **Recursion Limits:** When implementing recursive generators, always pass the `Size` parameter to prevent infinite depth.
4.  **Shrinking Loops:** Ensure custom shrink functions eventually return an empty array `[]` to terminate the shrinking process.
5.  **SwiftSyntax Version:** The project pins `swift-syntax` to specific versions (e.g., `600.0.1`) to match the Swift compiler version. Check `Package.swift` before upgrading.

---

## 🤖 AI Agent Guidelines

- **File Editing:** Always read `CLAUDE.md` in specific subdirectories (`Sources/InvariantSwift/`, `Tests/`, etc.) for localized context.
- **Safety:** Do not edit `.env` or `.env.local` without explicit permission.
- **Search:** Use `rg` (ripgrep) for searching code. It is faster and respects `.gitignore`.
- **Test Output:** If tests fail, use `swift test --filter <TestName>` to isolate the failure.
