import Foundation

// MARK: - Subprocess IPC Protocol

/// Request sent from parent to child process for property evaluation
struct PropertyEvaluationRequest: Codable, Sendable {
  /// Unique identifier for this evaluation request
  let testId: UUID

  /// Seed for deterministic test generation
  let seed: UInt64

  /// Size parameter for generation
  let size: Int

  /// Serialized test input (JSON encoded)
  let testInput: Data

  /// Generator type name for reconstruction
  let generatorType: String
}

/// Response sent from child to parent after property evaluation
struct PropertyEvaluationResponse: Codable, Sendable {
  /// Unique identifier matching the request
  let testId: UUID

  /// Whether the property predicate passed
  let passed: Bool

  /// Optional failure reason if passed == false
  let failureReason: String?

  /// Execution time in seconds
  let duration: TimeInterval

  init(
    testId: UUID,
    passed: Bool,
    duration: TimeInterval,
    failureReason: String? = nil
  ) {
    self.testId = testId
    self.passed = passed
    self.failureReason = failureReason
    self.duration = duration
  }
}

// MARK: - Subprocess Execution

#if os(macOS)

/// Subprocess-based property executor for crash isolation (macOS only)
@available(macOS 14.0, *)
struct SubprocessPropertyExecutor {

  /// Result of executing a property test in a subprocess
  enum ExecutionResult {
    /// Property passed successfully
    case passed

    /// Property failed (predicate returned false)
    case failed(reason: String)

    /// Subprocess crashed (SIGABRT, SIGSEGV, etc.)
    case crashed(signal: Int32, reason: Process.TerminationReason)

    /// Subprocess timed out
    case timedOut

    /// Failed to spawn or communicate with subprocess
    case spawnError(String)
  }

  /// Path to the helper executable
  let helperExecutablePath: URL

  /// Timeout for subprocess execution
  let timeout: TimeInterval

  init(helperExecutablePath: URL, timeout: TimeInterval = 5.0) {
    self.helperExecutablePath = helperExecutablePath
    self.timeout = timeout
  }

  /// Execute a property evaluation in an isolated subprocess
  ///
  /// - Parameters:
  ///   - request: The evaluation request with test input
  ///
  /// - Returns: The execution result (passed, failed, crashed, or error)
  func execute(request: PropertyEvaluationRequest) async -> ExecutionResult {
    let process = makeProcess()
    let pipes = setupPipes(for: process)

    guard let requestData = encodeRequest(request) else {
      return .spawnError("Failed to encode request")
    }

    if let launchError = launch(process) { return launchError }

    if let writeError = writeRequest(
      requestData,
      to: pipes.input,
      process: process
    ) {
      return writeError
    }

    if let timeoutResult = await waitForCompletion(process: process) {
      return timeoutResult
    }

    return parseProcessResult(process: process, outputPipe: pipes.output)
  }
}

extension SubprocessPropertyExecutor {
  private func makeProcess() -> Process {
    let process = Process()
    process.executableURL = helperExecutablePath
    return process
  }

  private func launch(_ process: Process) -> ExecutionResult? {
    do {
      try process.run()
      return nil
    } catch {
      return .spawnError("Failed to spawn subprocess: \(error)")
    }
  }

  private struct ProcessPipes {
    let input: Pipe
    let output: Pipe
    let error: Pipe
  }

  private func setupPipes(for process: Process) -> ProcessPipes {
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    return ProcessPipes(input: inputPipe, output: outputPipe, error: errorPipe)
  }

  private func encodeRequest(_ request: PropertyEvaluationRequest) -> Data? {
    try? JSONEncoder().encode(request)
  }

  private func writeRequest(
    _ data: Data,
    to pipe: Pipe,
    process: Process
  ) -> ExecutionResult? {
    do {
      var length = UInt32(data.count).bigEndian
      let lengthData = Data(bytes: &length, count: 4)
      try pipe.fileHandleForWriting.write(contentsOf: lengthData)
      try pipe.fileHandleForWriting.write(contentsOf: data)
      try pipe.fileHandleForWriting.close()
      return nil
    } catch {
      process.terminate()
      return .spawnError("Failed to write request: \(error)")
    }
  }

  private func waitForCompletion(process: Process) async -> ExecutionResult? {
    let startTime = Date()
    while process.isRunning {
      if Date().timeIntervalSince(startTime) > timeout {
        process.terminate()
        try? await Task.sleep(nanoseconds: 100_000_000)
        if process.isRunning {
          process.interrupt()
        }
        return .timedOut
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }

    process.waitUntilExit()
    return nil
  }

  private func parseProcessResult(
    process: Process,
    outputPipe: Pipe
  ) -> ExecutionResult {
    switch process.terminationReason {
    case .exit:
      return parseExit(process: process, outputPipe: outputPipe)

    case .uncaughtSignal:
      return .crashed(
        signal: process.terminationStatus,
        reason: .uncaughtSignal
      )

    @unknown default:
      return .spawnError("Unknown termination reason")
    }
  }

  private func parseExit(
    process: Process,
    outputPipe: Pipe
  ) -> ExecutionResult {
    guard process.terminationStatus == 0 else {
      return .failed(reason: "Exit code \(process.terminationStatus)")
    }
    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    guard
      let response = try? JSONDecoder().decode(
        PropertyEvaluationResponse.self,
        from: data
      )
    else {
      return .spawnError("Failed to decode response")
    }
    guard response.passed else {
      return .failed(reason: response.failureReason ?? "Unknown")
    }
    return .passed
  }
}

extension IsolatedPropertyRunner {
  func findHelperExecutable() -> URL? {
    let candidates = [
      Bundle.main.bundleURL
        .appendingPathComponent("Contents/MacOS/PropertyTestHelper"),
      Bundle.main.bundleURL.appendingPathComponent("PropertyTestHelper"),
      URL(fileURLWithPath: ".build/debug/PropertyTestHelper"),
      URL(fileURLWithPath: ".build/release/PropertyTestHelper"),
    ]
    return candidates.first {
      FileManager.default.isExecutableFile(atPath: $0.path)
    }
  }

  func executeInSubprocess<Value: Sendable>(
    property: Property<Value>,
    value: Value,
    helperPath: URL
  ) async -> IsolationTestOutcome {
    do {
      let request = try makeEvaluationRequest(value)
      let executor = SubprocessPropertyExecutor(
        helperExecutablePath: helperPath,
        timeout: 5.0
      )
      return mapSubprocessResult(await executor.execute(request: request))
    } catch {
      return .failure(reason: "Serialization error: \(error)")
    }
  }

  private func makeEvaluationRequest<Value>(
    _ value: Value
  ) throws -> PropertyEvaluationRequest {
    let data = try JSONEncoder().encode(AnyCodable(value))
    return PropertyEvaluationRequest(
      testId: UUID(),
      seed: 0,
      size: 0,
      testInput: data,
      generatorType: String(describing: Value.self)
    )
  }

  private func mapSubprocessResult(
    _ result: SubprocessPropertyExecutor.ExecutionResult
  ) -> IsolationTestOutcome {
    switch result {
    case .passed:
      return .success

    case .failed(let reason):
      return .failure(reason: reason)

    case .crashed(let signal, _):
      return .crashed(signal: signal)

    case .timedOut:
      return .failure(reason: "Timed out")

    case .spawnError(let error):
      return .failure(reason: "Spawn error: \(error)")
    }
  }
}
#endif  // os(macOS)
