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
