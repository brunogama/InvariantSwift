// MARK: - Compile Verification Infrastructure
// Verifies generated Swift code compiles using swiftc -typecheck before writing to disk.

import Foundation

/// Result of compile verification
public struct CompileVerificationResult: Sendable {
  public let success: Bool
  public let errors: [CompileError]
  public let output: String

  public struct CompileError: Sendable {
    public let line: Int?
    public let column: Int?
    public let message: String
    public let file: String
  }
}

/// Verifies generated Swift code compiles using swiftc -typecheck
public struct CompileVerifier: Sendable {
  private let verbose: Bool
  private let output: CLIOutput

  public init(verbose: Bool = false, output: CLIOutput = StandardOutput()) {
    self.verbose = verbose
    self.output = output
  }

  /// Verify that generated code compiles
  public func verify(
    code: String,
    fileName: String,
    imports: [String] = ["InvariantSwift", "Testing"]
  ) -> CompileVerificationResult {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ghostwriter-verify-\(UUID().uuidString)")

    do {
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      defer {
        try? FileManager.default.removeItem(at: tempDir)
      }

      let tempFile = tempDir.appendingPathComponent(fileName)
      try code.write(to: tempFile, atomically: true, encoding: .utf8)

      if verbose {
        output.write("  Verifying \(fileName) with swiftc...")
      }

      let result = runSwiftc(tempFile: tempFile)

      if result.terminationStatus == 0 {
        if verbose {
          output.write("  Compilation successful")
        }
        return CompileVerificationResult(success: true, errors: [], output: result.output)
      } else {
        let errors = parseSwiftcErrors(result.output, fileName: fileName)
        return CompileVerificationResult(success: false, errors: errors, output: result.output)
      }

    } catch {
      return CompileVerificationResult(
        success: false,
        errors: [
          CompileVerificationResult.CompileError(
            line: nil,
            column: nil,
            message: "Failed to verify: \(error.localizedDescription)",
            file: fileName
          )
        ],
        output: ""
      )
    }
  }

  private struct ProcessResult {
    let terminationStatus: Int32
    let output: String
  }

  private func runSwiftc(tempFile: URL) -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "swiftc",
      "-typecheck",
      tempFile.path,
      "-I", ".build/debug",
      "-sdk", sdkPath(),
    ]

    let pipe = Pipe()
    process.standardError = pipe
    process.standardOutput = pipe

    do {
      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""
      return ProcessResult(terminationStatus: process.terminationStatus, output: output)
    } catch {
      return ProcessResult(terminationStatus: 1, output: error.localizedDescription)
    }
  }

  private func parseSwiftcErrors(
    _ outputText: String,
    fileName: String
  ) -> [CompileVerificationResult.CompileError] {
    var errors: [CompileVerificationResult.CompileError] = []
    let lines = outputText.components(separatedBy: .newlines)

    for line in lines where line.contains(": error:") {
      let parts = line.components(separatedBy: ":")
      guard parts.count >= 4 else { continue }

      let lineNum = Int(parts[1].trimmingCharacters(in: .whitespaces))
      let colNum = Int(parts[2].trimmingCharacters(in: .whitespaces))
      let message = parts.dropFirst(3).joined(separator: ":").trimmingCharacters(in: .whitespaces)

      errors.append(
        CompileVerificationResult.CompileError(
          line: lineNum,
          column: colNum,
          message: message,
          file: fileName
        )
      )
    }

    return errors
  }

  private func sdkPath() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["--show-sdk-path"]

    let pipe = Pipe()
    process.standardOutput = pipe

    try? process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}
