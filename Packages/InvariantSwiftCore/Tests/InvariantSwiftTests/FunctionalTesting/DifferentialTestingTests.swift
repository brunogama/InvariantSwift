import Testing

@testable import InvariantSwift

@Suite("ISP-0005: Differential Testing")
struct DifferentialTestingTests {
  @Test("ErrorBehavior enum values exist")
  func errorBehaviorValues() {
    let behaviors: [ErrorBehavior] = [
      .mustMatch,
      .bothThrowOrBothSucceed,
      .candidateMaySucceedMore,
      .ignoreErrors,
    ]
    #expect(behaviors.count == 4)
  }

  @Test("DifferentialResult detects divergence on different outputs")
  func resultDetectsDivergence() {
    let result = DifferentialResult<Int, Int>(
      input: 42,
      referenceOutput: .success(100),
      candidateOutput: .success(200)
    )
    #expect(result.diverges == true)
  }

  @Test("DifferentialResult detects no divergence on same outputs")
  func resultDetectsNoDivergence() {
    let result = DifferentialResult<Int, Int>(
      input: 42,
      referenceOutput: .success(100),
      candidateOutput: .success(100)
    )
    #expect(result.diverges == false)
  }

  @Test("DifferentialResult handles both throwing")
  func resultHandlesBothThrowing() {
    struct TestError: Error {}
    let result = DifferentialResult<Int, Int>(
      input: 42,
      referenceOutput: .failure(TestError()),
      candidateOutput: .failure(TestError())
    )
    let behavior = ErrorBehavior.bothThrowOrBothSucceed
    #expect(result.diverges(errorBehavior: behavior) == false)
  }

  @Test("DifferentialResult with custom comparer")
  func resultWithCustomComparer() {
    let result = DifferentialResult<Int, Double>(
      input: 42,
      referenceOutput: .success(3.14159),
      candidateOutput: .success(3.14160),
      comparer: { abs($0 - $1) < 0.001 }
    )
    #expect(result.diverges == false)
  }

  @Test("DifferentialTester runs both implementations")
  func testerRunsBoth() throws {
    let tester = DifferentialTester<Int, Int>(
      reference: { $0 * 2 },
      candidate: { $0 + $0 }
    )
    #expect(tester.test(21).diverges == false)
  }

  @Test("DifferentialTester detects differences")
  func testerDetectsDifferences() throws {
    let tester = DifferentialTester<Int, Int>(
      reference: { $0 * 2 },
      candidate: { $0 * 3 }
    )
    #expect(tester.test(10).diverges == true)
  }

  @Test("DifferentialTestError provides detailed description")
  func testErrorDescription() {
    let result = DifferentialResult<Int, Int>(
      input: 42,
      referenceOutput: .success(84),
      candidateOutput: .success(126)
    )
    let error = DifferentialTestError(
      result: result,
      referenceName: "double",
      candidateName: "triple"
    )
    #expect(error.description.contains("Differential test failed"))
    #expect(error.description.contains("Input: 42"))
    #expect(error.description.contains("double: 84"))
    #expect(error.description.contains("triple: 126"))
  }
}
