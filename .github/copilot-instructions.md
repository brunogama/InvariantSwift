# Copilot review guidance

Use the path-specific instruction files in `.github/instructions/` for pull
request reviews that touch `Sources/**/*.swift` or `Tests/**/*.swift`.

Repository-wide review baseline:

- Treat `RULES.md` as mandatory: formatting, SwiftLint strict, zero warnings,
  and passing tests.
- Assume Swift 6 language mode and Complete strict concurrency checking on every
  active target, including tests.
- Reject changes that break target layering, introduce unsafe concurrency, or
  change behavior without matching tests unless the PR is explicitly doc-only.
- Prefer value types, avoid implicit global singletons, and keep routing logic
  deterministic and testable.
# InvariantSwift agent onboarding

Read `AGENTS.md`, `RULES.md`, and `WORKFLOW.md` before editing. They define the repo's operating rules, validation requirements, and git safety constraints.

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
# Copilot instructions for InvariantSwift

## Start here
- Read `AGENTS.md` first, then `RULES.md`, then `WORKFLOW.md`.
- For repository shape and public API context, read `README.md`, `Package.swift`, `Packages/InvariantSwiftCore/Package.swift`, and `Packages/InvariantSwiftMacros/Package.swift`.
- Keep diffs tight. This repo has explicit rules against unrelated refactors, destructive Git cleanup, and bypassing validation.

## Repository shape
- This is a Swift Package Manager workspace, not a single-package repo.
- The root `Package.swift` uses Swift tools `6.2` and defines the umbrella/testing integration targets, utility CLIs, plugins, and root integration tests.
- `Packages/InvariantSwiftCore` is the main library package. It contains the layered runtime modules:
  - `InvariantSwiftCore`
  - `InvariantSwiftGenerators`
  - `InvariantSwiftExecution`
  - `InvariantSwift`
  - `InvariantSwiftAdvanced`
  - `InvariantSwiftDomainGenerators`
- `Packages/InvariantSwiftMacros` contains the SwiftSyntax-based macro implementation, the public macro API target, Ghostwriter, and macro tests.
- Root `Sources/` is mostly workspace glue (`InvariantSwiftUmbrella`, `InvariantSwiftTestingIntegration`, CLIs, plugins). Root `Tests/` is mostly integration/smoke/generated-property coverage.

## Validation commands to use
Follow `RULES.md`: format, lint, build with warnings as errors, and run tests for the area you changed.

### Tooling prerequisites
- Run `make setup` before using the repo wrappers if `swiftlint`, `swift-format`, or `xcbeautify` are missing.
- `make setup` installs those tools with Homebrew, so it is mainly for macOS developer machines.

### Root workspace commands
Use these when changing root `Sources/`, root `Tests/`, or shared workspace configuration:
- `make format`
- `make lint`
- `swift build -Xswiftc -warnings-as-errors`
- `swift test --parallel`
- `make test-swift` if `xcbeautify` is installed and you want the repo's preferred wrapper (`swift test --enable-experimental-prebuilts | xcbeautify`)

### Sub-package commands
If you change code under `Packages/`, validate the affected package directly:
- Core package:
  - `swift build --package-path Packages/InvariantSwiftCore`
  - `swift test --package-path Packages/InvariantSwiftCore`
- Macros package:
  - `swift build --package-path Packages/InvariantSwiftMacros --enable-experimental-prebuilts`
  - `swift test --package-path Packages/InvariantSwiftMacros --enable-experimental-prebuilts`
- If a change touches macro-heavy code or root integration targets, `make ci-build` is the closest local approximation of the CI build order (`build-core`, then `build-macros`, then root build).

## Format and lint scope gotchas
- `make format` only formats `./Package.swift`, `./Sources`, and `./Tests` from the repo root. It does **not** recurse through `Packages/**`.
- The root `.swiftlint.yml` includes only `Sources`, `Benchmarks`, and `Tests`. It does **not** cover `Packages/**`.
- `Packages/InvariantSwiftMacros/.swiftlint.yml` exists for the macros package. If you edit files there, use that config explicitly.
- There is no package-local formatter config under `Packages/`; use the root `.swift-format` when formatting package files manually.

## CI and workflow facts that matter
- PR validation uses Swift `6.2` and requires:
  - format check
  - strict SwiftLint
  - `swift build -Xswiftc -warnings-as-errors`
  - `swift test --parallel`
  - Danger
  - commit lint
- `Format` workflow runs `make format` and may auto-commit formatting changes on PR branches.
- Commit lint uses Conventional Commits and intentionally ignores bootstrap commit messages that start with `Initial plan`.
- The PR validation workflow blocks blanket disable directives that affect all rules inside `Sources/` and `Tests/`, such as `swiftlint:disable all`, `swiftlint:disable:this all`, and `swiftlint:disable:next all`.
- If the user asks about CI failures, inspect GitHub Actions runs first. Do not guess.

## Conventions worth following
- Keep functions, files, and types comfortably under the SwiftLint budgets documented in `RULES.md` and `.swiftlint.yml`.
- Prefer `struct` over `class` where practical.
- Avoid `print(...)` in production sources.
- Update documentation when a change affects public API, setup, package layout, workflow, or developer commands.
- Do not assume older docs are current. `README.md`, `CONTRIBUTING.md`, and some package manifests still contain mixed `Swift 6.0`/`Swift 6.2` references, so prefer the actual build config and workflows when they disagree.

## Errors encountered during onboarding and how they were handled
These were observed while onboarding the repo in the current sandbox and are useful context if you hit the same problems again:

- `make lint` failed because `swiftlint` was not installed in the environment.
  - Work-around: run `make setup` on a macOS machine with Homebrew, or install `swiftlint` manually before using the Makefile wrapper.
- `make test-swift` failed because `xcbeautify` was not installed.
  - Work-around: install `xcbeautify`, or run the underlying command directly: `swift test --enable-experimental-prebuilts`.
- Running `swift build` and `swift test` in parallel caused `Another instance of SwiftPM is already running`.
  - Work-around: run SwiftPM commands sequentially.
- GitHub Actions runs for the onboarding branch returned `action_required` with zero jobs/logs via the API.
  - Work-around: rely on local validation until the workflow actually starts, because there are no job logs to inspect before jobs are created.
- A strict Linux build in the onboarding environment currently fails in `Packages/InvariantSwiftCore/Sources/InvariantSwiftCore/PropertyRunner+Progress.swift` and `PropertyRunner+Async.swift` because `CFAbsoluteTime` / `CFAbsoluteTimeGetCurrent` are not in scope.
  - Work-around used during onboarding: treat this as a pre-existing build issue unrelated to the onboarding document, avoid changing runtime code as part of this task, and note the failure explicitly instead of masking it.
