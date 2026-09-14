import Foundation

struct ProcessRequest: Equatable, Sendable {
  let executable: String
  let arguments: [String]
  let currentDirectory: String
  let environment: [String: String]
}

protocol ProcessRunning: Sendable {
  func run(_ request: ProcessRequest) async throws -> Int32
}

struct LiveProcessRunner: ProcessRunning {

  func run(_ request: ProcessRequest) async throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: request.executable)
    process.arguments = request.arguments
    process.currentDirectoryURL = URL(fileURLWithPath: request.currentDirectory)
    process.environment = request.environment
    // The child writes directly to the terminal so its output streams live.
    // stdin is detached: no child of this CLI reads input, and sharing the
    // parent's descriptor lets a child block on a terminal read forever.
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    return try await withCheckedThrowingContinuation { continuation in
      let resumed = ResumeGuard()
      process.terminationHandler = { finished in
        guard resumed.claim() else { return }
        continuation.resume(returning: finished.terminationStatus)
      }
      do {
        try process.run()
      } catch {
        process.terminationHandler = nil
        guard resumed.claim() else { return }
        continuation.resume(throwing: error)
      }
    }
  }
}

/// Guarantees a continuation is resumed exactly once when both the failure path
/// and the termination handler can race.
private final class ResumeGuard: @unchecked Sendable {
  private let lock = NSLock()
  private var claimed = false

  func claim() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard !claimed else { return false }
    claimed = true
    return true
  }
}
