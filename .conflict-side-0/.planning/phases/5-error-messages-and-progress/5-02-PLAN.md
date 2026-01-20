---
phase: 05-error-messages-progress
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - Sources/InvariantSwift/SwiftTesting/FailureReporting.swift
  - Sources/InvariantSwift/Core/FailureReport.swift
autonomous: true
user_setup: []

must_haves:
  truths:
    - "Failure messages include shrinking metrics (attempts, successful, reduction %)"
    - "Failure messages include both env var and macro reproduction syntax"
    - "Original and shrunk counterexamples both shown with clear distinction"
    - "Test name and failure reason prominently displayed"
  artifacts:
    - path: "Sources/InvariantSwift/Core/FailureReport.swift"
      provides: "shrinkingSummary computed property for Core FailureReport"
      contains: "shrinkingSummary"
    - path: "Sources/InvariantSwift/SwiftTesting/FailureReporting.swift"
      provides: "Enhanced formatVerboseMessage with shrinking metrics and repro commands"
      contains: "shrinkAttempts"
  key_links:
    - from: "FailureReporter.formatVerboseMessage"
      to: "SwiftTesting FailureReport"
      via: "Uses all report fields for comprehensive output"
      pattern: "report\\.shrink"
    - from: "Core FailureReport.format"
      to: "ReplayToken.replaySnippet"
      via: "Includes reproduction code snippet"
      pattern: "replaySnippet"
---

<objective>
Enhance failure messages to be comprehensive and actionable, including shrinking metrics, reproduction commands, and clear counterexample presentation.

Purpose: Enable developers to understand, reproduce, and debug property test failures quickly without manual investigation.

Output: Enhanced formatVerboseMessage in FailureReporting.swift, shrinkingSummary in Core/FailureReport.swift.
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

# Existing infrastructure - TWO SEPARATE FailureReport types exist:
# 1. Core/FailureReport.swift - used with ReplayToken, has: propertyName, outcome, iterations, discarded, counterexample, shrunkCounterexample, reason, replayToken
# 2. SwiftTesting/FailureReporting.swift - used in Swift Testing, has: testName, seed, originalValue, shrunkValue, iterationsBeforeFailure, shrinkAttempts, successfulShrinks, failureReason, totalTime
@Sources/InvariantSwift/SwiftTesting/FailureReporting.swift
@Sources/InvariantSwift/Core/FailureReport.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Enhance Core/FailureReport with shrinking summary</name>
  <files>
    Sources/InvariantSwift/Core/FailureReport.swift
  </files>
  <action>
Add computed properties to the CORE FailureReport struct (located at Sources/InvariantSwift/Core/FailureReport.swift).

IMPORTANT: This file is DIFFERENT from SwiftTesting/FailureReporting.swift. The Core FailureReport has these fields:
- propertyName: String
- outcome: PropertyResult
- iterations: Int
- discarded: Int
- counterexample: String
- shrunkCounterexample: String
- reason: FailureReason?
- replayToken: ReplayToken

1. Add `shrinkingSummary` computed property:
   ```swift
   /// Formatted shrinking summary for failure reports.
   /// Compares counterexample and shrunkCounterexample string lengths.
   public var shrinkingSummary: String {
     let originalLen = counterexample.count
     let shrunkLen = shrunkCounterexample.count
     guard originalLen > 0, shrunkLen < originalLen else {
       return "No shrinking performed"
     }
     let reduction = Int(Double(originalLen - shrunkLen) / Double(originalLen) * 100)
     return "Shrunk from \(originalLen) to \(shrunkLen) chars (\(reduction)% reduction)"
   }
   ```

2. Add `reductionPercentage` helper:
   ```swift
   /// Estimated reduction percentage based on string representation length.
   /// Returns nil if no meaningful reduction occurred (shrunk >= original or original empty).
   public var reductionPercentage: Int? {
     let originalLen = counterexample.count
     let shrunkLen = shrunkCounterexample.count
     guard originalLen > 0, shrunkLen < originalLen else { return nil }
     return Int(Double(originalLen - shrunkLen) / Double(originalLen) * 100)
   }
   ```

   NOTE: reductionPercentage uses string length as a proxy for reduction. This is intentional:
   - All counterexamples are converted to String representation already
   - Returns nil when no meaningful reduction (shrunk >= original)
   - This is a heuristic, not a precise measure

3. Update the existing `format()` method to include shrinking information:
   - After "Minimal counterexample:" section, add shrinking stats
   - Example: "Shrunk from 25 to 5 chars (80% reduction)"
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - grep -n "shrinkingSummary" Sources/InvariantSwift/Core/FailureReport.swift returns property
    - grep -n "reductionPercentage" Sources/InvariantSwift/Core/FailureReport.swift returns property
  </verify>
  <done>
    - Core/FailureReport has shrinkingSummary computed property
    - Core/FailureReport has reductionPercentage helper (returns nil when no reduction)
    - format() method includes shrinking stats
  </done>
</task>

<task type="auto">
  <name>Task 2: Enhance SwiftTesting FailureReporting verbose format</name>
  <files>
    Sources/InvariantSwift/SwiftTesting/FailureReporting.swift
  </files>
  <action>
Update `formatVerboseMessage(_ report: FailureReport)` in SwiftTesting/FailureReporting.swift to produce a comprehensive, actionable failure message.

IMPORTANT: This file contains a DIFFERENT FailureReport struct with these fields:
- testName: String
- seed: Seed
- originalValue: String
- shrunkValue: String
- iterationsBeforeFailure: Int
- shrinkAttempts: Int
- successfulShrinks: Int
- failureReason: FailureReason
- totalTime: TimeInterval
- classificationReport: String? (optional)

1. Restructure the verbose message format:
   ```swift
   private func formatVerboseMessage(_ report: FailureReport) -> String {
     var lines: [String] = []

     // Header
     lines.append("+" + String(repeating: "=", count: 78) + "+")
     lines.append("|" + " PROPERTY TEST FAILURE ".center(78) + "|")
     lines.append("+" + String(repeating: "=", count: 78) + "+")

     // Test info
     lines.append("|")
     lines.append("| Test: \(report.testName)")
     lines.append("| Reason: \(report.failureReason)")
     lines.append("|")

     // Counterexample section
     lines.append("+" + String(repeating: "-", count: 78) + "+")
     lines.append("| COUNTEREXAMPLE (minimal after shrinking):")
     lines.append("|")
     lines.append("|   \(report.shrunkValue)")
     lines.append("|")

     // Original if different
     if report.originalValue != report.shrunkValue {
       lines.append("| Original failing value:")
       lines.append("|   \(report.originalValue)")
       lines.append("|")
     }

     // Statistics
     lines.append("+" + String(repeating: "-", count: 78) + "+")
     lines.append("| STATISTICS:")
     lines.append("|   Iterations before failure: \(report.iterationsBeforeFailure)")
     lines.append("|   Shrink attempts: \(report.shrinkAttempts)")
     lines.append("|   Successful shrinks: \(report.successfulShrinks)")
     if report.totalTime > 0 {
       lines.append("|   Total time: \(String(format: "%.3f", report.totalTime))s")
     }
     lines.append("|")

     // Reproduction
     lines.append("+" + String(repeating: "-", count: 78) + "+")
     lines.append("| REPRODUCTION:")
     lines.append("|")
     lines.append("|   Environment variable:")
     lines.append("|     INVARIANT_SEED=\(report.seed.rawValue) swift test --filter \(report.testName)")
     lines.append("|")
     lines.append("|   In code (macro):")
     lines.append("|     @PropertyTest(seed: \(report.seed.rawValue), iterations: 1)")
     lines.append("|")

     // Classification if present
     if let classReport = report.classificationReport, !classReport.isEmpty {
       lines.append("+" + String(repeating: "-", count: 78) + "+")
       lines.append("| CLASSIFICATION:")
       for line in classReport.split(separator: "\n") {
         lines.append("|   \(line)")
       }
       lines.append("|")
     }

     lines.append("+" + String(repeating: "=", count: 78) + "+")

     return lines.joined(separator: "\n")
   }
   ```

2. Add a helper extension for string centering if not already present:
   ```swift
   private extension String {
     func center(_ width: Int) -> String {
       let padding = max(0, width - count)
       let leftPad = padding / 2
       let rightPad = padding - leftPad
       return String(repeating: " ", count: leftPad) + self + String(repeating: " ", count: rightPad)
     }
   }
   ```

3. Update `formatCompactMessage` to also include INVARIANT_SEED (not INVARIANT_SWIFT_SEED):
   - Change `report.reproductionCommand` usage to use INVARIANT_SEED directly
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - grep -n "INVARIANT_SEED=" Sources/InvariantSwift/SwiftTesting/FailureReporting.swift returns line
    - grep -n "@PropertyTest(seed:" Sources/InvariantSwift/SwiftTesting/FailureReporting.swift returns macro syntax
  </verify>
  <done>
    - Verbose message has clear sections: header, counterexample, statistics, reproduction
    - Both env var and macro reproduction syntax shown
    - Classification included when present
    - Uses INVARIANT_SEED consistently
  </done>
</task>

<task type="auto">
  <name>Task 3: Add tests for enhanced failure messages</name>
  <files>
    Tests/FunctionalTesting/ErrorMessageTests.swift (new)
  </files>
  <action>
Create `ErrorMessageTests.swift` with comprehensive tests for failure message formatting:

```swift
import Testing
import Foundation
@testable import InvariantSwift

@Suite("Error Message Tests")
struct ErrorMessageTests {

  @Test("Verbose message includes all sections")
  func verboseMessageSections() {
    let report = FailureReport(
      testName: "testArrayReverse",
      seed: Seed(value: 12345),
      originalValue: "[5, 3, 1, 2, 4]",
      shrunkValue: "[1, 0]",
      iterationsBeforeFailure: 42,
      shrinkAttempts: 15,
      successfulShrinks: 8,
      failureReason: .predicateFailed,
      totalTime: 0.5
    )

    let reporter = FailureReporter(verbose: true)
    let message = reporter.formatMessage(report)

    #expect(message.contains("PROPERTY TEST FAILURE"))
    #expect(message.contains("testArrayReverse"))
    #expect(message.contains("[1, 0]"))  // shrunk value
    #expect(message.contains("42"))  // iterations
    #expect(message.contains("15"))  // shrink attempts
    #expect(message.contains("INVARIANT_SEED=12345"))
    #expect(message.contains("@PropertyTest(seed: 12345"))
  }

  @Test("Compact message includes essential info")
  func compactMessageContent() {
    let report = FailureReport(
      testName: "testPositive",
      seed: Seed(value: 999),
      originalValue: "-5",
      shrunkValue: "-1",
      iterationsBeforeFailure: 10,
      shrinkAttempts: 3,
      successfulShrinks: 2,
      failureReason: .predicateFailed,
      totalTime: 0.1
    )

    let reporter = FailureReporter(verbose: false)
    let message = reporter.formatMessage(report)

    #expect(message.contains("-1"))  // counterexample
    #expect(message.contains("999"))  // seed
    #expect(message.contains("INVARIANT_SEED"))
  }

  @Test("Classification included when present")
  func classificationIncluded() {
    let report = FailureReport(
      testName: "testWithClassification",
      seed: Seed(value: 1),
      originalValue: "test",
      shrunkValue: "t",
      iterationsBeforeFailure: 5,
      shrinkAttempts: 2,
      successfulShrinks: 1,
      failureReason: .predicateFailed,
      totalTime: 0.2,
      classificationReport: "positive: 60%\nnegative: 40%"
    )

    let reporter = FailureReporter(verbose: true)
    let message = reporter.formatMessage(report)

    #expect(message.contains("CLASSIFICATION"))
    #expect(message.contains("positive: 60%"))
  }

  @Test("Core FailureReport shrinking summary")
  func coreFailureReportShrinking() {
    // Test the Core/FailureReport.swift type
    let token = ReplayToken(seed: 123, iterations: 100, maxDiscarded: 1000)
    let report = InvariantSwift.FailureReport(
      propertyName: "testProperty",
      outcome: .failed,
      iterations: 50,
      discarded: 5,
      counterexample: "[1,2,3,4,5]",
      shrunkCounterexample: "[1]",
      reason: .predicateFailed,
      replayToken: token
    )

    let formatted = report.format()
    #expect(formatted.contains("testProperty"))
    #expect(formatted.contains("Minimal counterexample"))
    #expect(formatted.contains("[1]"))
  }

  @Test("Core FailureReport reductionPercentage returns nil when no reduction")
  func coreFailureReportNoReduction() {
    let token = ReplayToken(seed: 123, iterations: 100, maxDiscarded: 1000)
    let report = InvariantSwift.FailureReport(
      propertyName: "testProperty",
      outcome: .failed,
      iterations: 50,
      discarded: 5,
      counterexample: "[1]",
      shrunkCounterexample: "[1]",  // Same as original - no reduction
      reason: .predicateFailed,
      replayToken: token
    )

    #expect(report.reductionPercentage == nil)
  }

  @Test("Core FailureReport reductionPercentage calculates correctly")
  func coreFailureReportReductionCalculation() {
    let token = ReplayToken(seed: 123, iterations: 100, maxDiscarded: 1000)
    let report = InvariantSwift.FailureReport(
      propertyName: "testProperty",
      outcome: .failed,
      iterations: 50,
      discarded: 5,
      counterexample: "1234567890",  // 10 chars
      shrunkCounterexample: "12",     // 2 chars = 80% reduction
      reason: .predicateFailed,
      replayToken: token
    )

    #expect(report.reductionPercentage == 80)
  }
}
```

Note: There are TWO FailureReport types - one in Core/FailureReport.swift and one in SwiftTesting/FailureReporting.swift. Test both, including edge cases for reductionPercentage.
  </action>
  <verify>
    - `swift build -Xswiftc -warnings-as-errors` passes
    - `swift test --filter ErrorMessageTests 2>&1 | head -20` shows test discovery
  </verify>
  <done>
    - Tests verify verbose message contains all required sections
    - Tests verify compact message contains essential info
    - Tests verify classification included when present
    - Tests verify both FailureReport types work correctly
    - Tests verify reductionPercentage returns nil when no reduction
  </done>
</task>

</tasks>

<verification>
1. Build verification: `swift build -Xswiftc -warnings-as-errors`
2. Test file exists: `ls Tests/FunctionalTesting/ErrorMessageTests.swift`
3. Verbose format includes: `grep -n "COUNTEREXAMPLE\|STATISTICS\|REPRODUCTION" Sources/InvariantSwift/SwiftTesting/FailureReporting.swift`
4. Uses correct env var: `grep -n "INVARIANT_SEED=" Sources/InvariantSwift/SwiftTesting/FailureReporting.swift`
5. Core FailureReport enhanced: `grep -n "shrinkingSummary\|reductionPercentage" Sources/InvariantSwift/Core/FailureReport.swift`
</verification>

<success_criteria>
- formatVerboseMessage produces clearly sectioned output (header, counterexample, stats, reproduction)
- Both INVARIANT_SEED env var and @PropertyTest macro syntax shown in reproduction section
- Shrinking metrics (attempts, successful, time) displayed
- Classification report included when present
- Core/FailureReport has shrinkingSummary and reductionPercentage helpers
- reductionPercentage returns nil when no reduction occurred
- Unit tests verify all message components including edge cases
- Zero warnings with -warnings-as-errors
</success_criteria>

<output>
After completion, create `.planning/phases/5-error-messages-and-progress/5-02-SUMMARY.md`
</output>
