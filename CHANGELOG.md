# Changelog

All notable changes to FunctionalTesting will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Phase 1 Business Macros**: Complete implementation of business-friendly property testing macros
  - `@BusinessRule`: Transform business rules into comprehensive property-based tests with smart iteration calculation and business-friendly error reporting
  - `@SmartGenerator`: Automatic test data generation from type structure with semantic inference from property names
  - `@TestAllCases`: Systematic boundary and edge case testing for enums and structured types
- **Business Domain Generators**: New generators for common business types (currency, email, personName, age, percentage)
- **Enhanced Error Reporting**: BusinessRuleViolation with actionable business insights and remediation suggestions  
- **Complexity-Aware Testing**: Automatic iteration calculation based on function complexity and business risk factors
- Property-based testing framework for Swift
- Core generator system with integrated shrinking
- Mathematical law verification system
- Coverage-guided testing with 99% target
- Swift 6 concurrency support with async properties
- Macro system for automatic test generation (@PropertyTest)
- Integration with Swift Testing framework
- Advanced features: lens system, DICE, SMT solver support
- Comprehensive test suite with performance benchmarks
- CLI tool (`functest`) for property-based testing
- Swift Package Manager plugin integration

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Security
- N/A (initial release)

## [1.0.0] - 2025-09-12

### Added
- Initial release of FunctionalTesting framework
- Complete property-based testing framework with advanced features
- Core property testing with generators and shrinking
- Mathematical law verification and model-based testing
- Coverage-guided testing with 99% target
- Swift 6 concurrency support with async properties
- Macro system for automatic test generation
- Integration with Swift Testing framework
- Advanced features: lens system, DICE, SMT solver support
- Comprehensive test suite with performance benchmarks

[Unreleased]: https://github.com/your-org/FunctionalTesting/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/your-org/FunctionalTesting/releases/tag/v1.0.0
