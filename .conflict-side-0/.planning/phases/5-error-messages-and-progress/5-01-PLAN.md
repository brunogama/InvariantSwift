---
phase: 05-error-messages-progress
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Sources/InvariantSwift/Core/Property.swift
  - Sources/InvariantSwift/Core/PropertyRunner+Progress.swift
  - Sources/InvariantSwift/SwiftTesting/FailureReporting.swift
autonomous: true
user_setup: []

must_haves:
  truths:
    - "PropertyRunner reads INVARIANT_SEED env var when no explicit seed provided"
    - "PropertyConfig has showProgress and progressInterval settings"
    - "Progress output appears every N seconds or M iterations for long tests"
    - "Progress suppressed for fast tests (< 5 seconds)"
  artifacts:
    - path: "Sources/InvariantSwift/Core/Property.swift"
      provides: "PropertyConfig with showProgress and progressInterval"
      contains: "showProgress"
    - path: "Sources/InvariantSwift/Core/PropertyRunner+Progress.swift"
      provides: "ProgressReporter for tracking and emitting progress"
      exports: ["ProgressReporter", "ProgressInterval"]
  key_links:
    - from: "PropertyRunner.init"
      to: "ProcessInfo.environment[\"INVARIANT_SEED\"]"
      via: "Seed resolution with env var fallback"
      pattern: "environment.*INVARIANT_SEED"
    - from: "PropertyRunner.runProperty"
      to: "ProgressReporter"
      via: "Progress tracking during iteration loop"
      pattern: "progressReporter"
---

<objective>
Add progress tracking and INVARIANT_SEED environment variable support to PropertyRunner.

Purpose: Enable reproducibility via environment variable and provide visibility into long-running property tests.

Output: PropertyConfig with progress settings, ProgressReporter utility, seed env var reading in PropertyRunner.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/5-error-messages-and-progress/5-RESEARCH.md

# Existing infrastructure
@Sources/InvariantSwift/Core/Property.swift
@Sources/InvariantSwift/SwiftTesting/FailureReporting.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add ProgressReporter and extend PropertyConfig</name>
  <files>
    Sources/InvariantSwift/Core/PropertyRunner+Progress.swift (new)
    Sources/InvariantSwift/Core/Property.swift
  </files>
  <action>
1. Create `PropertyRunner+Progress.swift` with:
   - `ProgressInterval` enum with cases: `.iterations(Int)`, `.seconds(TimeInterval)`, `.adaptive`
   - `ProgressReporter` struct with:
     - Properties: totalIterations, minInterval, minIterations, lastReportTime, lastReportedIteration, startTime
     - `init(totalIterations:interval:)` constructor
     - `mutating func recordIteration(_ current: Int)` that checks time/iteration thresholds
     - `private func emit(current:elapsed:)` that prints progress line
     - `func shouldSuppressProgress(testDuration: TimeInterval) -> Bool` returning true if < 5 seconds
   - Use `CFAbsoluteTimeGetCurrent()` for timing (low overhead)
   - Progress format: "Progress: {current}/{total} ({percent}%) - {rate} tests/sec"

2. Extend `PropertyConfig` in Property.swift:
   - Add `showProgress: Bool` property (default: false)
   - Add `progressInterval: ProgressInterval` property (default: .adaptive)
   - Update `init()` to include these parameters
   - Adaptive mode defaults to: every 1000 iterations OR 5 seconds, whichever first

Implementation note: Use nonisolated progress emission pattern - capture progress events and emit outside actor isolation to avoid blocking test execution. The ProgressReporter should be a struct that can be used from within the PropertyRunner actor but emit progress without holding actor lock.
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - grep -n "showProgress" Sources/InvariantSwift/Core/Property.swift returns property definition
    - grep -n "ProgressReporter" Sources/InvariantSwift/Core/PropertyRunner+Progress.swift returns struct
  </verify>
  <done>
    - PropertyConfig has showProgress and progressInterval properties
    - ProgressReporter struct exists with time-based throttling
    - Progress suppressed for tests < 5 seconds
  </done>
</task>

<task type="auto">
  <name>Task 2: Implement INVARIANT_SEED environment variable reading</name>
  <files>
    Sources/InvariantSwift/Core/Property.swift
    Sources/InvariantSwift/SwiftTesting/FailureReporting.swift
  </files>
  <action>
1. Modify `PropertyRunner.init(seed:)` in Property.swift to implement seed resolution priority:
   - Priority 1: Explicit seed parameter (if provided)
   - Priority 2: INVARIANT_SEED environment variable (parse as UInt64)
   - Priority 3: INVARIANT_SWIFT_SEED environment variable (for backwards compatibility)
   - Priority 4: Seed.random (system randomness)

   Implementation:
   ```swift
   public init(seed: Seed? = nil) {
     let actualSeed: Seed
     if let explicitSeed = seed {
       actualSeed = explicitSeed
     } else if let envSeed = Self.seedFromEnvironment() {
       actualSeed = envSeed
     } else {
       actualSeed = Seed.random
     }
     self.seed = actualSeed
     self.rng = SeedBasedRandomNumberGenerator(seed: actualSeed)
   }

   private static func seedFromEnvironment() -> Seed? {
     let env = ProcessInfo.processInfo.environment
     // Try INVARIANT_SEED first, then INVARIANT_SWIFT_SEED for backwards compatibility
     if let seedString = env["INVARIANT_SEED"] ?? env["INVARIANT_SWIFT_SEED"],
        let seedValue = UInt64(seedString) {
       return Seed(value: seedValue)
     }
     return nil
   }
   ```

2. Update reproduction commands in `FailureReporting.swift`:
   - Change `reproductionCommand` to use INVARIANT_SEED (not INVARIANT_SWIFT_SEED)
   - Keep INVARIANT_SWIFT_SEED in `reproductionEnvVar` as secondary option
   - Add macro reproduction syntax: `@PropertyTest(seed: {seed}, iterations: 1)`

   Update format to:
   ```
   Reproduce:
     INVARIANT_SEED={seed} swift test --filter {testName}
     OR in code: @PropertyTest(seed: {seed}, iterations: 1)
   ```
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - grep -n "INVARIANT_SEED" Sources/InvariantSwift/Core/Property.swift returns env reading
    - grep -n "seedFromEnvironment" Sources/InvariantSwift/Core/Property.swift returns helper function
  </verify>
  <done>
    - PropertyRunner reads INVARIANT_SEED env var when no explicit seed provided
    - Also reads INVARIANT_SWIFT_SEED for backwards compatibility
    - Reproduction commands updated with both env var and macro syntax
  </done>
</task>

<task type="auto">
  <name>Task 3: Add unit tests for progress and seed features</name>
  <files>
    Tests/FunctionalTesting/ProgressReporterTests.swift (new)
    Tests/FunctionalTesting/SeedEnvironmentTests.swift (new)
  </files>
  <action>
1. Create `ProgressReporterTests.swift`:
   ```swift
   import Testing
   @testable import InvariantSwift

   @Suite("Progress Reporter Tests")
   struct ProgressReporterTests {
     @Test("Progress interval parses correctly")
     func progressIntervalParsing() {
       let iterBased = ProgressInterval.iterations(1000)
       let timeBased = ProgressInterval.seconds(5.0)
       let adaptive = ProgressInterval.adaptive
       // Verify enum cases exist and are distinct
     }

     @Test("Progress suppressed for fast tests")
     func fastTestSuppression() {
       var reporter = ProgressReporter(totalIterations: 100, interval: .adaptive)
       #expect(reporter.shouldSuppressProgress(testDuration: 3.0) == true)
       #expect(reporter.shouldSuppressProgress(testDuration: 6.0) == false)
     }

     @Test("Progress config in PropertyConfig")
     func propertyConfigProgress() {
       let config = PropertyConfig(showProgress: true, progressInterval: .seconds(2.0))
       #expect(config.showProgress == true)
       if case .seconds(let interval) = config.progressInterval {
         #expect(interval == 2.0)
       } else {
         Issue.record("Expected seconds interval")
       }
     }
   }
   ```

2. Create `SeedEnvironmentTests.swift`:
   ```swift
   import Testing
   import Foundation
   @testable import InvariantSwift

   @Suite("Seed Environment Tests")
   struct SeedEnvironmentTests {
     @Test("Explicit seed takes priority over environment")
     func explicitSeedPriority() async {
       // Note: Can't easily set env vars in tests, but can verify priority logic
       let runner = PropertyRunner(seed: Seed(value: 42))
       #expect(runner.seed.rawValue == 42)
     }

     @Test("Reproduction command includes correct format")
     func reproductionCommandFormat() {
       let report = FailureReport(
         testName: "testExample",
         seed: Seed(value: 12345),
         originalValue: "[1,2,3]",
         shrunkValue: "[1]",
         iterationsBeforeFailure: 10,
         shrinkAttempts: 5,
         successfulShrinks: 3,
         failureReason: .predicateFailed,
         totalTime: 1.5
       )
       #expect(report.reproductionCommand.contains("INVARIANT_SEED=12345"))
     }
   }
   ```

Note: Use Swift Testing format with @Suite and @Test, not XCTest.
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - `swift test --filter ProgressReporterTests 2>&1 | head -20` shows test discovery
    - `swift test --filter SeedEnvironmentTests 2>&1 | head -20` shows test discovery
  </verify>
  <done>
    - ProgressReporterTests verify progress throttling and suppression
    - SeedEnvironmentTests verify seed priority and reproduction format
    - All tests compile and can be discovered
  </done>
</task>

</tasks>

<verification>
1. Build verification: `swift build -Xswiftc -warnings-as-errors`
2. New files exist:
   - `ls Sources/InvariantSwift/Core/PropertyRunner+Progress.swift`
   - `ls Tests/FunctionalTesting/ProgressReporterTests.swift`
   - `ls Tests/FunctionalTesting/SeedEnvironmentTests.swift`
3. PropertyConfig has new properties: `grep -n "showProgress\|progressInterval" Sources/InvariantSwift/Core/Property.swift`
4. Seed reading from env: `grep -n "INVARIANT_SEED" Sources/InvariantSwift/Core/Property.swift`
</verification>

<success_criteria>
- PropertyConfig has showProgress (default false) and progressInterval (default .adaptive) properties
- ProgressReporter struct provides time-based throttling for progress output
- PropertyRunner.init reads INVARIANT_SEED (and INVARIANT_SWIFT_SEED for compat) env var
- Reproduction commands include both env var and macro syntax
- Unit tests verify progress suppression and seed priority
- Zero warnings with -warnings-as-errors
</success_criteria>

<output>
After completion, create `.planning/phases/5-error-messages-and-progress/5-01-SUMMARY.md`
</output>
