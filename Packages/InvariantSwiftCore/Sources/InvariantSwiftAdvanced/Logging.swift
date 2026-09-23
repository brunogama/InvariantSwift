import Foundation

#if !canImport(os)

// MARK: - Logger (non-Apple platforms)

/// Stand-in for `os.Logger` where the `os` module does not exist.
///
/// This module logs through `os.Logger` on Apple platforms. Linux has no `os`
/// module, so this type provides the same call shape the module uses
/// (`debug`, `info`, `warning`, `error` with an interpolated message) and
/// writes each line to standard error. It is compiled only where `os` is
/// unavailable, so it never competes with the real type.
struct Logger: Sendable {
  private let subsystem: String
  private let category: String

  init(subsystem: String, category: String) {
    self.subsystem = subsystem
    self.category = category
  }

  func debug(_ message: @autoclosure () -> String) {
    write(level: "debug", message())
  }

  func info(_ message: @autoclosure () -> String) {
    write(level: "info", message())
  }

  func warning(_ message: @autoclosure () -> String) {
    write(level: "warning", message())
  }

  func error(_ message: @autoclosure () -> String) {
    write(level: "error", message())
  }

  private func write(level: String, _ message: String) {
    let line = "[\(subsystem):\(category)] \(level): \(message)\n"
    FileHandle.standardError.write(Data(line.utf8))
  }
}

#endif  // !canImport(os)
