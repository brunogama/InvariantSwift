import Foundation

/// Runs an SMT solver as a child process and returns its standard output.
///
/// Both solver pipes are drained concurrently with the run. Draining only
/// after the process exits deadlocks as soon as a model exceeds the operating
/// system pipe buffer, which `(get-model)` reaches for constraints with many
/// variables.
func executeSolver(
  input: String,
  config: SMTSolverConfig
) async throws -> String {
  #if os(macOS)
  try await runSolver(input: input, config: config)
  #else
  throw SMTSolverError.unsupportedOperation(
    "SMT solver execution is unavailable on this platform"
  )
  #endif
}

#if os(macOS)
private func runSolver(input: String, config: SMTSolverConfig) async throws -> String {
  let execution = makeExecution(config: config)
  let termination = TerminationSignal()
  execution.process.terminationHandler = { _ in termination.signal() }

  let output = DataBuffer()
  let errorOutput = DataBuffer()
  let drained = DispatchGroup()
  drain(execution.output.fileHandleForReading, into: output, group: drained)
  drain(execution.error.fileHandleForReading, into: errorOutput, group: drained)

  do {
    try execution.process.run()
  } catch {
    execution.process.terminationHandler = nil
    throw SMTSolverError.solverError("Failed to launch \(config.solverPath): \(error)")
  }

  let timedOut = AtomicFlag()
  let deadline = makeTimeout(execution.process, after: config.timeout, flag: timedOut)
  defer { deadline.cancel() }

  try write(input, to: execution.input)
  await termination.wait()
  await drained.wait()

  return try result(
    execution,
    output: output.value,
    errorOutput: errorOutput.value,
    timedOut: timedOut.value
  )
}

private func result(
  _ execution: SMTExecution,
  output: Data,
  errorOutput: Data,
  timedOut: Bool
) throws -> String {
  if timedOut || execution.process.terminationReason == .uncaughtSignal {
    throw SMTSolverError.timeout
  }
  guard execution.process.terminationStatus == 0 else {
    let message = String(data: errorOutput, encoding: .utf8) ?? "Unknown error"
    throw SMTSolverError.solverError(message)
  }
  return String(data: output, encoding: .utf8) ?? ""
}

private struct SMTExecution {
  let process: Process
  let input: Pipe
  let output: Pipe
  let error: Pipe
}

private func makeExecution(config: SMTSolverConfig) -> SMTExecution {
  let execution = SMTExecution(
    process: Process(),
    input: Pipe(),
    output: Pipe(),
    error: Pipe()
  )
  execution.process.executableURL = URL(fileURLWithPath: config.solverPath)
  execution.process.arguments = SMTSolverArguments.arguments(for: config)
  execution.process.standardInput = execution.input
  execution.process.standardOutput = execution.output
  execution.process.standardError = execution.error
  // A solver that exits before reading the whole constraint would otherwise
  // raise SIGPIPE and kill the host process. Report EPIPE to the writer.
  _ = fcntl(execution.input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
  return execution
}

private func write(_ input: String, to pipe: Pipe) throws {
  guard let data = input.data(using: .utf8) else {
    throw SMTSolverError.invalidInput("Input is not valid UTF-8")
  }
  let handle = pipe.fileHandleForWriting
  do {
    try handle.write(contentsOf: data)
    try handle.close()
  } catch {
    try? handle.close()
    throw SMTSolverError.solverError("Failed to send constraint to solver: \(error)")
  }
}

private func makeTimeout(
  _ process: Process,
  after duration: Duration,
  flag: AtomicFlag
) -> Task<Void, Never> {
  Task {
    guard (try? await Task.sleep(for: duration)) != nil else { return }
    guard process.isRunning else { return }
    flag.set()
    process.terminate()
  }
}

private func drain(_ handle: FileHandle, into buffer: DataBuffer, group: DispatchGroup) {
  group.enter()
  DispatchQueue.global(qos: .userInitiated).async {
    buffer.set(handle.readDataToEndOfFile())
    group.leave()
  }
}

private extension DispatchGroup {
  /// Suspends until every drain finishes, without blocking a cooperative thread.
  func wait() async {
    await withCheckedContinuation { continuation in
      notify(queue: .global(qos: .userInitiated)) { continuation.resume() }
    }
  }
}

/// Bridges `Process.terminationHandler` to a suspension point.
///
/// `waitUntilExit()` blocks the calling thread. Called from an `async`
/// function it holds a cooperative thread-pool thread for the whole solve,
/// and inside an actor it blocks that actor's executor.
private final class TerminationSignal: @unchecked Sendable {
  private let lock = NSLock()
  private var terminated = false
  private var continuation: CheckedContinuation<Void, Never>?

  func signal() {
    lock.lock()
    terminated = true
    let pending = continuation
    continuation = nil
    lock.unlock()
    pending?.resume()
  }

  func wait() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      guard !terminated else {
        lock.unlock()
        continuation.resume()
        return
      }
      self.continuation = continuation
      lock.unlock()
    }
  }
}

private final class DataBuffer: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = Data()

  func set(_ data: Data) {
    lock.lock()
    storage = data
    lock.unlock()
  }

  var value: Data {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }
}

private final class AtomicFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var flag = false

  func set() {
    lock.lock()
    flag = true
    lock.unlock()
  }

  var value: Bool {
    lock.lock()
    defer { lock.unlock() }
    return flag
  }
}
#endif
