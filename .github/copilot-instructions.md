# InvariantSwift agent onboarding

Read `/home/runner/work/InvariantSwift/InvariantSwift/AGENTS.md`, `RULES.md`, and `WORKFLOW.md` before editing. They define the repo's operating rules, validation requirements, and git safety constraints.

## Repository shape

- This is a Swift 6.2 monorepo. The root `Package.swift` is an umbrella manifest; most implementation code lives in sub-packages.
- Use the narrowest package possible:
  - `Packages/InvariantSwiftCore/` for the core library, generators, execution, and advanced runtime behavior.
  - `Packages/InvariantSwiftMacros/` for SwiftSyntax-based macros and `GhostwriterCLI`.
  - `Sources/InvariantSwiftTestingIntegration/` for the Swift Testing integration layer exported by the root package.
  - Root `Tests/` mainly contains integration, generated, and smoke tests.
- Utility and maintenance scripts live under `Tools/`. The `Makefile` exposes the most common build, test, and docs commands.

## Test and code style expectations

- Tests use Swift Testing (`@Test`, `@Suite`, `#expect`), not XCTest.
- Macro tests are whitespace-sensitive, so avoid casual formatting changes in expected expansion output.
- All targets opt into strict concurrency checking. Treat warnings as errors and do not weaken concurrency settings to get a build through.
- Prefer small, low-complexity changes. SwiftLint budgets are enforced aggressively: line length 100, function body warning at 60 lines, cyclomatic complexity warning at 10.

## Commands agents should use

For Swift code changes, the repo rules expect these checks:

1. Format changed Swift files with `swift-format -i --configuration .swift-format <files>` or run `make format` for the root recursive formatter.
2. Run `swiftlint lint --fix <files>` and then `swiftlint lint --strict <files>`.
3. Run `swift build -Xswiftc -warnings-as-errors`.
4. Run `swift test`.

Useful repo-specific shortcuts:

- `make build-core`
- `make test-core`
- `make build-macros` (uses `--enable-experimental-prebuilts`)
- `make test-macros`
- `make build`
- `make test-swift`
- `make lint`
- `make docs-validate`

When you only touch one package, prefer `swift build --package-path ...` / `swift test --package-path ...` over rebuilding the entire workspace.

## CI and PR guardrails

- PR validation checks formatting in `Sources/` and `Tests/`, strict SwiftLint, `swift build -Xswiftc -warnings-as-errors`, `swift test --parallel`, Danger, and commitlint.
- CI blocks blanket `swiftlint:disable ... all` directives in `Sources/` and `Tests/`.
- Commit messages are expected to follow Conventional Commits. The coding-agent bootstrap commit starting with `Initial plan` is explicitly ignored by commitlint.
- Pre-commit hooks also enforce branch protection (`main`/`dev` direct commits are rejected), changelog updates for code changes, and prevent committing `.swift.disabled` files.

## Practical repo-specific guidance

- `Package.swift` is excluded from SwiftLint, so lint behavior for the root manifest differs from normal source files.
- Prefer `Package.swift` and `.github/workflows/*.yml` over README prose when platform/toolchain details disagree. The actual workspace currently targets Swift tools `6.2`, and CI is pinned to Swift 6.2 / Xcode 16.4-era runners.
- Some older docs still reference the previous `FunctionalTesting` name; trust the current package manifests, sources, and workflows first.

## Known issues and workarounds observed during onboarding

- In this onboarding sandbox, `swift-format` and `swiftlint` were not installed (`command not found`). On macOS, `make setup` installs the expected tooling through Homebrew; otherwise install equivalent binaries before running repo validation locally.
- A baseline Linux root build failed before any changes with `CFAbsoluteTimeGetCurrent` / `CFAbsoluteTime` errors in:
  - `Packages/InvariantSwiftCore/Sources/InvariantSwiftCore/PropertyRunner+Async.swift`
  - `Packages/InvariantSwiftCore/Sources/InvariantSwiftCore/PropertyRunner+Progress.swift`
  - plus a `Duration` to `TimeInterval` conversion error in `PropertyRunner+Progress.swift`
- Treat that Linux root-build failure as pre-existing unless your change touches those files. For unrelated work, verify regressions against the macOS CI path instead of assuming your change caused the baseline failure.
