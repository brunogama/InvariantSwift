import Foundation

// MARK: - Subprocess IPC Protocol

/// The schema version shared by the parent and `PropertyTestHelper` subprocess.
package enum PropertyEvaluationWireProtocol {
  package static let version = 1
}

/// Request sent from the parent to the child process for property evaluation.
package struct PropertyEvaluationRequest: Codable, Sendable, Equatable {
  /// Unique identifier for this evaluation request.
  package let testId: UUID

  /// Seed for deterministic test generation.
  package let seed: UInt64

  /// Size parameter for generation.
  package let size: Int

  /// Serialized test input (JSON encoded).
  package let testInput: Data

  /// Generator type name for reconstruction.
  package let generatorType: String

  /// Schema version used to reject incompatible helper requests.
  package var protocolVersion = PropertyEvaluationWireProtocol.version
}

/// Response sent from the child to the parent after property evaluation.
package struct PropertyEvaluationResponse: Codable, Sendable, Equatable {
  /// Unique identifier matching the request.
  package let testId: UUID

  /// Whether the property predicate passed.
  package let passed: Bool

  /// Optional failure reason if passed == false.
  package let failureReason: String?

  /// Execution time in seconds.
  package let duration: TimeInterval

  /// Schema version echoed by the helper response.
  package var protocolVersion = PropertyEvaluationWireProtocol.version

  package init(
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
    let process = Process()
    process.executableURL = helperExecutablePath

    let pipes = setupPipes(for: process)

    guard let requestData = encodeRequest(request) else {
      return .spawnError("Failed to encode request")
    }

    if let launchError = launch(process, writing: requestData, to: pipes) {
      return launchError
    }

    if let timeoutResult = await waitForCompletion(process: process) {
      return timeoutResult
    }

    return parseProcessResult(process: process, outputPipe: pipes.output)
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

  private func launch(
    _ process: Process,
    writing requestData: Data,
    to pipes: ProcessPipes
  ) -> ExecutionResult? {
    do {
      try process.run()
    } catch {
      return .spawnError("Failed to spawn subprocess: \(error)")
    }

    return writeRequest(requestData, to: pipes.input, process: process)
  }

  private func writeRequest(
    _ data: Data,
    to pipe: Pipe,
    process: Process
  ) -> ExecutionResult? {
    do {
      let writer = pipe.fileHandleForWriting
      var length = UInt32(data.count).bigEndian
      try writer.write(contentsOf: Data(bytes: &length, count: 4))
      try writer.write(contentsOf: data)
      try writer.close()
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
}

// MARK: - Result Parsing

@available(macOS 14.0, *)
extension SubprocessPropertyExecutor {
  private func parseProcessResult(
    process: Process,
    outputPipe: Pipe
  ) -> ExecutionResult {
    switch process.terminationReason {
    case .exit:
      parseExit(status: process.terminationStatus, outputPipe: outputPipe)

    case .uncaughtSignal:
      .crashed(signal: process.terminationStatus, reason: .uncaughtSignal)

    @unknown default:
      .spawnError("Unknown termination reason")
    }
  }

  private func parseExit(status: Int32, outputPipe: Pipe) -> ExecutionResult {
    if status != 0 {
      return .spawnError("Helper exited with code \(status)")
    }

    let responseData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    guard
      let response = try? JSONDecoder().decode(
        PropertyEvaluationResponse.self,
        from: responseData
      )
    else {
      return .spawnError("Failed to decode response")
    }

    return validate(response)
  }

  private func validate(
    _ response: PropertyEvaluationResponse
  ) -> ExecutionResult {
    guard response.protocolVersion == PropertyEvaluationWireProtocol.version
    else {
      return .spawnError("Incompatible helper response protocol version")
    }

    return response.passed
      ? .passed
      : .failed(reason: response.failureReason ?? "Unknown")
  }
}

#endif  // os(macOS)
