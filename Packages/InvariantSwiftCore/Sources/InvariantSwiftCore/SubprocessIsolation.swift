import Foundation

// MARK: - Subprocess IPC Protocol

/// Current IPC protocol version.
///
/// Must stay in step with `currentProtocolVersion` in the `PropertyTestHelper`
/// executable: the helper rejects any request whose version does not match.
let currentProtocolVersion = 1

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

  /// IPC protocol version — the helper rejects requests that omit or mismatch it.
  let protocolVersion: Int

  init(
    testId: UUID,
    seed: UInt64,
    size: Int,
    testInput: Data,
    generatorType: String,
    protocolVersion: Int = currentProtocolVersion
  ) {
    self.testId = testId
    self.seed = seed
    self.size = size
    self.testInput = testInput
    self.generatorType = generatorType
    self.protocolVersion = protocolVersion
  }
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

  /// IPC protocol version echoed back by the helper.
  let protocolVersion: Int

  init(
    testId: UUID,
    passed: Bool,
    failureReason: String? = nil,
    duration: TimeInterval,
    protocolVersion: Int = currentProtocolVersion
  ) {
    self.testId = testId
    self.passed = passed
    self.failureReason = failureReason
    self.duration = duration
    self.protocolVersion = protocolVersion
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
    guard let requestData = encodeRequest(request) else {
      return .spawnError("Failed to encode request")
    }

    let process = Process()
    process.executableURL = helperExecutablePath

    let pipes = setupPipes(for: process)

    do {
      try process.run()
    } catch {
      return .spawnError("Failed to spawn subprocess: \(error)")
    }

    // Drain both output pipes concurrently with the wait below. A pipe holds
    // only one buffer (64 KiB): a helper that writes more than that blocks in
    // write(2) while the parent blocks waiting for it to exit. Draining also
    // reaches EOF on child exit, which closes these descriptors deterministically
    // rather than leaving them to FileHandle deinit on an arbitrary thread.
    let stdoutTask = Task.detached { pipes.output.fileHandleForReading.readDataToEndOfFile() }
    let stderrTask = Task.detached { pipes.error.fileHandleForReading.readDataToEndOfFile() }

    func drain() async {
      _ = await stdoutTask.value
      _ = await stderrTask.value
    }

    if let writeError = writeRequest(requestData, to: pipes.input, process: process) {
      await drain()
      return writeError
    }

    if let timeoutResult = await waitForCompletion(process: process) {
      await drain()
      return timeoutResult
    }

    let output = await stdoutTask.value
    _ = await stderrTask.value

    return parseProcessResult(process: process, output: output)
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

  private func writeRequest(_ data: Data, to pipe: Pipe, process: Process) -> ExecutionResult? {
    do {
      var length = UInt32(data.count).bigEndian
      try pipe.fileHandleForWriting.write(contentsOf: Data(bytes: &length, count: 4))
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

    // No waitUntilExit() here. Foundation delivers a process's termination
    // once; `isRunning` going false means that delivery already happened and
    // terminationStatus/terminationReason are populated. Calling
    // waitUntilExit() afterwards waits on a signal that will never come again
    // and deadlocks the test process, which in turn hangs the SwiftPM parent
    // still reading its stdout and stderr.
    return nil
  }

  private func parseProcessResult(process: Process, output: Data) -> ExecutionResult {
    switch process.terminationReason {
    case .exit:
      if process.terminationStatus != 0 {
        return .failed(reason: "Exit code \(process.terminationStatus)")
      }

      guard
        let response = try? JSONDecoder().decode(
          PropertyEvaluationResponse.self,
          from: output
        )
      else {
        return .spawnError("Failed to decode response")
      }

      guard response.protocolVersion == currentProtocolVersion else {
        return .spawnError(
          "Helper replied with protocol version \(response.protocolVersion), "
            + "expected \(currentProtocolVersion)"
        )
      }

      return response.passed ? .passed : .failed(reason: response.failureReason ?? "Unknown")

    case .uncaughtSignal:
      return .crashed(signal: process.terminationStatus, reason: .uncaughtSignal)

    @unknown default:
      return .spawnError("Unknown termination reason")
    }
  }
}

#endif  // os(macOS)
