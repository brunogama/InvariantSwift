# External Integrations

**Analysis Date:** 2026-01-23

## APIs & External Services

**None (by design).**

InvariantSwift is a pure Swift library with no HTTP/REST API clients, cloud platform SDKs (AWS, Azure, GCP), or external service dependencies. The library is completely self-contained.

## Data Storage

**Databases:**
- SQLite3 (local file-based)
  - Location: `Sources/InvariantSwift/Database/CorpusDatabase.swift`
  - Purpose: Persistent storage of test examples, regression cases, and corpus for coverage-guided fuzzing
  - Implementation: Native SQLite3 bindings via Foundation
  - Mode: WAL (Write-Ahead Logging) for performance
  - Initialization: Auto-creates tables on first access, no external schema setup required
  - No remote database access

**File Storage:**
- Local filesystem only
  - Test artifacts: `.build/`, build output
  - Corpus files: User-configurable location (defaults to `~/.invariant-swift/corpus`)
  - Reports: JSON-based test reports written to local files
  - No cloud storage integration (S3, GCS, etc.)

**Caching:**
- In-memory (Sendable types)
  - Generator caches for deterministic replay (via `Seed`)
  - SourceKitten availability check cache
  - No external cache service (Redis, Memcached, etc.)

## Authentication & Identity

**Auth Provider:**
- Custom (internal only)
  - No user authentication system
  - No API keys or tokens
  - No external identity providers (OAuth, SSO, etc.)
  - All authentication/identity concerns are user-application-specific

## Monitoring & Observability

**Error Tracking:**
- None (by design)
  - Errors are reported inline as Property failures
  - No Sentry, Datadog, or cloud error tracking integration
  - Test failures captured in JSON reports written to disk

**Logs:**
- Standard `os.log` infrastructure (macOS/iOS native)
  - Location: `Sources/InvariantSwift/Observability/TelemetrySystem.swift`
  - Configurable verbosity via `TelemetrySystem.Config`
  - No centralized log aggregation (ELK, Splunk, etc.)
  - Output: System logging visible via Console.app or `log stream` CLI
  - JSON test reports can be integrated with external systems by users

**Metrics:**
- In-memory telemetry collection
  - Location: `Sources/InvariantSwift/Observability/TelemetrySystem.swift`
  - Exports: JSON serializable metrics snapshots
  - Buffering: Configurable batch size and flush interval
  - No external metrics platform integration
  - User can export metrics for analysis

## CI/CD & Deployment

**Hosting:**
- GitHub (repository hosting only)
  - No cloud deployment infrastructure
  - Swift Package Index (auto-discovered, no manual registration)

**CI Pipeline:**
- GitHub Actions (self-hosted on GitHub infrastructure)
  - Workflow files: `.github/workflows/`
    - `ci.yml` - Main test pipeline (Linux Docker, macOS, iOS, tvOS)
    - `benchmarks.yml` - Performance benchmarking
    - `format.yml` - Code formatting checks
    - `documentation.yml` - DocC documentation building
    - `mutation-testing.yml` - Mutation testing CI
  - No external CI service (Travis, CircleCI, etc.)
  - No SaaS integrations for test reporting

**Publishing:**
- Swift Package Index (automatic)
  - Auto-discovered from GitHub repository
  - No special publishing pipeline required
  - Semantic versioning via git tags

## Environment Configuration

**Required env vars:**
- None - Library works with zero configuration out of the box

**Optional env vars:**
- None documented
- Configuration is entirely API-based via Swift code (e.g., `PropertyConfig`, `TelemetrySystem.Config`)

**Secrets location:**
- Not applicable - No secrets or credentials needed
- `.env` files: Not used
- Credentials: None required

**Build-time configuration:**
- `swift-format` config file: `.swift-format`
- `swiftlint` config file: `.swiftlint.yml`
- `Package.swift` defines all dependencies and targets

## Webhooks & Callbacks

**Incoming:**
- None
  - No webhook endpoints
  - No callback registration system
  - Tests run locally/in CI, no external triggers

**Outgoing:**
- None (by design)
  - Library does not initiate external requests
  - No callbacks to third-party services
  - No push notifications or webhooks

## Integration Points for Users

While the library itself has no external integrations, it provides integration points for users to add their own:

**Test Reporting Integration:**
- JSON export of test results
  - File: `Sources/InvariantSwift/Core/RunReport.swift`
  - Format: `Codable` JSON structure
  - Users can parse and send to external systems (CI/CD, dashboards, etc.)

**Corpus Export/Import:**
- Serializable test corpus
  - File: `Sources/InvariantSwift/Database/CorpusDatabase.swift`
  - Users can export corpus and integrate with coverage tools or other PBT frameworks

**Custom Generators with External Data:**
- Generator combinators support user-provided data
  - Location: `Sources/InvariantSwift/Generators/`
  - Users can build generators that fetch data from APIs, databases, etc.

**Telemetry Export:**
- Configurable telemetry collection with manual export
  - File: `Sources/InvariantSwift/Observability/TelemetrySystem.swift`
  - Users can export metrics and integrate with monitoring systems

## Security & API Safety

**No network surface:**
- Library makes zero network requests
- No DNS lookups (except optional `sourcekitten` CLI tool, which is local)
- Safe for sandboxed/offline environments
- Safe for supply chain (no external dependencies at runtime)

**Cryptographic operations:**
- None built into library
- Users can generate secure data via generators
- Seed-based reproducibility uses stdlib `Random`

**Subprocess Safety:**
- Subprocess spawning for test isolation
  - Location: `Sources/InvariantSwift/Core/SubprocessIsolation.swift`
  - Explicit child process spawning for crash isolation
  - No shell execution (safe from injection)
  - User-controlled and tested

---

*Integration audit: 2026-01-23*
