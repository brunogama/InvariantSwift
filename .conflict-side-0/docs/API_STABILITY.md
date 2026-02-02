# API Stability Guide

**InvariantSwift versioning and backwards compatibility commitments.**

---

## Semantic Versioning

InvariantSwift follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR** (x.0.0): Breaking API changes
- **MINOR** (0.x.0): New features, backwards compatible
- **PATCH** (0.0.x): Bug fixes, backwards compatible

## What Constitutes a Breaking Change

### Breaking Changes (Require MAJOR Version Bump)

- Removing a public type, function, or property
- Changing a public function's signature (parameters, return type)
- Changing the behavior of a public function in a way that breaks existing usage
- Removing a public protocol conformance
- Changing Swift version requirements
- Changing minimum platform versions

### Non-Breaking Changes (MINOR or PATCH)

- Adding new public types, functions, or properties
- Adding new protocol conformances
- Performance improvements
- Bug fixes that don't change documented behavior
- Documentation updates
- Internal refactoring

## Deprecation Policy

1. **Minimum 2 releases**: Deprecated APIs must remain functional for at least 2 minor releases before removal
2. **Compiler warnings**: Deprecated APIs are marked with `@available(*, deprecated, renamed:)` or `@available(*, deprecated, message:)`
3. **Migration guidance**: Deprecation messages include migration instructions
4. **CHANGELOG**: All deprecations are documented with alternatives

### Example Deprecation

```swift
@available(*, deprecated, renamed: "Runner")
public typealias PropertyRunner = Runner
```

## Stability Guarantees

### Stable APIs (1.0+)

Once InvariantSwift reaches 1.0:

- All public APIs in `InvariantSwift` module are stable
- Breaking changes only occur in major versions
- Deprecated APIs are supported for 2+ minor versions

### Pre-1.0 (Current)

- APIs may change between minor versions
- Breaking changes are documented in CHANGELOG
- Upgrade guide provided for significant changes

## Versioned Documentation

Each release includes:
- API reference documentation
- Migration guides for breaking changes
- CHANGELOG with all changes

## Reporting Issues

If you encounter an undocumented breaking change:
1. Check CHANGELOG for the release
2. Open an issue on GitHub
3. Include version numbers and code examples
