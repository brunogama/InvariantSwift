---
phase: 05-error-messages-progress
plan: 03
type: execute
wave: 2
depends_on: ["5-01"]
files_modified:
  - Sources/InvariantSwift/Core/Property.swift
  - Sources/InvariantSwift/SwiftTesting/PropertyTestIntegration.swift
  - Tests/FunctionalTesting/ProgressIntegrationTests.swift
autonomous: true
user_setup: []

must_haves:
  truths:
    - "PropertyRunner emits progress during long-running tests when showProgress enabled"
    - "Progress output includes current iteration, total, percentage, and rate"
    - "Progress automatically suppressed for fast tests (< 5 seconds)"
    - "Progress works in CI environments (no TTY required)"
    - "Seed always logged on failure (FR-5.3) regardless of verbose setting"
  artifacts:
    - path: "Sources/InvariantSwift/Core/Property.swift"
      provides: "PropertyRunner with progress tracking in runProperty"
      contains: "progressReporter"
    - path: "Tests/FunctionalTesting/ProgressIntegrationTests.swift"
      provides: "Integration tests for progress tracking"
      exports: ["ProgressIntegrationTests"]
  key_links:
    - from: "PropertyRunner.runProperty iteration loop"
      to: "ProgressReporter.recordIteration"
      via: "Progress tracking calls emit() internally when threshold reached"
      pattern: "progressReporter.*recordIteration"
    - from: "PropertyRunner.runProperty .failure case"
      to: "Seed logging"
      via: "Always log seed when returning failure"
      pattern: "seed.*rawValue"
---

<objective>
Integrate ProgressReporter into PropertyRunner to emit progress updates during long-running property tests.

Purpose: Provide visibility into long-running tests so developers know tests aren't hung.

Output: PropertyRunner integration with progress tracking, integration tests verifying behavior.
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
@.planning/phases/5-error-messages-and-progress/5-01-PLAN.md

# Dependencies from Plan 01
@Sources/InvariantSwift/Core/PropertyRunner+Progress.swift
@Sources/InvariantSwift/Core/Property.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Integrate ProgressReporter into PropertyRunner</name>
  <files>
    Sources/InvariantSwift/Core/Property.swift
  </files>
  <action>
Update PropertyRunner.runProperty methods to use ProgressReporter when enabled:

1. Add a private helper to create ProgressReporter from config:
   ```swift
   private func makeProgressReporter(config: PropertyConfig) -> ProgressReporter? {
     guard config.showProgress else { return nil }
     return ProgressReporter(
       totalIterations: config.iterations,
       interval: config.progressInterval
     )
   }
   ```

2. Update the main `runProperty<T>(_ property: Property<T>, config: PropertyConfig)` method:
   - Create ProgressReporter at start if enabled
   - Track start time using CFAbsoluteTimeGetCurrent()
   - IMPORTANT: Inside the iteration loop, call `progressReporter.recordIteration(currentIteration)`
   - The recordIteration method INTERNALLY calls emit() when the threshold is reached (time or iteration based)
   - At end of test, check if we should suppress (fast test) and emit final summary if not suppressed

   Key integration points in the iteration loop (around line 825-900):
   ```swift
   // Before iteration loop
   var progressReporter = makeProgressReporter(config: config)
   let startTime = CFAbsoluteTimeGetCurrent()

   // Inside iteration loop, after incrementing successfulIterations
   // This is the CRITICAL wiring - recordIteration checks threshold and calls emit() internally
   if var reporter = progressReporter {
     reporter.recordIteration(successfulIterations)
     // Note: emit() is called INSIDE recordIteration when:
     //   - For .iterations(n): current % n == 0
     //   - For .seconds(t): elapsed since lastReportTime >= t
     //   - For .adaptive: either 1000 iterations OR 5 seconds
     progressReporter = reporter  // Copy back mutated struct
   }

   // After loop completes
   let totalTime = CFAbsoluteTimeGetCurrent() - startTime
   if config.showProgress && totalTime >= 5.0 {
     // Emit final summary (not suppressed for fast tests)
     let rate = Double(config.iterations) / totalTime
     print("Completed \(config.iterations) tests in \(String(format: "%.2f", totalTime))s (\(Int(rate)) tests/sec)")
   }
   ```

3. The ProgressReporter.recordIteration implementation (from Plan 5-01) should look like:
   ```swift
   mutating func recordIteration(_ current: Int) {
     let now = CFAbsoluteTimeGetCurrent()
     let shouldEmit: Bool

     switch interval {
     case .iterations(let n):
       shouldEmit = current % n == 0
     case .seconds(let t):
       shouldEmit = (now - lastReportTime) >= t
     case .adaptive:
       let iterationThreshold = current - lastReportedIteration >= 1000
       let timeThreshold = (now - lastReportTime) >= 5.0
       shouldEmit = iterationThreshold || timeThreshold
     }

     if shouldEmit {
       emit(current: current, elapsed: now - startTime)
       lastReportTime = now
       lastReportedIteration = current
     }
   }

   private func emit(current: Int, elapsed: TimeInterval) {
     let percent = Int(Double(current) / Double(totalIterations) * 100)
     let rate = elapsed > 0 ? Int(Double(current) / elapsed) : 0
     print("Progress: \(current)/\(totalIterations) (\(percent)%) - \(rate) tests/sec")
   }
   ```

4. Apply similar changes to other runProperty variants:
   - `runProperty<T: Sendable>(_ property: ThrowingProperty<T>, config: PropertyConfig)`
   - `runProperty<T: Sendable>(_ property: EvaluatingProperty<T>, config: PropertyConfig)`
   - Async variants if they exist

IMPORTANT: Since PropertyRunner is an actor, be careful with progress emission:
- Use nonisolated pattern for print() calls if needed
- Or capture progress data and emit outside the actor context
- The simplest approach: ProgressReporter is a struct with mutating methods, make it inout parameter or use local var

For actor isolation, the easiest pattern:
- Make ProgressReporter a simple struct that accumulates state
- At checkpoints, emit progress synchronously (print is safe from actors)
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - grep -n "progressReporter" Sources/InvariantSwift/Core/Property.swift returns integration points
    - grep -n "recordIteration" Sources/InvariantSwift/Core/Property.swift returns progress calls
    - grep -n "emit" Sources/InvariantSwift/Core/PropertyRunner+Progress.swift returns emit function (from Plan 5-01)
  </verify>
  <done>
    - PropertyRunner.runProperty creates ProgressReporter when showProgress enabled
    - Progress tracked during iteration loop via recordIteration
    - recordIteration internally calls emit() when threshold reached
    - Final summary emitted for long tests
  </done>
</task>

<task type="auto">
  <name>Task 2: Add seed logging on verbose mode and ALWAYS on failures</name>
  <files>
    Sources/InvariantSwift/Core/Property.swift
    Sources/InvariantSwift/SwiftTesting/PropertyTestIntegration.swift
  </files>
  <action>
1. Add seed logging at start of PropertyRunner.runProperty when verbose:
   ```swift
   // At start of runProperty, after seed resolution
   if config.verbose || config.verbosity == .verbose {
     print("Running property test with seed: \(seed.rawValue)")
   }
   ```

2. CRITICAL (FR-5.3): Add seed logging on failure ALWAYS (not just verbose):
   - When returning .failure case, ALWAYS log the seed for reproduction
   - This ensures seed is logged even in non-verbose mode for debugging

   ```swift
   // Before returning .failure result
   // FR-5.3: Always log seed on failure for reproducibility
   print("Property failed. Seed: \(seed.rawValue) - Reproduce: INVARIANT_SEED=\(seed.rawValue) swift test")
   return .failure(...)
   ```

3. Update PropertyTestIntegration.swift to log seed in Swift Testing context:
   - In `checkProperty` functions, log seed at start if verbose
   - On failure, include seed in Issue.record message (ALWAYS, not just verbose)

   In the async checkProperty function around line 182+:
   ```swift
   public func checkProperty<T: Sendable>(
     _ property: Property<T>,
     config: PropertyConfig = .default,
     file: StaticString = #file,
     line: UInt = #line
   ) async throws {
     let runner = PropertyRunner(seed: config.seed)

     // Log seed in verbose mode
     if config.verbose {
       print("Property test starting with seed: \(runner.seed.rawValue)")
     }

     let result = await runner.runProperty(property, config: config)

     switch result {
     case .success:
       break  // Test passed

     case .failure(_, let iterations, let shrunk, let reason, let seed):
       // FR-5.3: ALWAYS log seed on failure (not just verbose)
       let message = """
         Property failed after \(iterations) iterations.
         Counterexample: \(shrunk)
         Reason: \(reason)
         Seed: \(seed.rawValue)
         Reproduce: INVARIANT_SEED=\(seed.rawValue) swift test --filter <testName>
         """
       Issue.record(Comment(stringLiteral: message), sourceLocation: SourceLocation(fileID: String(describing: file), line: Int(line)))
       throw PropertyTestError.failed(counterexample: shrunk, reason: reason)

     case .gaveUp(let discarded, let iterations):
       // ... existing handling
     }
   }
   ```
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - grep -n "seed.*rawValue" Sources/InvariantSwift/Core/Property.swift returns seed logging
    - grep -n "INVARIANT_SEED" Sources/InvariantSwift/SwiftTesting/PropertyTestIntegration.swift returns env var reference
    - grep -n "Property failed.*Seed" Sources/InvariantSwift/Core/Property.swift confirms always-on failure logging
  </verify>
  <done>
    - Seed logged at start in verbose mode
    - Seed ALWAYS logged on failure with reproduction command (FR-5.3)
    - Swift Testing integration includes seed in failure messages
    - All failure paths include seed for reproducibility
  </done>
</task>

<task type="auto">
  <name>Task 3: Create integration tests for progress and seed logging</name>
  <files>
    Tests/FunctionalTesting/ProgressIntegrationTests.swift (new)
  </files>
  <action>
Create `ProgressIntegrationTests.swift` with integration tests:

```swift
import Testing
import Foundation
@testable import InvariantSwift

@Suite("Progress Integration Tests")
struct ProgressIntegrationTests {

  @Test("PropertyConfig with progress enabled")
  func progressConfigEnabled() {
    let config = PropertyConfig(
      iterations: 100,
      showProgress: true,
      progressInterval: .iterations(25)
    )

    #expect(config.showProgress == true)
    if case .iterations(let n) = config.progressInterval {
      #expect(n == 25)
    } else {
      Issue.record("Expected iterations interval")
    }
  }

  @Test("Progress suppressed for small iteration counts")
  func smallIterationSuppression() {
    // Progress should be suppressed for very fast tests
    // This tests the suppression logic indirectly
    var reporter = ProgressReporter(totalIterations: 10, interval: .adaptive)
    // For a 10-iteration test that completes in <5 seconds, progress is suppressed
    #expect(reporter.shouldSuppressProgress(testDuration: 0.5) == true)
  }

  @Test("PropertyRunner initializes with INVARIANT_SEED support")
  func runnerSeedSupport() async {
    // Test that runner can be initialized and uses seed
    let runner = PropertyRunner(seed: Seed(value: 42))
    // The seed should be 42 (explicit takes priority)
    #expect(runner.seed.rawValue == 42)
  }

  @Test("Seed appears in failure context")
  func seedInFailure() async {
    // Create a property that always fails
    let property = Property(generator: Gen<Int>.pure(0)) { _ in false }
    let runner = PropertyRunner(seed: Seed(value: 99999))
    let config = PropertyConfig(iterations: 1)

    let result = await runner.runProperty(property, config: config)

    if case .failure(_, _, _, _, let seed) = result {
      #expect(seed.rawValue == 99999)
    } else {
      Issue.record("Expected failure result")
    }
  }

  @Test("Verbose config enables logging")
  func verboseConfigLogging() {
    let config = PropertyConfig(verbose: true, verbosity: .verbose)
    #expect(config.verbose == true)
    #expect(config.verbosity == .verbose)
  }

  @Test("Adaptive progress interval defaults")
  func adaptiveIntervalDefaults() {
    let config = PropertyConfig(showProgress: true, progressInterval: .adaptive)
    if case .adaptive = config.progressInterval {
      // Adaptive is the default, this should pass
    } else {
      Issue.record("Expected adaptive interval")
    }
  }

  @Test("ProgressReporter recordIteration triggers emit at threshold")
  func recordIterationTriggersEmit() {
    // Test that recordIteration properly tracks state
    var reporter = ProgressReporter(totalIterations: 100, interval: .iterations(10))

    // After 10 iterations, should have emitted once
    for i in 1...10 {
      reporter.recordIteration(i)
    }
    // The emit happens internally - we can verify the reporter state
    #expect(reporter.lastReportedIteration == 10)
  }

  @Test("Seed always included in failure result regardless of verbose")
  func seedAlwaysInFailure() async {
    // FR-5.3: Verify seed is always available in failure results
    let property = Property(generator: Gen<Int>.pure(-1)) { _ in false }
    let runner = PropertyRunner(seed: Seed(value: 12345))
    let config = PropertyConfig(iterations: 1, verbose: false)  // Not verbose

    let result = await runner.runProperty(property, config: config)

    // Even with verbose=false, failure result must include seed
    if case .failure(_, _, _, _, let seed) = result {
      #expect(seed.rawValue == 12345)
    } else {
      Issue.record("Expected failure result with seed")
    }
  }
}
```

Note: Testing actual progress output is difficult without capturing stdout. These tests verify the configuration and integration points work correctly.
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - `swift test --filter ProgressIntegrationTests 2>&1 | head -20` shows test discovery
  </verify>
  <done>
    - Integration tests verify PropertyConfig with progress settings
    - Tests verify seed handling in runner and failures
    - Tests verify verbose configuration
    - Tests verify ProgressReporter recordIteration tracks state
    - Tests verify seed always in failure result (FR-5.3)
    - All tests compile and can be discovered
  </done>
</task>

</tasks>

<verification>
1. Build verification: `swift build -Xswiftc -warnings-as-errors`
2. Test file exists: `ls Tests/FunctionalTesting/ProgressIntegrationTests.swift`
3. Integration in runner: `grep -n "progressReporter\|showProgress" Sources/InvariantSwift/Core/Property.swift`
4. Seed logging (always on failure): `grep -c "Property failed.*Seed\|seed.*rawValue" Sources/InvariantSwift/Core/Property.swift` returns multiple occurrences
5. Emit wiring: `grep -n "recordIteration.*emit\|emit.*current" Sources/InvariantSwift/Core/PropertyRunner+Progress.swift` confirms emit integration
</verification>

<success_criteria>
- PropertyRunner.runProperty integrates ProgressReporter when showProgress enabled
- Progress emitted every N iterations or T seconds (configurable) via recordIteration -> emit() chain
- Progress suppressed for tests completing in < 5 seconds
- Seed logged at start (verbose) and ALWAYS on failure (FR-5.3)
- Swift Testing integration includes seed in failure messages
- Integration tests verify all configuration options work
- Integration tests verify FR-5.3 seed-always-on-failure requirement
- Zero warnings with -warnings-as-errors
</success_criteria>

<output>
After completion, create `.planning/phases/5-error-messages-and-progress/5-03-SUMMARY.md`
</output>
