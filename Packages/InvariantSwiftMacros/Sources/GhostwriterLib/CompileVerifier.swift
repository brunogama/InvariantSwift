// MARK: - Compile Verification Infrastructure
// Verifies generated Swift code compiles using swiftc -typecheck before writing to disk.

import Foundation

/// The strongest check completed by ``CompileVerifier``.
public enum CompileVerificationLevel: String, Sendable {
  case syntax
  case typeCheck
}

/// Describes the outcome of a compiler verification operation.
public struct CompileVerificationResult: Sendable {
  /// Whether the requested verification level completed successfully.
  public let success: Bool
  /// Structured compiler diagnostics classified as errors.
  public let errors: [CompileError]
  /// The compiler's complete standard output and standard error text.
  public let output: String
  /// The strongest verification operation that was attempted.
  public let level: CompileVerificationLevel

  /// A structured Swift compiler error.
  public struct CompileError: Sendable {
    /// The one-based source line, when the compiler supplied one.
    public let line: Int?
    /// The one-based source column, when the compiler supplied one.
    public let column: Int?
    /// The diagnostic message.
    public let message: String
    /// The source file name associated with the verification request.
    public let file: String
  }
}

/// Verifies generated Swift code with the active `swiftc` toolchain.
public struct CompileVerifier: Sendable {
  /// A generated source file included in one compiler invocation.
  public struct SourceFile: Sendable {
    /// The file name used in compiler diagnostics.
    public let fileName: String
    /// The Swift source to type-check.
    public let code: String

    /// Creates a generated source file for batch verification.
    public init(fileName: String, code: String) {
      self.fileName = fileName
      self.code = code
    }
  }

  /// Inputs supplied by a real build context for a generated test type-check.
  public struct TypeCheckContext: Sendable {
    /// Directories containing Swift modules imported by generated code.
    public let moduleSearchPaths: [URL]
    /// Directories containing frameworks imported by generated code.
    public let frameworkSearchPaths: [URL]
    /// Additional arguments required by the consumer's compiler context.
    public let compilerArguments: [String]

    /// Creates compiler inputs discovered from a consumer build.
    public init(
      moduleSearchPaths: [URL],
      frameworkSearchPaths: [URL] = [],
      compilerArguments: [String] = []
    ) {
      self.moduleSearchPaths = moduleSearchPaths
      self.frameworkSearchPaths = frameworkSearchPaths
      self.compilerArguments = compilerArguments
    }
  }

  private let verbose: Bool
  private let baseDirectory: URL
  private let moduleCacheDirectory: URL
  private let typeCheckContext: TypeCheckContext

  /// - Parameters:
  ///   - verbose: Print progress while verifying.
  ///   - baseDirectory: Where the temporary source file is written.
  ///   - moduleSearchPaths: Directories to search for modules the code imports.
  ///     Empty by default. This used to be a hardcoded `-I .build/debug`, relative
  ///     to whatever directory the process happened to run in: inert where no such
  ///     directory existed, and where one did, it offered swiftc a second copy of
  ///     modules already loaded, so every snippet failed with "redefinition of
  ///     module" no matter how valid it was.
  public init(
    verbose: Bool = false,
    baseDirectory: URL = FileManager.default.temporaryDirectory,
    moduleSearchPaths: [URL] = []
  ) {
    self.verbose = verbose
    self.baseDirectory = baseDirectory
    self.moduleCacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "ghostwriter-module-cache"
    )
    self.typeCheckContext = TypeCheckContext(moduleSearchPaths: moduleSearchPaths)
  }

  /// Creates a verifier backed by compiler inputs discovered from SwiftPM.
  public init(
    verbose: Bool = false,
    baseDirectory: URL = FileManager.default.temporaryDirectory,
    typeCheckContext: TypeCheckContext
  ) {
    self.verbose = verbose
    self.baseDirectory = baseDirectory
    self.moduleCacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "ghostwriter-module-cache"
    )
    self.typeCheckContext = typeCheckContext
  }

  /// Verifies that generated code type-checks.
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
    runCompiler(
      code: code,
      fileName: fileName,
      level: .typeCheck,
      operationArguments: ["-typecheck"]
    )
  }

  /// Type-checks files from the same consumer module in one compiler invocation.
  public func verifyBatch(_ files: [SourceFile]) -> CompileVerificationResult {
    guard !files.isEmpty else {
      return CompileVerificationResult(success: true, errors: [], output: "", level: .typeCheck)
    }

    let tempDir = baseDirectory.appendingPathComponent("ghostwriter-verify-\(UUID().uuidString)")
    do {
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let paths = try files.enumerated().map { index, file in
        let path = tempDir.appendingPathComponent("\(index)-\(file.fileName)")
        try file.code.write(to: path, atomically: true, encoding: .utf8)
        return path
      }
      let arguments = compilerArguments(
        tempFiles: paths,
        level: .typeCheck,
        operationArguments: ["-typecheck"]
      )
      let processResult = try execute(arguments: arguments)
      return makeResult(processResult, fileName: "generated batch", level: .typeCheck)
    } catch {
      return failure(error, fileName: "generated batch", level: .typeCheck)
    }
  }

  /// Parses source without resolving imports, declarations, or macros.
  ///
  /// A successful result is explicitly marked ``CompileVerificationLevel/syntax``.
  /// Callers must not present it as a successful type-check.
  public func verifySyntax(
    code: String,
    fileName: String
  ) -> CompileVerificationResult {
    runCompiler(
      code: code,
      fileName: fileName,
      level: .syntax,
      operationArguments: ["-frontend", "-parse"]
    )
  }

  private func runCompiler(
    code: String,
    fileName: String,
    level: CompileVerificationLevel,
    operationArguments: [String]
  ) -> CompileVerificationResult {
    let tempDir =
      baseDirectory
      .appendingPathComponent("ghostwriter-verify-\(UUID().uuidString)")

    do {
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      defer {
        try? FileManager.default.removeItem(at: tempDir)
      }

      let tempFile = tempDir.appendingPathComponent(fileName)
      try code.write(to: tempFile, atomically: true, encoding: .utf8)

      reportStart(fileName: fileName, level: level)
      let invocation = compilerArguments(
        tempFiles: [tempFile],
        level: level,
        operationArguments: operationArguments
      )
      let processResult = try execute(arguments: invocation)
      return makeResult(processResult, fileName: fileName, level: level)
    } catch {
      return failure(error, fileName: fileName, level: level)
    }
  }

  private func compilerArguments(
    tempFiles: [URL],
    level: CompileVerificationLevel,
    operationArguments: [String]
  ) -> [String] {
    var arguments = ["swiftc"] + operationArguments + tempFiles.map(\.path)
    arguments += ["-module-cache-path", moduleCacheDirectory.path]

    guard level == .typeCheck else { return arguments }

    for searchPath in typeCheckContext.moduleSearchPaths {
      arguments += ["-I", searchPath.path]
    }
    for searchPath in typeCheckContext.frameworkSearchPaths {
      arguments += ["-F", searchPath.path]
    }
    arguments += typeCheckContext.compilerArguments
    if let sdk = sdkPath() {
      arguments += ["-sdk", sdk]
    }
    return arguments
  }

  private func execute(arguments: [String]) throws -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments

    let pipe = Pipe()
    process.standardError = pipe
    process.standardOutput = pipe

    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
  }

  private func makeResult(
    _ processResult: (status: Int32, output: String),
    fileName: String,
    level: CompileVerificationLevel
  ) -> CompileVerificationResult {
    guard processResult.status != 0 else {
      reportSuccess(level: level)
      return CompileVerificationResult(
        success: true,
        errors: [],
        output: processResult.output,
        level: level
      )
    }

    let errors = parseSwiftcErrors(processResult.output, fileName: fileName)
    return CompileVerificationResult(
      success: false,
      errors: errors,
      output: processResult.output,
      level: level
    )
  }

  private func failure(
    _ error: Error,
    fileName: String,
    level: CompileVerificationLevel
  ) -> CompileVerificationResult {
    CompileVerificationResult(
      success: false,
      errors: [
        CompileVerificationResult.CompileError(
          line: nil,
          column: nil,
          message: "Failed to verify: \(error.localizedDescription)",
          file: fileName
        )
      ],
      output: "",
      level: level
    )
  }

  private func reportStart(fileName: String, level: CompileVerificationLevel) {
    guard verbose else { return }
    let operation = level == .syntax ? "syntax" : "types"
    // swiftlint:disable:next no_print
    print("  Verifying \(operation) in \(fileName) with swiftc...")
  }

  private func reportSuccess(level: CompileVerificationLevel) {
    guard verbose else { return }
    let operation = level == .syntax ? "Syntax verification" : "Type-check verification"
    // swiftlint:disable:next no_print
    print("  \(operation) successful")
  }

  /// Parses `swiftc` error output into structured errors.
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
