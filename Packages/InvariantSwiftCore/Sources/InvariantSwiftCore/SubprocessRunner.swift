import Foundation

enum SubprocessRunner {
  static let unsupportedPlatformReason =
    "Subprocess isolation is unavailable on this platform"

  enum SubprocessResult {
    case success
    case failure(reason: String)
    case crashed(signal: Int32)
    case timeout
  }

  static func execute(
    timeout: TimeInterval = 5.0,
    body: @escaping () throws -> Bool
  ) -> SubprocessResult {
    _ = timeout
    do {
      return try body() ? .success : .failure(reason: "Property returned false")
    } catch {
      return .failure(reason: error.localizedDescription)
    }
  }

  static func executeIsolated(
    executablePath: String,
    arguments: [String],
    timeout: TimeInterval = 5.0
  ) async -> SubprocessResult {
    #if os(macOS)
    let process = configuredProcess(path: executablePath, arguments: arguments)
    do {
      try process.run()
    } catch {
      return .failure(reason: "Failed to spawn subprocess: \(error)")
    }
    guard await waitForExit(process, timeout: timeout) else { return .timeout }
    return result(for: process)
    #else
    return .failure(reason: unsupportedPlatformReason)
    #endif
  }

  #if os(macOS)
  private static func configuredProcess(
    path: String,
    arguments: [String]
  ) -> Process {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    return process
  }

  private static func waitForExit(
    _ process: Process,
    timeout: TimeInterval
  ) async -> Bool {
    let startTime = Date()
    while process.isRunning {
      if Date().timeIntervalSince(startTime) > timeout {
        process.terminate()
        return false
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    process.waitUntilExit()
    return true
  }

  private static func result(for process: Process) -> SubprocessResult {
    switch process.terminationReason {
    case .exit:
      let status = process.terminationStatus
      return status == 0 ? .success : .failure(reason: "Exit code \(status)")

    case .uncaughtSignal:
      return .crashed(signal: process.terminationStatus)

    @unknown default:
      return .failure(reason: "Unknown termination reason")
    }
  }
  #endif
}
