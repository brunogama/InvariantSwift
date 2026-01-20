# Contributing to FunctionalTesting

We love your input! We want to make contributing to FunctionalTesting as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

## Pull Request Process

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Development Setup

### Prerequisites

- Swift 6.0+
- Xcode 16.0+ (for iOS/macOS development)
- SwiftLint for code formatting

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/FunctionalTesting.git
   cd FunctionalTesting
   ```

2. **Install dependencies**
   ```bash
   swift package resolve
   ```

3. **Run the tests**
   ```bash
   swift test
   ```

4. **Run linting**
   ```bash
   swiftlint
   ```

## Code Style

We follow the Google Swift Style Guide with some modifications:

### Formatting
- Use 2 spaces for indentation
- Line length limit: 100 characters
- Use SwiftLint for automated formatting

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
Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semi-colons, etc.
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding missing tests
- `chore`: Changes to build process, tools, etc.

Examples:
```
feat(generators): add UUID generator
fix(shrinking): handle empty arrays correctly
docs(readme): update installation instructions
```

### Pull Request Guidelines

1. **Branch Naming**: Use descriptive names like `feat/uuid-generator` or `fix/shrinking-bug`

2. **PR Title**: Use conventional commit format

3. **PR Description**: Include:
   - What changes were made and why
   - How to test the changes
   - Any breaking changes
   - Links to related issues

4. **Checklist**:
   - [ ] Tests added/updated
   - [ ] Documentation updated
   - [ ] CHANGELOG.md updated
   - [ ] All tests pass
   - [ ] Code follows style guidelines
   - [ ] No breaking changes (or clearly documented)

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
- iOS 16.0+
- macOS 13.0+
- tvOS 16.0+
- watchOS 9.0+
- Linux (Ubuntu LTS)

## Getting Help

- **Discussions**: Use GitHub Discussions for questions and ideas
- **Issues**: Use GitHub Issues for bugs and feature requests
- **Discord**: Join our community Discord server (link in README)

## Recognition

Contributors will be:
- Listed in the CHANGELOG.md for their contributions
- Added to the README.md contributors section
- Given credit in release notes for significant contributions

## License

By contributing, you agree that your contributions will be licensed under the MIT License that covers the project. Feel free to contact the maintainers if that's a concern.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

Thank you for contributing to FunctionalTesting! 🎉