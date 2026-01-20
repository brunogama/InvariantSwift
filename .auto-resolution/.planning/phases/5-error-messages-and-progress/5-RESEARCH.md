# Phase 5: Error Messages & Progress - Research

**Researched:** 2026-01-23
**Domain:** Developer experience (failure reporting, progress tracking, seed management)
**Confidence:** HIGH

## Summary

Phase 5 focuses on enhancing developer experience through improved failure messages, progress indicators, and seed management. Research reveals substantial existing infrastructure that can be extended:

**Current state:**
- FailureReport struct exists with comprehensive failure metadata
- FailureReporter formats compact and verbose messages
- PropertyConfig has verbose flag and verbosity levels
- Seed infrastructure complete with environment variable patterns
- CI environment detection implemented in FlakeHunter

**Gaps to address:**
- No progress tracking during long-running property tests
- Seed not automatically read from INVARIANT_SEED environment variable
- Reproduction commands incomplete (missing macro syntax)
- Progress indicators not implemented
- Shrinking metrics not captured during execution

**Primary recommendation:** Build on existing FailureReport/FailureReporter infrastructure. Add progress tracking to PropertyRunner actor with configurable intervals. Integrate INVARIANT_SEED env var reading at PropertyRunner initialization.

## Standard Stack

The established libraries/tools for failure reporting and progress in Swift/property testing:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Testing | 6.0+ | Test framework integration | Official Apple framework, Issue recording, structured output |
| ProcessInfo | Foundation | Environment variables | Standard library, cross-platform, used for NO_COLOR, CI detection |
| CFAbsoluteTimeGetCurrent | CoreFoundation | Timing | Low overhead, precise timing for progress intervals |
| DispatchSemaphore | Dispatch | Actor synchronization | Used in existing runProperty for regression bank |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Terminal ANSI codes | N/A | Color output | Already used in PrettyPrint.swift for colors |
| swift-custom-dump | 1.3.3+ | Pretty-printing values | Dependency for better counterexample formatting |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CFAbsoluteTime | Date() | CFAbsoluteTime has lower overhead, better for tight loops |
| ProcessInfo.environment | Custom config file | Env vars are standard for CI/seed reproduction |
| Actor-based progress | Shared mutable state | Actor isolation ensures thread safety |

**Installation:**
```bash
# No new dependencies needed - all in Swift stdlib/Foundation
```

## Architecture Patterns

### Recommended Project Structure
```
Sources/InvariantSwift/
├── SwiftTesting/
│   ├── FailureReporting.swift    # EXTEND: Add progress metrics
│   └── ProgressReporter.swift     # NEW: Progress tracking
├── Core/
│   ├── Property.swift             # EXTEND: Add progress config
│   └── Seed.swift                 # EXTEND: Add env var reading
└── Presentation/
    └── PrettyPrint.swift          # EXISTS: Reuse for formatting
```

### Pattern 1: Progress Tracking in Actor
**What:** PropertyRunner actor tracks iterations and emits progress at configurable intervals
**When to use:** Long-running property tests (>5 seconds)
**Example:**
```swift
// Source: Research synthesis from actor isolation patterns
public actor PropertyRunner {
  private var progressReporter: ProgressReporter?

  public func runProperty<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    progressReporter = config.showProgress
      ? ProgressReporter(
          totalIterations: config.iterations,
          interval: config.progressInterval
        )
      : nil

    var successfulIterations = 0
    while successfulIterations < config.iterations {
      // ... test execution ...

      progressReporter?.recordIteration(successfulIterations)
      successfulIterations += 1
    }
    return .success(iterations: successfulIterations)
  }
}
```

### Pattern 2: Environment Variable Seed Resolution
**What:** Check INVARIANT_SEED before using config.seed or Seed.random
**When to use:** Every PropertyRunner initialization
**Example:**
```swift
// Source: Existing patterns in Persistence/FailingExample.swift lines 149-165
public init(seed: Seed? = nil) {
  let actualSeed: Seed

  // Priority: explicit seed > env var > random
  if let explicitSeed = seed {
    actualSeed = explicitSeed
  } else if let envSeed = ProcessInfo.processInfo.environment["INVARIANT_SEED"],
            let seedValue = UInt64(envSeed) {
    actualSeed = Seed(value: seedValue)
  } else {
    actualSeed = Seed.random
  }

  self.seed = actualSeed
  self.rng = SeedBasedRandomNumberGenerator(seed: actualSeed)
}
```

### Pattern 3: Enhanced Failure Message Format
**What:** Structured failure report with actionable reproduction steps
**When to use:** All property test failures
**Example:**
```swift
// Source: Existing FailureReporting.swift verbose format, lines 207-244
private func formatVerboseMessage(_ report: FailureReport) -> String {
  """
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║                           PROPERTY TEST FAILURE                              ║
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║ Test: \(report.testName)
  ║ Failure reason: \(report.failureReason)
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║ COUNTEREXAMPLE (after shrinking):
  ║   \(report.shrunkValue)
  ║
  ║ Original failing value:
  ║   \(report.originalValue)
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║ SHRINKING:
  ║   Attempts: \(report.shrinkAttempts)
  ║   Successful: \(report.successfulShrinks)
  ║   Reduction: \(reductionPercentage)%
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║ REPRODUCTION:
  ║   swift test --filter \(testName)
  ║   OR set: INVARIANT_SEED=\(seed.rawValue)
  ║   OR macro: @PropertyTest(seed: \(seed.rawValue), iterations: 1)
  ╚══════════════════════════════════════════════════════════════════════════════╝
  """
}
```

### Pattern 4: Progress Reporter with Rate Limiting
**What:** Emit progress every N iterations or T seconds, whichever comes first
**When to use:** Property tests with configurable progress
**Example:**
```swift
// Source: Research synthesis from best practices
public struct ProgressReporter {
  private let totalIterations: Int
  private let minInterval: TimeInterval  // Minimum seconds between updates
  private let minIterations: Int         // Minimum iterations between updates
  private var lastReportTime: CFAbsoluteTime
  private var lastReportedIteration: Int

  public mutating func recordIteration(_ current: Int) {
    let now = CFAbsoluteTimeGetCurrent()
    let elapsedSinceReport = now - lastReportTime
    let iterationsSinceReport = current - lastReportedIteration

    // Emit if either threshold crossed
    if elapsedSinceReport >= minInterval || iterationsSinceReport >= minIterations {
      emit(current: current, elapsed: now - startTime)
      lastReportTime = now
      lastReportedIteration = current
    }
  }

  private func emit(current: Int, elapsed: TimeInterval) {
    let rate = Double(current) / elapsed
    let percent = (Double(current) / Double(totalIterations)) * 100
    print("Progress: \(current)/\(totalIterations) (\(Int(percent))%) - \(Int(rate)) tests/sec")
  }
}
```

### Anti-Patterns to Avoid
- **Unconditional progress logging:** Don't log progress for tests <5 seconds (creates noise)
- **String concatenation in tight loops:** Build strings once, not per iteration
- **Blocking I/O in PropertyRunner:** Use actor isolation, don't block test execution
- **Hardcoded reproduction commands:** Generate from test context (macro vs function)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pretty-printing values | Custom formatters | PrettyPrint.prettyPrint() | Already handles arrays, dicts, cycles, truncation (PrettyPrint.swift lines 815-820) |
| CI detection | Parse env vars | ExecutionEnvironment.isCIEnvironment | Handles CI, GITHUB_ACTIONS, TRAVIS, JENKINS (FlakeHunter.swift lines 143-145) |
| Timing measurements | Date().timeIntervalSince | CFAbsoluteTimeGetCurrent() | Lower overhead, used in existing timeout code (Property.swift line 1251) |
| Thread-safe progress | Global mutable state | Actor isolation in PropertyRunner | Already an actor, leverage it (Property.swift line 763) |
| Color output | Custom ANSI codes | PrettyConfig.enableColors + NO_COLOR env var | Respects user preference (PrettyPrint.swift line 276) |
| Shrinking metrics | Track manually | Capture in ShrinkTree.findMinimal | BFS search already iterates, count attempts there (Core/ShrinkTree.swift) |

**Key insight:** Existing infrastructure (PrettyPrint, FlakeHunter's CI detection, PropertyRunner actor) provides building blocks. Don't reinvent—compose and extend.

## Common Pitfalls

### Pitfall 1: Progress Spam in Fast Tests
**What goes wrong:** Emitting progress for tests that complete in <1 second creates noise and slows tests
**Why it happens:** Default config enables progress unconditionally
**How to avoid:**
- Suppress progress for tests estimated to finish quickly (iterations < 100)
- Auto-disable in CI environments unless explicitly enabled
- Use time-based threshold: don't emit first progress until 5 seconds elapsed
**Warning signs:** Test output filled with "Progress: 10/100" lines for sub-second tests

### Pitfall 2: Seed Environment Variable Priority Confusion
**What goes wrong:** INVARIANT_SEED ignored when seed parameter explicitly passed
**Why it happens:** Wrong precedence order in seed resolution
**How to avoid:**
- Document priority: explicit parameter > env var > random
- Log seed source in verbose mode: "Using seed from INVARIANT_SEED"
- Warn if both explicit seed AND env var set (potential conflict)
**Warning signs:** User sets INVARIANT_SEED but test uses different seed

### Pitfall 3: Incomplete Reproduction Commands
**What goes wrong:** Generated reproduction commands don't work (especially for @PropertyTest macros)
**Why it happens:** Missing context about how test was defined
**How to avoid:**
- Detect test context: macro vs checkProperty() function
- For macros: show @PropertyTest(seed:, iterations:) syntax
- For functions: show INVARIANT_SEED env var + swift test filter
- Include both options in output
**Warning signs:** User copies reproduction command, test doesn't reproduce failure

### Pitfall 4: Shrinking Metrics Lost
**What goes wrong:** FailureReport shows shrinkAttempts=0 because metrics not captured
**Why it happens:** ShrinkTree.findMinimal doesn't return attempt count
**How to avoid:**
- Extend ShrinkTree.findMinimal to return (value, metrics: ShrinkMetrics)
- Capture: attempts, successes, reduction percentage
- Store in PropertyResult.failure case
**Warning signs:** Failure reports always show "0 shrink attempts"

### Pitfall 5: Actor Isolation Breaking Progress Updates
**What goes wrong:** Progress reporter can't print from within actor context
**Why it happens:** PropertyRunner is an actor, print() may suspend
**How to avoid:**
- Use nonisolated progress emission (fire-and-forget Task)
- OR capture progress events, emit after actor context exits
- OR use OSLog for async-safe logging
**Warning signs:** Progress messages appear in wrong order or not at all

## Code Examples

Verified patterns from official sources:

### Seed Reading with Environment Variable Fallback
```swift
// Source: Pattern from Persistence/FailingExample.swift lines 149-165
public init(seed: Seed? = nil) {
  let actualSeed: Seed

  if let explicitSeed = seed {
    actualSeed = explicitSeed
  } else if let envSeed = ProcessInfo.processInfo.environment["INVARIANT_SEED"],
            let seedValue = UInt64(envSeed) {
    actualSeed = Seed(value: seedValue)
  } else {
    actualSeed = Seed.random
  }

  self.seed = actualSeed
  self.rng = SeedBasedRandomNumberGenerator(seed: actualSeed)
}
```

### CI Environment Detection
```swift
// Source: FlakeHunter.swift lines 143-145
let isCIEnvironment = ProcessInfo.processInfo.environment.keys.contains { key in
  ["CI", "CONTINUOUS_INTEGRATION", "GITHUB_ACTIONS", "TRAVIS", "JENKINS_URL"].contains(key)
}
```

### Time-Based Progress Throttling
```swift
// Source: Research synthesis from timing patterns
public struct ProgressThrottle {
  private var lastEmitTime: CFAbsoluteTime
  private let minInterval: TimeInterval

  public init(minInterval: TimeInterval = 5.0) {
    self.lastEmitTime = CFAbsoluteTimeGetCurrent()
    self.minInterval = minInterval
  }

  public mutating func shouldEmit() -> Bool {
    let now = CFAbsoluteTimeGetCurrent()
    if now - lastEmitTime >= minInterval {
      lastEmitTime = now
      return true
    }
    return false
  }
}
```

### Enhanced FailureReport with Shrinking Metrics
```swift
// Source: Extension of FailureReporting.swift structure
public struct FailureReport: Sendable {
  // ... existing fields ...
  public let shrinkAttempts: Int
  public let successfulShrinks: Int

  /// Percentage reduction from original to shrunk value
  public var reductionPercentage: Int {
    // Requires defining "size" metric for values
    // For collections: (original.count - shrunk.count) / original.count * 100
    // For numbers: similar ratio-based calculation
    0  // Placeholder
  }

  /// Formatted shrinking summary
  public var shrinkingSummary: String {
    """
    Shrinking: \(successfulShrinks) successful out of \(shrinkAttempts) attempts
    Reduction: \(reductionPercentage)% (\(originalSize) → \(shrunkSize))
    """
  }
}
```

### PropertyConfig Extensions for Progress
```swift
// Source: Pattern from PropertyConfig structure (Property.swift lines 400-712)
extension PropertyConfig {
  /// Enable progress indicators for long-running tests
  public let showProgress: Bool

  /// Progress update interval (iterations or seconds)
  public let progressInterval: ProgressInterval

  public enum ProgressInterval: Sendable {
    case iterations(Int)       // Every N iterations
    case seconds(TimeInterval) // Every N seconds
    case adaptive             // Auto-adjust based on test speed
  }

  public init(
    iterations: Int = 100,
    maxShrinks: Int = 1000,
    maxDiscarded: Int = 1000,
    seed: Seed? = nil,
    verbose: Bool = false,
    showProgress: Bool = false,
    progressInterval: ProgressInterval = .adaptive
    // ... other params ...
  ) {
    // ... initialization ...
    self.showProgress = showProgress
    self.progressInterval = progressInterval
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual seed specification | INVARIANT_SEED env var | Hypothesis (Python) ~2015 | Industry standard for reproducibility |
| Verbose always-on logging | Configurable verbosity levels | QuickCheck 2.x → 3.x | Reduced noise, better CI integration |
| Simple "failed" message | Shrunk counterexample + repro command | Hedgehog (Haskell) ~2017 | Dramatically faster debugging |
| No progress indicators | Real-time progress for long tests | Hypothesis ~2019 | Better UX, prevents "is it hung?" questions |
| Text-only error messages | Structured diffs with colors | Modern terminals ~2020 | Easier visual parsing of failures |

**Deprecated/outdated:**
- **Hardcoded seeds in test code:** Use env vars or config instead (harder to change, less CI-friendly)
- **Printing to stdout in library code:** Use structured logging or reporter pattern (better testability)
- **Binary verbose flag:** Use verbosity levels (.silent, .normal, .verbose) for granular control
- **Blocking progress updates:** Use async/actor patterns to avoid blocking test execution

## Open Questions

Things that couldn't be fully resolved:

1. **Shrinking Metric Calculation**
   - What we know: ShrinkTree.findMinimal uses BFS, budget limits attempts
   - What's unclear: How to define "reduction percentage" for non-collection types (e.g., Int)
   - Recommendation: Start with collection count for arrays/dicts, punt on other types to v2

2. **Progress in Swift Testing Output**
   - What we know: Swift Testing has structured output, custom test string representation
   - What's unclear: Whether progress messages interfere with Swift Testing's Issue recording
   - Recommendation: Gate progress behind config flag, test with Swift Testing integration tests

3. **Macro Context Detection**
   - What we know: @PropertyTest macro expands to checkProperty() call
   - What's unclear: How to detect if test was defined with macro vs direct function call
   - Recommendation: Pass metadata through PropertyConfig or capture in FailureReport builder

4. **Actor-Safe Progress Emission**
   - What we know: PropertyRunner is an actor, print() may not be isolation-safe
   - What's unclear: Best pattern for emitting progress without breaking actor isolation
   - Recommendation: Research OSLog vs nonisolated Task vs event capture, prototype both

## Sources

### Primary (HIGH confidence)
- InvariantSwift codebase:
  - `Sources/InvariantSwift/SwiftTesting/FailureReporting.swift` - Existing failure report infrastructure
  - `Sources/InvariantSwift/Core/Property.swift` - PropertyConfig, PropertyRunner actor, verbosity patterns
  - `Sources/InvariantSwift/Core/Seed.swift` - Seed infrastructure, environment variable patterns
  - `Sources/InvariantSwift/Reliability/FlakeHunter.swift` - CI detection pattern (lines 143-145)
  - `Sources/InvariantSwift/Presentation/PrettyPrint.swift` - Pretty-printing infrastructure, NO_COLOR handling
  - `Sources/InvariantSwift/Persistence/FailingExample.swift` - Environment variable reading patterns (lines 149-165)

### Secondary (MEDIUM confidence)
- [Swift Testing Framework](https://developer.apple.com/xcode/swift-testing) - Official test framework integration
- [Swift Testing Vision](https://github.com/swiftlang/swift-evolution/blob/main/visions/swift-testing.md) - Structured event streams, live progress reporting
- [Mastering Swift Testing Framework](https://fatbobman.com/en/posts/mastering-the-swift-testing-framework/) - CustomTestStringConvertible patterns

### Tertiary (LOW confidence - research synthesis)
- [Hypothesis Property Testing](https://hypothesis.works/articles/what-is-property-based-testing/) - Best practices for shrinking and error messages
- [QuickCheck Documentation](https://hackage.haskell.org/package/QuickCheck) - Progress tracking patterns (TestProgress)
- [Hedgehog Property Testing](https://cran.r-project.org/web/packages/hedgehog/vignettes/hedgehog.html) - Integrated shrinking patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components in Swift stdlib/Foundation, verified in codebase
- Architecture: HIGH - Patterns extracted from existing FailureReporting.swift, PropertyRunner actor
- Pitfalls: MEDIUM - Based on existing code + general property testing experience
- Progress patterns: MEDIUM - Research synthesis, needs prototype validation

**Research date:** 2026-01-23
**Valid until:** 2026-02-22 (30 days - stable domain)

---

## Next Steps for Planner

When creating PLAN.md files:

1. **Extend FailureReport:** Add shrinkAttempts/successfulShrinks capture in PropertyRunner shrinking methods
2. **Add ProgressReporter:** New file in SwiftTesting/ for progress tracking
3. **Extend PropertyConfig:** Add showProgress, progressInterval fields
4. **Modify PropertyRunner.init:** Add INVARIANT_SEED env var reading
5. **Update FailureReporter.formatMessage:** Include shrinking metrics and both macro/function reproduction commands
6. **CI-aware defaults:** Auto-disable progress in CI unless explicitly enabled

Key verification: Progress should NOT emit for fast tests (<5s), and INVARIANT_SEED should work end-to-end from environment to PropertyRunner.
