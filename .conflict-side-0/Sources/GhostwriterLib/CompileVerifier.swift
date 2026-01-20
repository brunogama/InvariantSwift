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

  public init(verbose: Bool = false) {
    self.verbose = verbose
  }

  /// Verify that generated code compiles
  /// - Parameters:
  ///   - code: Swift source code to verify
  ///   - fileName: Name for temp file (for error messages)
  ///   - imports: Additional imports needed (e.g., ["InvariantSwift"])
  /// - Returns: Verification result with any errors found
  public func verify(
    code: String,
    fileName: String,
    imports: [String] = ["InvariantSwift", "Testing"]
  ) -> CompileVerificationResult {
    // Create temporary directory
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ghostwriter-verify-\(UUID().uuidString)")

    do {
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      defer {
        try? FileManager.default.removeItem(at: tempDir)
      }

      // Write code to temp file
      let tempFile = tempDir.appendingPathComponent(fileName)
      try code.write(to: tempFile, atomically: true, encoding: .utf8)

      if verbose {
        // swiftlint:disable:next no_print
        print("  Verifying \(fileName) with swiftc...")
      }

      // Run swiftc -typecheck
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = [
        "swiftc",
        "-typecheck",
        tempFile.path,
        "-I", ".build/debug",  // For module imports
        "-sdk", sdkPath(),
      ]

      let pipe = Pipe()
      process.standardError = pipe
      process.standardOutput = pipe

      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""

      if process.terminationStatus == 0 {
        if verbose {
          // swiftlint:disable:next no_print
          print("  ✓ Compilation successful")
        }
        return CompileVerificationResult(success: true, errors: [], output: output)
      } else {
        let errors = parseSwiftcErrors(output, fileName: fileName)
        return CompileVerificationResult(success: false, errors: errors, output: output)
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

  /// Parse swiftc error output into structured errors
  private func parseSwiftcErrors(
    _ output: String,
    fileName: String
  )
    -> [CompileVerificationResult.CompileError]
  {
    var errors: [CompileVerificationResult.CompileError] = []

    // swiftc format: "file.swift:line:column: error: message"
    let lines = output.components(separatedBy: .newlines)
    for line in lines where line.contains(": error:") {
      let parts = line.components(separatedBy: ":")
      guard parts.count >= 4 else { continue }

      let lineNum = Int(parts[1].trimmingCharacters(in: .whitespaces))
      let colNum = Int(parts[2].trimmingCharacters(in: .whitespaces))
      let message = parts.dropFirst(3).joined(separator: ":").trimmingCharacters(
        in: .whitespaces
      )

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

  /// Get SDK path for current platform
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
