import Foundation

// MARK: - Subprocess Runner

/// Low-level subprocess execution with crash detection
enum SubprocessRunner {

  /// Result of subprocess execution
  enum SubprocessResult {
    case success
    case failure(reason: String)
    case crashed(signal: Int32)
    case timeout
  }

  /// Execute a closure in current process with signal handling
  /// For true crash isolation, we'd need posix_spawn, but this provides
  /// a foundation that can be extended.
  static func execute(
    timeout: TimeInterval = 5.0,
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

    // Capture output for debugging
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
    } catch {
      return .failure(reason: "Failed to spawn subprocess: \(error)")
    }

    if let timedOut = await waitForExit(of: process, timeout: timeout) {
      return timedOut
    }

    return terminationResult(of: process)
  }

  private static func waitForExit(
    of process: Process,
    timeout: TimeInterval
  ) async -> SubprocessResult? {
    let startTime = Date()
    while process.isRunning {
      if Date().timeIntervalSince(startTime) > timeout {
        process.terminate()
        return .timeout
      }
      try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    process.waitUntilExit()
    return nil
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
