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
  private let baseDirectory: URL

  public init(
    verbose: Bool = false,
    baseDirectory: URL = FileManager.default.temporaryDirectory
  ) {
    self.verbose = verbose
    self.baseDirectory = baseDirectory
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
    let tempDir =
      baseDirectory
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
      var arguments = [
        "swiftc",
        "-typecheck",
        tempFile.path,
        "-I", ".build/debug",  // For module imports
      ]
      // Only Apple toolchains select an SDK this way; elsewhere swiftc
      // finds its own.
      if let sdk = sdkPath() {
        arguments += ["-sdk", sdk]
      }
      process.arguments = arguments

      let pipe = Pipe()
      process.standardError = pipe
      process.standardOutput = pipe

      try process.run()
      // Drain before waiting: swiftc can emit more than one pipe buffer of
      // diagnostics, and it cannot exit while blocked writing them.
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()

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

  /// The SDK path reported by xcrun, or nil where there is no xcrun.
  ///
  /// The launch failure must be handled before touching the pipe: if no child
  /// was spawned, this process still holds the pipe's write end, and reading
  /// the read end to EOF would block forever. That hung every test on Linux.
  private func sdkPath() -> String? {
    #if os(macOS)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["--show-sdk-path"]

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
      try process.run()
    } catch {
      return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let path =
      String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return path.isEmpty ? nil : path
    #else
    return nil
    #endif
  }
}
