// MARK: - CLI Output Protocol
// Abstraction for CLI output to avoid direct standard output calls in production code.

import Foundation

/// Protocol for CLI output handling.
/// CLI tools use this protocol instead of direct stdout calls.
public protocol CLIOutput: Sendable {
  func write(_ message: String)
  func write(_ message: String, terminator: String)
}

/// Standard output implementation using FileHandle.
public struct StandardOutput: CLIOutput {
  public init() {}

  public func write(_ message: String) {
    write(message, terminator: "\n")
  }

  public func write(_ message: String, terminator: String) {
    let output = message + terminator
    FileHandle.standardOutput.write(Data(output.utf8))
  }
}

/// In-memory output for testing.
public final class MemoryOutput: CLIOutput, @unchecked Sendable {
  private var buffer: [String] = []
  private let lock = NSLock()

  public init() {}

  public var lines: [String] {
    lock.lock()
    defer { lock.unlock() }
    return buffer
  }

  public var output: String {
    lines.joined(separator: "\n")
  }

  public func write(_ message: String) {
    lock.lock()
    defer { lock.unlock() }
    buffer.append(message)
  }

  public func write(_ message: String, terminator: String) {
    lock.lock()
    defer { lock.unlock() }
    if terminator.isEmpty {
      if buffer.isEmpty {
        buffer.append(message)
      } else {
        buffer[buffer.count - 1] += message
      }
    } else {
      buffer.append(message)
    }
  }
}
