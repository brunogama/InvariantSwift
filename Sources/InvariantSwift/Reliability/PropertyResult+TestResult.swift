import InvariantSwiftCore

// MARK: - PropertyResult to TestResult Conversion

extension PropertyResult {
  /// Convert PropertyResult to TestResult for reliability testing integration.
  ///
  /// This mapping enables PropertyResult to be used with FlakeHunter and other
  /// reliability testing infrastructure that expects TestResult enum.
  ///
  /// - Returns: TestResult representing the property test outcome
  ///   - `.passed` for `.success`
  ///   - `.failed` for `.failure`
  ///   - `.skipped` for `.gaveUp`
  ///
  /// - Example:
  ///   ```swift
  ///   let result = await runner.runProperty(property)
  ///   let testResult = result.toTestResult()  // .passed, .failed, or .skipped
  ///   await flakeHunter.recordExecution(
  ///     TestExecution(testId: "myTest", result: testResult, ...)
  ///   )
  ///   ```
  ///
  /// - Note: This method was moved from `fileprivate` in FlakeHunter.swift to `public`
  ///   in Plan 11-01, Task 2 for broader API access.
  public func toTestResult() -> TestResult {
    switch self {
    case .success:
      return .passed

    case .failure:
      return .failed

    case .gaveUp:
      return .skipped
    }
  }
}
