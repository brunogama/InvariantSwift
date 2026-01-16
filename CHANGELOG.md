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
- Comprehensive roadmap task breakdown:
  * ROADMAP_TASK_BREAKDOWN.md (124 granular sub-tasks across 9 milestones)
  * Complete task metadata: IDs, titles, objectives, acceptance criteria, dependencies, effort estimates, file references
  * Master dependency graph showing task sequencing and critical path
  * 54 MVP tasks (Milestones 0-3: Naming, Core Generator, Swift Testing, @PropertyTest)
  * 70 extension tasks (Milestones 4-9: Process Isolation, CLI, Model-Based, Coverage-Guided, Invariant Mining)
- Milestone 0: API Stabilization work begins
  * API_AUDIT.md (503 lines) - Complete audit of 82 public symbols across 11 categories
    - Identifies KEEP/RENAME/DEPRECATE status for all public APIs
    - Naming inconsistencies documented and recommendations provided
    - Usage patterns analyzed from test suite
  * PUBLIC_API_DESIGN.md (837 lines) - Production-ready API design
    - 4-module organization (Core, Generators, Advanced, Observability)
    - Namespace structure and protocol hierarchy specified
    - Naming standards and stability commitments documented
    - Pre-1.0 breaking change strategy (no deprecation bridges needed)
    - Ready for team review and approval before implementation
  * API_DOCUMENTATION_TEMPLATE.md (412 lines) - Comprehensive documentation standard
    - Required DocC elements for every public symbol
    - Category-specific templates (protocols, structs, enums, functions, operators)
    - Mathematical/functional programming API guidelines
    - Async properties and model-based testing documentation patterns
    - Compliance validation checklist for all 82 symbols
    - Examples of good vs. bad documentation
  * CLAUDE.md updated with "Documentation Guidelines" section
    - DocC standards and requirements (Milestones 0.3-0.4)
    - Documentation compliance rules and validation procedures
    - Building and validating DocC documentation
    - Functional programming concept documentation standards

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
