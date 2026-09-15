import Foundation

// MARK: - Subprocess Runner

/// Low-level subprocess execution with crash detection
enum SubprocessRunner {

  static let unsupportedPlatformReason =
    "Subprocess isolation is unavailable on this platform"

  /// Result of subprocess execution
  enum SubprocessResult {
    case success
    case failure(reason: String)
    case crashed(signal: Int32)
    case timeout
  }

  /// Evaluates `body` in the current process.
  ///
  /// Despite the enclosing type's name this runs in-process and so cannot
  /// enforce a time limit. Use ``executeIsolated(executablePath:arguments:timeout:)``
  /// when a timeout is required.
  static func execute(
    body: @escaping () throws -> Bool
  ) -> SubprocessResult {
    do {
      let result = try body()
      return result ? .success : .failure(reason: "Property returned false")
    } catch {
      return .failure(reason: error.localizedDescription)
    }
  }

  /// Execute property test in isolated subprocess
  /// Uses Process to spawn a child that runs the test
  static func executeIsolated(
    executablePath: String,
    arguments: [String],
    timeout: TimeInterval = 5.0
  ) async -> SubprocessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments

    // The merged pipe is drained continuously. Leaving it unread lets a
    // chatty child fill the OS buffer and block in write until the timeout
    // fires, turning an ordinary pass or failure into a reported timeout.
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    pipe.fileHandleForReading.readabilityHandler = { handle in
      _ = handle.availableData
    }

    let signal = ProcessTerminationSignal()
    process.terminationHandler = { _ in signal.resume() }

    do {
      try process.run()
    } catch {
      process.terminationHandler = nil
      pipe.fileHandleForReading.readabilityHandler = nil
      return .failure(reason: "Failed to spawn subprocess: \(error)")
    }

    let timedOut = await waitForExit(of: process, signal: signal, timeout: timeout)
    pipe.fileHandleForReading.readabilityHandler = nil
    guard !timedOut else { return .timeout }

    return terminationResult(of: process)
  }

  /// Suspends until the process exits, or terminates it once `timeout` elapses.
  ///
  /// Returns `true` when the timeout fired. The process reports its exit
  /// through its termination handler rather than being polled, so no thread is
  /// held and no wake-up happens between spawn and exit.
  private static func waitForExit(
    of process: Process,
    signal: ProcessTerminationSignal,
    timeout: TimeInterval
  ) async -> Bool {
    let deadline = Task {
      guard (try? await Task.sleep(for: .seconds(timeout))) != nil else { return }
      guard process.isRunning else { return }
      signal.markExpired()
      process.terminate()
    }
    defer { deadline.cancel() }
    await signal.wait()
    return signal.expired
  }

  private static func terminationResult(
    of process: Process
  ) -> SubprocessResult {
    let status = process.terminationStatus
    switch process.terminationReason {
    case .exit:
      return status == 0 ? .success : .failure(reason: "Exit code \(status)")

    case .uncaughtSignal:
      return .crashed(signal: status)

    @unknown default:
      return .failure(reason: "Unknown termination reason")
    }
  }
}

/// Bridges `Process.terminationHandler` to a suspension point.
///
/// Polling `isRunning` wakes the executor every 10ms for the whole run;
/// `waitUntilExit()` blocks a cooperative thread instead. Neither is needed
/// when the process reports its own exit.
private final class ProcessTerminationSignal: @unchecked Sendable {
  private let lock = NSLock()
  private var terminated = false
  private var timedOut = false
  private var continuation: CheckedContinuation<Void, Never>?

  var expired: Bool {
    lock.lock()
    defer { lock.unlock() }
    return timedOut
  }

  func markExpired() {
    lock.lock()
    timedOut = true
    lock.unlock()
  }

  func resume() {
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
