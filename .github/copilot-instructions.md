# InvariantSwift AI Coding Agent Onboarding Summary

## (1) REPOSITORY PURPOSE & MAJOR MODULE LAYOUT

### Purpose
InvariantSwift is the most advanced property-based testing framework for Swift (6.0+) with:
- 50+ automatic test input generators for Swift types
- Smart shrinking to minimal failing counterexamples
- Swift Macros (@PropertyTest, @Arbitrary, @Gen) for boilerplate-free testing
- Native Swift Testing framework integration
- Full Swift 6 concurrency (async properties)
- Coverage-guided and model-based testing

Platforms: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, Linux (Swift 6.0+)

### Architecture: SPM Workspace Monorepo
Root: /home/runner/work/InvariantSwift/InvariantSwift/

TWO SUB-PACKAGES as local dependencies:

**Packages/InvariantSwiftCore/** (No SwiftSyntax):
  - Layer 0: Sources/InvariantSwiftCore/ (RNG, shrinking, infrastructure)
  - Layer 1: Sources/InvariantSwiftGenerators/ (50+ generators) + Sources/InvariantSwiftExecution/
  - Layer 2: Sources/InvariantSwift/ (facade combining layers 0-1)
  - Layer 3: Sources/InvariantSwiftAdvanced/ (coverage-guided, model-based testing)
  - Domain: Sources/InvariantSwiftDomainGenerators/ (Date, UUID, URL, etc.)

**Packages/InvariantSwiftMacros/** (SwiftSyntax dependency):
  - Sources/InvariantSwiftMacros/ (macro implementations)
  - Sources/InvariantSwiftMacroAPI/ (re-exported macro stubs, zero-dependency)
  - Sources/GhostwriterLib/ + Sources/GhostwriterCLI/ (auto-test generation)

**Root Targets**:
  - Sources/InvariantSwiftUmbrella/ (re-exports all)
  - Sources/InvariantSwiftTestingIntegration/ (Swift Testing integration)
  - Utility CLIs: PropertyTestHelper, GeneratorCatalogCLI
  - Plugins: InvariantSwiftPlugin, GhostwriterPlugin, GeneratorCatalogPlugin
  - Integration tests: Tests/{CoverageIntegrationTests, GeneratedPropertyTests, SmokeTests}

---

## (2) LOCAL VALIDATION COMMANDS & PREREQUISITES

### Prerequisites
- Swift 6.0+ (check: swift --version)
- Xcode 16.0+ (macOS development)
- Homebrew tools: swiftlint, swift-format, xcbeautify

Install: `make setup`

### REQUIRED Validation Commands (Must Pass Before Commit)

1. FORMAT CODE (Required):
   make format
   OR: swift-format -i --configuration .swift-format --recursive ./Package.swift ./Sources ./Tests

2. LINT (Required - Strict mode, NO blanket disables allowed):
   make lint
   OR: swiftlint lint --strict

3. BUILD WITH WARNINGS-AS-ERRORS (Required):
   swift build -Xswiftc -warnings-as-errors

4. RUN TESTS (Required):
   make test-swift  (primary: uses prebuilts for fast macro compilation)
   OR: swift test

5. BUILD SUB-PACKAGES (CI-aware):
   make ci-build  (builds InvariantSwiftCore, InvariantSwiftMacros, then full package)
   OR: make build-core && make build-macros

6. OPTIONAL - Platform-specific tests:
   make test-macos / test-ios / test-tvos / test-watchos / test-linux

### Known Workarounds & Quirks

QUIRK 1: MACRO COMPILATION SLOWNESS (CRITICAL)
- Problem: SwiftSyntax (602+) has large compile overhead
- Solution: Use --enable-experimental-prebuilts flag
  swift build --package-path Packages/InvariantSwiftMacros --enable-experimental-prebuilts
  make test-macros (uses prebuilts automatically)
- Why: Prebuilts cache binary artifacts; 3+ minute speedup

QUIRK 2: MACOS BETA SDK SIGTRAP CRASHES
- Problem: Pre-release macOS SDKs have ABI incompatibilities → test crashes
- Solution: make test-safe
  OR: python3 sigtrap_capture.py InvariantSwift --verbose
- Why: SIGTRAP crash isolation protects against ABI issues

QUIRK 3: INTEGRATION TESTS NEED SUB-PACKAGES BUILT FIRST
- Problem: Integration tests depend on both sub-package products
- CI order: build-core → build-macros → integration-tests
- Local: make ci-build (sequential build prevents race conditions)
- Why: Products from both sub-packages needed before root integration tests

QUIRK 4: LINUX TESTS SKIP ON MACOS
- Problem: Swift 6.2-jammy Docker tests require Docker
- Solution: make test-linux (requires Docker running)
- Local alternative: Run via GitHub Actions CI only

QUIRK 5: MACRO GOLDEN TESTS IN CI ONLY
- Location: .github/workflows/ci.yml line 79
- Command: swift test --filter MacroGoldenTests
- Status: Not fully migrated yet; runs in CI only

QUIRK 6: SWIFTLINT ↔ SWIFT-FORMAT CONFLICTS (ALREADY RESOLVED)
- .swiftlint.yml (lines 76, 107-109) EXPLICITLY DISABLES conflicting rules:
  - opening_brace (critical)
  - vertical_whitespace_opening_braces (critical)
  - vertical_whitespace_closing_braces (critical)
  - number_separator (critical)
  - sorted_imports, trailing_comma (manual)
- Never re-enable these; let swift-format handle formatting

### CI Pipeline Validation Gates (.github/workflows/pr-validation.yml)
ALL MUST PASS for PR merge:
1. Format Check: swift-format lint --strict --recursive Sources/ Tests/
2. Lint Check: swiftlint lint --strict (no blanket disables allowed)
3. Build Check: swift build -Xswiftc -warnings-as-errors
4. Test Check: swift test --parallel
5. Commit Lint: Conventional Commits format enforced
6. Danger Check: Custom checks via Dangerfile.swift

No bypasses allowed (--no-verify forbidden).

---

## (3) WORKFLOWS, GUARDRAILS & CONVENTIONS

### Code Budgets (RULES.md - Lint-First Design)

Hard limits enforced by SwiftLint (.swiftlint.yml):
  Line length: 100 chars (error)
  Function params: warn 4, error 6
  Function body: warn 60, error 120
  Type body: warn 300, error 800
  File length: warn 400, error 1000
  Cyclomatic complexity: warn 10, error 15
  Nesting: type level 2, function level 3

STRATEGY: Refactor BEFORE hitting limits.
  - Split large functions into helpers
  - Extract nested types
  - Use table-driven design for complex logic

### Formatting Rules (.swift-format JSON)

  Indentation: 2 spaces
  Line length: 100 characters (matching SwiftLint)
  Line breaks: lineBreakBeforeEachArgument: true
  Documentation: ALL public APIs need /// doc comments
  No force unwrap/try: Relaxed but use judiciously

### Style Conventions (Google Swift Style Guide)

  Prefer struct over class (SwiftLint rule)
  No print() in production code (allowed: Tests, Benchmarks, CLIs)
  Use guard for early returns (prefer shallow nesting)
  Prefer let over var
  Extract helpers when block > 15 lines or multiple responsibilities

### Sub-Package Dependency Order (ENFORCED)

  InvariantSwiftCore (Layer 0)
    ↓
  InvariantSwiftGenerators, InvariantSwiftExecution (Layer 1)
    ↓
  InvariantSwift (Layer 2, combines 0+1)
    ↓
  InvariantSwiftAdvanced (Layer 3, extends 2)
  
  Separate: InvariantSwiftDomainGenerators → InvariantSwift
  Separate: InvariantSwiftMacros (no Core dependency; imports selectively)

### Commit Conventions (Conventional Commits Format)

Format: type(scope): description

Types:
  feat: New feature
  fix: Bug fix
  docs: Documentation
  style: Formatting (use sparingly; prefer make format)
  refactor: Code restructure (no behavior change)
  perf: Performance improvement
  test: Test additions
  chore: Tooling, CI, dependencies

Examples:
  feat(generators): add UUID generator
  fix(shrinking): handle empty arrays correctly
  refactor(core): decompose Property.swift into single-responsibility files

Rules:
  Use fixes #<issue-number> or closes #<issue-number> to link issues
  No blanket swiftlint:disable all

### Branch & PR Workflow (WORKFLOW.md)

Branching patterns:
  feat/<area>-<topic> (e.g., feat/coverage-guided-generation)
  fix/<area>-<bug> (e.g., fix/shrinking-edge-case)
  docs/<area>-<topic> (e.g., docs/generator-reference)
  
Branch protection: No direct commits to main/dev (enforced by pre-commit hook)

PR process:
  1. Create feature branch off main
  2. Make focused changes (one feature/fix per PR)
  3. Push, open PR with conventional commit title
  4. All CI gates must pass
  5. User explicitly merges (agents do not auto-merge)

Code review checklist (WORKFLOW.md lines 46-56):
  Correctness & edge cases
  Regression risk
  API impact & backward compatibility
  Test coverage (aim 99%+ on new code)
  Lint/format compliance
  Complexity & file-size budgets
  Documentation updates

### Pre-Commit Hooks (.pre-commit-config.yaml)

Automatic checks when committing:
  swift-format: Formats code
  swiftlint: Lints & fixes (runs fix then strict mode)
  Branch protection: Blocks commits to main/dev
  Trailing whitespace removal
  File size checks (max 1000 KB)

Install: pip install pre-commit && pre-commit install

### Documentation Expectations (WORKFLOW.md lines 84-92)

Update docs when changes affect:
  Public API (add /// doc comments)
  Setup/installation (README.md, CONTRIBUTING.md)
  Repository workflow (AGENTS.md, WORKFLOW.md)
  Release process (RELEASING.md, CHANGELOG.md)
  Package layout
  Developer commands (Makefile)
  Behavior users depend on

Doc comment style:
  /// Generates random integers within a specified range.
  ///
  /// - Parameter range: The range of integers to generate from
  /// - Returns: A generator that produces integers in the given range
  public static func int(in range: ClosedRange<Int>) -> Gen<Int> { ... }

---

## (4) KNOWN BUILD/TEST/LINT QUIRKS & WORKAROUNDS

Build Quirks:
  - SwiftSyntax slow compile: Use --enable-experimental-prebuilts (3+ min speedup)
  - Macro tests skipped in CI: Run via swift test --filter MacroGoldenTests manually
  - Sub-package build order: Run make ci-build or build core then macros first
  - Linux tests need Docker: Use Docker or run via CI only

Lint Quirks:
  - SwiftLint ↔ swift-format conflicts: NEVER enable opening_brace, vertical_whitespace_*, number_separator, sorted_imports, trailing_comma
  - Blanket disable forbidden: Use targeted disables only (swiftlint:disable cyclomatic_complexity)
  - print() forbidden in production: Allowed only in Tests, Benchmarks, CLI paths
  - File > 1000 lines: Split into separate files or use +Helpers.swift pattern

Test Quirks:
  - Beta SDK SIGTRAP: Use make test-safe or python3 sigtrap_capture.py
  - xcodebuild simulator device errors: Run xcrun simctl create or list devices
  - Platform differences: iOS/tvOS need simulators booted; watchOS limited device selection

---

## (5) KEY DOCUMENTATION FILES TO READ FIRST

Priority Reading Order:

1. README.md (lines 1-100 overview, lines 41-185 features)
   - What project does, features, usage examples, platforms

2. AGENTS.md (lines 15-33 code rules, lines 48-60 Git safety)
   - How to operate in this repo, commit policy, Git safety for parallel agents

3. RULES.md (lines 1-50 non-negotiables, lines 88-108 mandatory process)
   - Definition of done, lint budgets, code size constraints, process

4. WORKFLOW.md (lines 22-38 branching, lines 39-45 PR expectations)
   - Issue intake, branching, PR process, review expectations, conflict policy

5. CONTRIBUTING.md (lines 24-55 setup & style, lines 83-120 docs)
   - Development setup, code style, testing guidelines, documentation

Task-Specific:
  Generators: README.md lines 123-185 + Packages/InvariantSwiftCore/Sources/InvariantSwiftGenerators/
  Macros: README.md lines 270-340 + Packages/InvariantSwiftMacros/Sources/InvariantSwiftMacros/
  Shrinking: README.md lines 225-267 + Packages/InvariantSwiftCore/Sources/InvariantSwiftCore/Shrinking.swift
  Model-based testing: README.md lines 398-432 + Packages/InvariantSwiftCore/Sources/InvariantSwiftAdvanced/ModelTesting.swift
  Coverage-guided: README.md lines 381-396 + Packages/InvariantSwiftCore/Sources/InvariantSwiftAdvanced/CoverageGuided.swift

Configuration & Build:
  Makefile: Root test/build targets (lines 1-50), docs generation (lines 95-142)
  Package.swift (Root): Lines 1-50 workspace structure, 49-75 umbrella layers, 77-105 CLIs/plugins, 142-177 integration tests
  Packages/InvariantSwiftCore/Package.swift: Lines 21-35 products, 42-75 dependency layers
  .swiftlint.yml: Lines 118-204 rule configurations & budgets
  .swift-format: Lines 20-58 enabled rules & style directives

CI/CD & Release:
  .github/workflows/ci.yml: Full CI pipeline (sub-packages, platforms, lint, format, coverage)
  .github/workflows/pr-validation.yml: PR merge gates (format, lint, build, test, commit-lint, danger)
  RELEASING.md: Release versioning, changelog rules, release checklist
  CHANGELOG.md: Project history (lines 1-50 format, 8-50 recent changes)

Files to Understand Package Structure:
  Package.swift (root): Umbrella manifest
  Packages/InvariantSwiftCore/Package.swift: Core layered structure
  Packages/InvariantSwiftMacros/Package.swift: Macro package

---

## Quick Onboarding Checklist

[ ] Read AGENTS.md, RULES.md, WORKFLOW.md (15 min)
[ ] Run make setup && make validate locally (5 min)
[ ] Understand sub-packages: InvariantSwiftCore (Layers 0-3) vs InvariantSwiftMacros (10 min)
[ ] Know commands: make format, make lint, swift build -Xswiftc -warnings-as-errors, make test-swift (5 min)
[ ] Understand pre-commit hooks: automatic format & lint before commit (5 min)
[ ] Know hard budgets: 100-char lines, 60-line functions, 400-line files, complexity ≤10 (5 min)
[ ] Know workarounds: --enable-experimental-prebuilts, test-safe, ci-build (5 min)
[ ] Know commit format: type(scope): description with Conventional Commits (3 min)

**Total: ~1 hour onboarding**

---

## Key Takeaways for Coding

DO:
  - Run make format && make lint before committing
  - Build sub-packages first if touching integration tests
  - Use --enable-experimental-prebuilts for macro builds
  - Extract functions that exceed 50 lines
  - Write /// doc comments for all public APIs
  - Use targeted swiftlint:disable with justification
  - Follow type(scope): description commit format

DON'T:
  - Commit without passing format/lint/build/test checks
  - Use --no-verify to bypass pre-commit hooks
  - Enable swiftlint rules that conflict with swift-format
  - Add print() to production code (Tests/Benchmarks/CLIs only)
  - Force push to shared branches
  - Mix refactoring with feature/fix changes
  - Exceed code budgets (100 chars, 60-line functions, 400-line files, 10 complexity)
  - Remove or weaken intentional behavior without explicit user request

___BEGIN___COMMAND_DONE_MARKER___0
