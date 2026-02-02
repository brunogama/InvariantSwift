# Technology Stack

**Analysis Date:** 2026-01-23

## Languages

**Primary:**
- Swift 6.0+ - Core library implementation, all source code in `Sources/InvariantSwift/`
- Swift 6.2 - Swift Package Manager specification (`Package.swift`)

**Secondary:**
- Python 3 - Development utilities and CI/CD helpers (batch testing, scripts)
- YAML - GitHub Actions workflow configuration
- JSON - Configuration files and test reporting

## Runtime

**Environment:**
- Swift 6.0+ compiler (via SwiftPM)
- macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, macCatalyst 17+

**Package Manager:**
- Swift Package Manager (SwiftPM)
- Lockfile: `Package.resolved` (auto-managed by SwiftPM)

## Frameworks

**Core Testing:**
- Swift Testing (native) - Modern test runner for `@Test` attributes
- XCTest (via xcbeautify) - Legacy test infrastructure

**Macro System:**
- SwiftSyntax 602.0.0 (exact) - AST manipulation for `@PropertyTest`, `@Arbitrary`, `@StateMachine` macros
  - Location: `Sources/InvariantSwiftMacros/`
  - Modules: `SwiftSyntaxMacros`, `SwiftCompilerPlugin`, `SwiftParser`

**Build & Development:**
- Swift Compiler Plugin Support - Macro compilation infrastructure
- xcbeautify - Test output formatting

## Key Dependencies

**Critical:**
- `swift-syntax` (602.0.0, exact) - Macro implementation and code generation
  - Used in: `Sources/InvariantSwiftMacros/` for all macro expansion
  - Used in: `Sources/GhostwriterCLI/` for auto-test generation
  - Why pinned: SwiftSyntax major versions break compatibility; requires exact match for Swift 6.0+

- `swift-custom-dump` (1.3.3+) - Pretty-printing for test output
  - Used in: Test failure reporting (`Sources/InvariantSwift/SwiftTesting/FailureReporting.swift`)
  - Purpose: Readable diff/display of values in test failures

- `swift-benchmark` (0.1.2+) - Performance benchmarking
  - Used in: `Benchmarks/` executable target
  - Purpose: Microbenchmarking of generator and shrinking performance

**Infrastructure:**
- SQLite3 (via Darwin/Foundation) - Local persistent corpus storage
  - Used in: `Sources/InvariantSwift/Database/CorpusDatabase.swift`
  - Purpose: Store regression examples and coverage-guided corpus

- Foundation - Core types and system interfaces
  - Used in: All targets
  - Provides: JSON encoding/decoding, file I/O, subprocess support

- Dispatch - Concurrency primitives
  - Used in: Telemetry and observability systems
  - Provides: DispatchQueue for background tasks

- os (Darwin) - System logging
  - Used in: `Sources/InvariantSwift/Observability/TelemetrySystem.swift`
  - Provides: os.log infrastructure

## Configuration

**Environment:**
- No external environment variables required for core library
- No secrets or API keys needed
- Optional CLI tools: `sourcekitten` (for enhanced type analysis, graceful fallback to regex)

**Build:**
- `.swift-format` - Code formatting rules (2-space indentation, 100-character line length)
  - Config path: `.swift-format`
  - Enforced in: Pre-commit hooks via `swiftlint` and `swift-format`

- `.swiftlint.yml` - Linting configuration
  - Config path: `.swiftlint.yml`
  - Style: Google Swift Style Guide
  - Strict mode enforced (warnings = errors)

- `Package.swift` - SwiftPM manifest
  - Defines: 6 library targets, 2 executable targets, 7 test targets, 2 plugin targets
  - Swift settings: `-strict-concurrency=complete`, `-warn-concurrency`

- `.pre-commit-config.yaml` - Git hooks
  - Runs: swiftlint, swift-format, documentation checks
  - Path: `.pre-commit-config.yaml`

## Platform Requirements

**Development:**
- Swift 6.0+ compiler
- Xcode 15.4+ (for IDE, not required for CLI)
- Docker (for Linux testing via `make test-linux`)
- Python 3.8+ (for helper scripts)
- macOS 14+ (recommended for full testing suite)

**Production/Distribution:**
- Minimum: iOS 17, macOS 14, tvOS 17, watchOS 10
- Supported: All Apple platforms (iOS, macOS, tvOS, watchOS, Catalyst)

**CI/CD:**
- GitHub Actions (`.github/workflows/`)
  - Test targets: Linux (Docker swift:6.0-jammy), macOS, iOS, tvOS
  - No external service dependencies
  - Self-contained within GitHub (no SaaS integrations for CI)

## Build & Release

**Build Command:**
```bash
swift build                              # Debug
swift build -c release                   # Optimized
swift build -Xswiftc -warnings-as-errors # Strict
```

**Test Command:**
```bash
swift test                      # All tests
swift test --filter <suite>     # Specific suite
```

**Code Quality:**
```bash
swiftlint lint --strict         # Linting
swift-format -i --recursive     # Formatting
make validate                   # Full pre-PR check
```

## Compiler Settings

**Strict Concurrency (all targets):**
```swift
.unsafeFlags([
  "-Xfrontend", "-strict-concurrency=complete",
  "-Xfrontend", "-warn-concurrency"
]),
.enableUpcomingFeature("StrictConcurrency")
```

**Testing Enabled (debug only):**
```swift
.unsafeFlags(["-enable-testing"], .when(configuration: .debug))
```

**No Warnings Allowed:**
- All compilation must use `-warnings-as-errors`
- SwiftLint in strict mode

## External Tools Used

**CLI Tools (optional, graceful fallback):**
- `sourcekitten` - Enhanced Swift type analysis for Ghostwriter
  - Path: `Sources/InvariantSwift/Ghostwriter/SourceKittenClient.swift`
  - Fallback: Regex-based parsing if unavailable

- `xcbeautify` - Format test output
  - Used in: Makefile test targets
  - Not required for tests to run (via `swift test` directly)

**Docker:**
- `swift:6.0-jammy` - Linux testing environment
  - Used in: `make test-linux`
  - Purpose: Verify cross-platform compatibility

---

*Stack analysis: 2026-01-23*
