# Contributing to InvariantSwift

We welcome contributions to InvariantSwift. This repository uses Git Flow: `main` holds
released code, `develop` is the integration branch, and your work goes on a `feature/` or
`bugfix/` branch cut from `develop`.

- Branch from `develop` and open your pull request against `develop`.
- Keep changes small and focused.
- Prefer the smallest mergeable slice.
- Hide incomplete work behind a feature flag or inactive path.
- Leave `main` alone. It advances only through a release or hotfix merge.

`WORKFLOW.md` describes the full branch model, including how releases and hotfixes are cut.

---

## Development Process

We use GitHub to host code, track issues and feature requests, and accept pull requests.

---

## Pull Request Process

1. Fork the repository and create a `feature/<area>-<topic>` branch from `develop`.
2. Make one focused logical change.
3. Add tests for code changes and update documentation for API changes.
4. Run the local validation commands.
5. Open a small pull request against `develop`.

An urgent fix to already-released code is the one exception: cut `hotfix/<topic>` from
`main` and say so in the pull request, so it can be merged into both `main` and `develop`.

---

## Development Setup

### Prerequisites

- Shared: Swift 6.2.4+
- Linux: Ubuntu LTS
- Apple platforms: Xcode 16.4+ on macOS 15.3+
- Optional: the git-flow AVH extension (`brew install git-flow-avh`) if you prefer
  `git flow` subcommands over plain git

### Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/brunogama/InvariantSwift.git
   cd InvariantSwift
   ```

2. **Install tooling**

   ```bash
   # macOS
   brew install just
   just setup

   # Linux
   curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
   ```

3. **Configure the branch model**

   ```bash
   scripts/gitflow-init.sh
   ```

   This points git-flow at `main` and `develop` and sets the branch prefixes. It is safe to
   run without the extension installed, and safe to re-run.

4. **Resolve dependencies**

   ```bash
   swift package resolve
   ```

5. **Build and test**

   ```bash
   swift build
   swift test
   ```

---

## Local Validation

Before opening a pull request, run the same gates CI runs:

```bash
just format
just lint
swift build -Xswiftc -warnings-as-errors
swift test --parallel
```

---

## Code Style

We follow the Google Swift Style Guide with some modifications:

### Formatting

- Use 2 spaces for indentation
- Line length limit: 100 characters
- Use swift-format for automated formatting and SwiftLint for linting

### Conventions

- Use descriptive variable names
- Prefer `let` over `var` when possible
- Use guard statements for early returns
- Document public APIs with triple-slash comments (`///`)

### Example

```swift
/// Generates random integers within a specified range.
///
/// - Parameter range: The range of integers to generate from
/// - Returns: A generator that produces integers in the given range
public static func int(in range: ClosedRange<Int>) -> Gen<Int> {
  Gen { rng, size in
    Int.random(in: range, using: &rng)
  }
}
```

---

## Testing Guidelines

### Test Structure

- Use Swift Testing framework for all tests
- Follow the Arrange-Act-Assert pattern
- Use descriptive test names that explain the behavior being tested

### Property Testing

- Add property tests for new generators
- Include edge cases and error scenarios
- Aim for 99%+ code coverage

### Example Test

```swift
@Test("Integer generator produces values in range")
func testIntegerGeneratorRange() {
  let range = -100...100
  let property = Property(generator: Gen.int(in: range)) { value in
    range.contains(value)
  }

  try checkProperty(property, config: PropertyConfig(iterations: 1000))
}
```

---

## Documentation

### API Documentation

- All public APIs must have documentation comments
- Include usage examples for complex APIs
- Document parameters, return values, and thrown errors

### README Updates

- Update README.md for new features
- Include code examples showing usage
- Update feature lists and compatibility information

### Changelog

- The release workflow generates `CHANGELOG.md` from Conventional Commits.
- Do not edit the generated file manually.
- Describe user-facing changes and migration steps in the PR description.

---

## Submitting Changes

### Commit Messages

This repository enforces Conventional Commits through `commitlint.config.js`:

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

Use `!` or a `BREAKING CHANGE:` footer to identify a breaking change.

Rules:

- Keep the type and subject lowercase.
- Do not end the subject with a period.
- Keep the header and every body line at or below 100 characters.
- Keep each commit atomic and scoped to one logical change.
- Do not include AI agent `Co-authored-by:` trailers.

Types:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting only
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or fixing tests
- `build`: Build system or dependency changes
- `ci`: CI configuration
- `chore`: Maintenance tasks
- `revert`: Revert a previous change

Examples:

```text
feat(generators): add uuid generator
fix(shrinking): handle empty arrays correctly
docs(readme): update installation instructions
```

### Pull Request Guidelines

1. **Branch Naming**: Use the Git Flow prefix for the branch's role, such as
   `feature/uuid-generator`, `bugfix/shrinking-bug`, or `hotfix/coverage-helper-path`.
2. **PR Title**: Use Conventional Commit format.
3. **PR Description**: Explain what changed, why, how to test it, and any breaking changes.
4. **Checklist**:
   - [ ] Tests added or updated
   - [ ] Documentation updated when needed
   - [ ] User-facing changes described for the generated release notes
   - [ ] All validation gates pass
   - [ ] The pull request targets `develop`, or `main` for a release or hotfix
   - [ ] Incomplete work is protected by a feature flag or not merged

---

## Issue Reporting

### Bug Reports

Include:

- Swift version
- Platform (iOS, macOS, etc.) and version
- Minimal code example that reproduces the issue
- Expected vs. actual behavior
- Stack trace or error messages

### Feature Requests

Include:

- Use case and motivation
- Proposed API (if applicable)
- Examples of how it would be used
- Alternatives you've considered

---

## Architecture Guidelines

### Core Principles

- **Composability**: New features should work well with existing ones
- **Performance**: Maintain high performance standards
- **Safety**: Prefer compile-time safety over runtime checks
- **Simplicity**: APIs should be easy to understand and use

### Adding New Generators

1. Implement the generator function
2. Add comprehensive tests
3. Update documentation
4. Add usage examples

### Adding New Features

1. Discuss in an issue first for large changes
2. Consider backwards compatibility
3. Add tests and documentation
4. Update relevant examples

---

## Performance Considerations

- Property tests should run efficiently (>10,000 generations/second for simple types)
- Memory usage should be reasonable for large data structures
- Shrinking should complete quickly (<100ms for typical cases)

---

## Platform Support

Ensure new features work on all supported platforms:

- iOS 17.0+
- macOS 14.0+
- tvOS 17.0+
- watchOS 10.0+
- Linux (Ubuntu LTS)

---

## Getting Help

- Questions: open a GitHub Discussion
- Bugs: open a GitHub Issue
- Security: contact maintainers privately

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.
