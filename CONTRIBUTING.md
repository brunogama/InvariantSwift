# Contributing to InvariantSwift

We welcome contributions to InvariantSwift. This repository uses trunk-based development with `main` as the target branch.

- Keep changes small and focused.
- Prefer the smallest mergeable slice.
- Use a short-lived branch and merge it back quickly.
- Hide incomplete work behind a feature flag or inactive path.
- Do not rely on long-lived feature or release branches.

## Development Process

We use GitHub to host code, track issues and feature requests, and accept pull requests.

## Pull Request Process

1. Fork the repository and create a short-lived branch from `main`.
2. Make one focused logical change.
3. Add tests for code changes and update documentation for API changes.
4. Run the local validation commands.
5. Open a small pull request against `main`.

## Development Setup

### Prerequisites

- Swift 6.2.4+
- Xcode 16.4+
- macOS 14+

### Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/brunogama/InvariantSwift.git
   cd InvariantSwift
   ```

2. **Install tooling**

   ```bash
   make setup
   ```

3. **Resolve dependencies**

   ```bash
   swift package resolve
   ```

4. **Build and test**

   ```bash
   swift build
   swift test
   ```

## Local Validation

Before opening a pull request, run the same gates CI runs:

```bash
make format
make lint
swift build -Xswiftc -warnings-as-errors
swift test --parallel
scripts/change-budget.sh --mode range --base origin/main --head HEAD
```

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

- Add entries to CHANGELOG.md for all changes
- Follow [Keep a Changelog](https://keepachangelog.com/) format
- Categorize changes as Added, Changed, Deprecated, Removed, Fixed, or Security

## Submitting Changes

### Commit Messages

This repository enforces Conventional Commits plus repository-specific body fields:

```text
<type>(<scope>): <subject>

Description:
- Summary: <what changed>
- Breaking Rule: yes|no
- Breaking API Rule: yes|no
- Breaking API Commit: yes|no
```

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

1. **Branch Naming**: Use short names such as `feat/uuid-generator` or `fix/shrinking-bug`.
2. **PR Title**: Use Conventional Commit format.
3. **PR Description**: Explain what changed, why, how to test it, and any breaking changes.
4. **Checklist**:
   - [ ] Tests added or updated
   - [ ] Documentation updated when needed
   - [ ] CHANGELOG.md updated for user-facing changes
   - [ ] All validation gates pass
   - [ ] The change budget is acceptable
   - [ ] Incomplete work is protected by a feature flag or not merged

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

## Performance Considerations

- Property tests should run efficiently (>10,000 generations/second for simple types)
- Memory usage should be reasonable for large data structures
- Shrinking should complete quickly (<100ms for typical cases)

## Platform Support

Ensure new features work on all supported platforms:

- iOS 17.0+
- macOS 14.0+
- tvOS 17.0+
- watchOS 10.0+
- Linux (Ubuntu LTS)

## Getting Help

- Questions: open a GitHub Discussion
- Bugs: open a GitHub Issue
- Security: contact maintainers privately

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.
