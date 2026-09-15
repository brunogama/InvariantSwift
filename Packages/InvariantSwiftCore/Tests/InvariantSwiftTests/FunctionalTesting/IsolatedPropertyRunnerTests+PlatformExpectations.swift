import Testing

@testable import InvariantSwiftCore

extension IsolatedPropertyRunnerTests {
  func expectPlatformResult<Value: Sendable>(
    _ result: IsolatedPropertyResult<Value>,
    macOSIterations: Int
  ) {
    #if os(macOS)
    guard case .success(let iterations) = result else {
      Issue.record("Expected success on macOS")
      return
    }
    #expect(iterations == macOSIterations)
    #else
    guard case .failure(let failure) = result else {
      Issue.record("Expected unsupported-platform failure")
      return
    }
    let expectedReason = SubprocessRunner.unsupportedPlatformReason
    #expect(failure.context.iterations == 1)
    #expect(failure.context.reason == expectedReason)
    #endif
  }
}
