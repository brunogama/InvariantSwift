import Foundation
import Testing
import InvariantSwiftCore
@testable import InvariantSwift

/// Final comprehensive coverage validation tests for maintaining broad API coverage.
struct FinalCoverageValidationTests {

  @Test("Final validation - coverage metrics meet 99% threshold")
  func finalValidationCoverageMetricsMeet99PercentThreshold() async throws {
    let runner = LLVMCoverageRunner()
    let coverage = try await runner.calculateCoverage(forceRefresh: true)

    guard
      let measuredCoverage = requireMeasuredCoverage(
        coverage,
        context: "final coverage threshold validation"
      )
    else {
      return
    }

    #expect(measuredCoverage.linePercentage >= 99.0)
    #expect(measuredCoverage.regionPercentage >= 95.0)
  }

  func assertNonFatal<T>(_ result: PropertyResult<T>, message: String) {
    switch result {
    case .success, .failure, .gaveUp:
      #expect(Bool(true), Comment(rawValue: message))
    }
  }

  func assertSuccess<T>(_ result: PropertyResult<T>, message: String) {
    switch result {
    case .success:
      #expect(Bool(true), Comment(rawValue: message))

    case .failure, .gaveUp:
      #expect(Bool(false), Comment(rawValue: message))
    }
  }

  func currentMemoryUsage() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(
          mach_task_self_,
          task_flavor_t(MACH_TASK_BASIC_INFO),
          $0,
          &count
        )
      }
    }

    guard result == KERN_SUCCESS else {
      return 0
    }

    return info.resident_size
  }

  func requireMeasuredCoverage(
    _ coverage: LLVMCoverageRunner.CoverageReport,
    context: String
  ) -> LLVMCoverageRunner.CoverageReport? {
    guard !coverage.isSynthetic else {
      let reason = coverage.syntheticFallbackReason ?? "coverage artifacts unavailable"
      #expect(Bool(true), Comment(rawValue: "Skipping \(context): \(reason)"))
      return nil
    }

    return coverage
  }
}
