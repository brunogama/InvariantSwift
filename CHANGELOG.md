# Changelog

All notable changes to FunctionalTesting will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
- CodeRabbit automated code review configuration with Swift-specific optimizations
- Comprehensive architecture documentation suite:
  * InvariantSwift-architecture.md (37 KB, 18 sections, 13 diagrams, 6 ADRs)
  * SHARDING-GUIDE.md for team-distributed ownership
  * README.md navigation hub for documentation suite
  * sections/ directory with pre-sharded architecture sections (17 files + index)
- Developer onboarding and quick start guides:
  * ONBOARDING.md (1,297 lines) - Complete developer onboarding guide
  * QUICKSTART.md (158 lines) - 10-minute quick start guide
  * README_IMPROVEMENTS.md (359 lines) - README improvement analysis
  * .claude/commands/tools/onboarding.md - Onboarding analysis template

### Changed
- Remove swift-docs-generation pre-commit hook
- Clean up duplicate Swift format configuration files
- Add Claude Code development workflow configuration
- **Migrate main library target from FunctionalTesting to InvariantSwift**
- Reorganize source files from FunctionalTesting/ to InvariantSwift/
- Reorganize test files from FunctionalTestingTests/ to FunctionalTesting/

### Deprecated
- N/A (initial release)

### Removed
- ClassificationCoverage.swift (obsolete coverage file)

### Fixed
- Clean up duplicate content in CodeRabbit configuration file
- Fix compilation errors in DICE.swift, Seed.swift, CombinatorGenerators.swift (isEmpty checks)
- Fix generic parameter naming collision in ModelTesting.swift (Command → CommandType)
- Fix FuncTestCLI/main.swift: actor-isolated method calls, Property API usage, RandomNumberGenerator types
- Fix Package.swift to exclude LawGeneration.swift.disabled file
- Ensure Swift 6 strict concurrency compliance across all targets
- Apply linter corrections for code style consistency

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
