import Foundation

protocol CLIOutput: Sendable {
  func writeStandardOutput(_ value: String)
  func writeStandardError(_ value: String)
}

struct StandardCLIOutput: CLIOutput {

  func writeStandardOutput(_ value: String) {
    FileHandle.standardOutput.write(Data(value.utf8))
  }

  func writeStandardError(_ value: String) {
    FileHandle.standardError.write(Data(value.utf8))
  }
}

final class MemoryCLIOutput: CLIOutput, @unchecked Sendable {
  private let lock = NSLock()
  private var standardOutput = ""
  private var standardError = ""

  init() {}

  var stdout: String {
    lock.withLock { standardOutput }
  }

  var stderr: String {
    lock.withLock { standardError }
  }

  func writeStandardOutput(_ value: String) {
    lock.withLock { standardOutput += value }
  }

  func writeStandardError(_ value: String) {
    lock.withLock { standardError += value }
  }
}
