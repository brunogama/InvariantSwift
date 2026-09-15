import Foundation

/// Reports failures in the failing-example persistence path.
///
/// Persistence is best effort: a failure here must not fail the property test
/// that triggered it. Discarding the error silently, though, makes a write or
/// encode failure indistinguishable from having nothing to save, so the reason
/// is emitted on standard error when `INVARIANT_DEBUG` is set.
enum FailingExampleDiagnostics {
  static func report(_ message: @autoclosure () -> String) {
    guard FailingExampleConfig.isDebugMode else { return }
    let line = "[InvariantSwift] \(message())\n"
    guard let data = line.data(using: .utf8) else { return }
    try? FileHandle.standardError.write(contentsOf: data)
  }
}
