# Contributing to MacroTemplateKit

Thank you for contributing to MacroTemplateKit.
This repository uses trunk-based development.
The target branch is `main`.

## Core expectations
- Keep changes small and focused.
- Prefer the smallest mergeable slice.
- If a branch is needed, use a short-lived branch and merge it back quickly.
- If work is incomplete but must land, hide it behind a feature flag or an inactive path.
- Do not rely on long-lived feature branches or release branches.

## Reporting Issues
1. Search existing issues first.
2. Use the issue template when available.
3. Provide clear reproduction steps for bugs.
4. Include environment details such as Swift version, OS, and Xcode version.

## Development Setup
### Prerequisites
- Swift 5.10+
- Xcode 16+
- macOS 13+

### Bootstrap
Install the same tooling used in CI:

```bash
./scripts/bootstrap.sh
```

### Build
```bash
git clone https://github.com/YOUR_USERNAME/MacroTemplateKit.git
cd MacroTemplateKit
swift build
swift test
```

## Local Validation
Before opening a PR, run the same checks CI runs:

```bash
./scripts/ci-local.sh
```

If you prefer running commands individually:

```bash
swift-format lint --strict <changed-swift-files>
swiftlint lint --strict --config Sources/MacroTemplateKit/.swiftlint.yml Sources/MacroTemplateKit/
swiftlint lint --strict --config Tests/MacroTemplateKitTests/.swiftlint.yml Tests/MacroTemplateKitTests/
swift test --parallel -Xswiftc -warnings-as-errors
./scripts/change-budget.sh --mode range --base origin/main --head HEAD
```

## Coding Standards
- Follow Swift API Design Guidelines.
- Use 2-space indentation.
- Maximum line length: 100 characters.
- Use meaningful names.
- Add `///` documentation comments for public APIs.
- Update README or DocC content for significant user-facing changes.

## Commit Messages
This repository enforces Conventional Commits plus repository-specific body requirements.

Format:

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

Required body fields:

```text
Description:
- Summary: <what changed>
- Breaking Rule: yes|no
- Breaking API Rule: yes|no
- Breaking API Commit: yes|no
```

Rules:
- type must be lowercase
- subject must be lowercase
- no period at the end of the subject
- header length must be <= 100 characters
- commits should be atomic and scoped to one logical change
- do not include `Co-authored-by:` or other author trailers unless repository policy explicitly allows them

## Pull Requests
1. Sync with `main`.
2. Create a short-lived branch only if needed.
3. Make one focused logical change.
4. Run local validation.
5. Open a small PR against `main`.

### PR checklist
- [ ] all tests pass
- [ ] no compiler warnings
- [ ] documentation updated when needed
- [ ] changelog updated for user-facing changes
- [ ] change budget is acceptable or the work is explicitly approved as an exception
- [ ] incomplete work is protected by a feature flag or not merged

## Release Process
Releases are managed by maintainers and documented in `RELEASING.md`.
Do not cut releases from a side branch.
Release from validated `main`.

## Getting Help
- Questions: open a GitHub Discussion
- Bugs: open a GitHub Issue
- Security: contact maintainers privately

## License
By contributing, you agree that your contributions will be licensed under the MIT License.
