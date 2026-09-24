import Foundation
import Testing

@testable import GhostwriterLib

@Suite("Ghostwriter compile pipeline")
struct GhostwriterCompilePipelineTests {
  @Test("Syntax verification is not reported as a type-check")
  func syntaxVerificationHasExplicitLevel() {
    let verifier = CompileVerifier()
    let code = "let value: TypeThatDoesNotExist = makeMissingValue()"

    let syntaxResult = verifier.verifySyntax(code: code, fileName: "Unresolved.swift")
    let typeCheckResult = verifier.verify(code: code, fileName: "Unresolved.swift")

    #expect(syntaxResult.success)
    #expect(syntaxResult.level == .syntax)
    #expect(typeCheckResult.success == false)
    #expect(typeCheckResult.level == .typeCheck)
  }

  @Test("Batch type-check accepts valid files and exposes failures for per-file fallback")
  func batchVerification() {
    let verifier = CompileVerifier()
    let valid = CompileVerifier.SourceFile(fileName: "Valid.swift", code: "struct Valid {}")
    let other = CompileVerifier.SourceFile(fileName: "Other.swift", code: "struct Other {}")
    let invalid = CompileVerifier.SourceFile(
      fileName: "Invalid.swift",
      code: "let missing: UnknownType = UnknownType()"
    )

    #expect(verifier.verifyBatch([valid, other]).success)
    #expect(verifier.verifyBatch([valid, invalid]).success == false)
    #expect(verifier.verify(code: valid.code, fileName: valid.fileName).success)
    #expect(verifier.verify(code: invalid.code, fileName: invalid.fileName).success == false)
  }

  @Test("CLI generates and type-checks a test in its SwiftPM context")
  func cliGenerationUsesSwiftPMContext() throws {
    let package = try packageRoot()
    let cli = try cliBinary(in: package)
    let sandbox = FileManager.default.temporaryDirectory
      .appendingPathComponent("ghostwriter-compile-pipeline-\(UUID().uuidString)")
    let sourceDirectory = sandbox.appendingPathComponent("Sources/Fixture")
    let outputDirectory = sandbox.appendingPathComponent("Generated")
    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: sandbox) }

    let source = sourceDirectory.appendingPathComponent("DiffFormat.swift")
    try Self.diffFormatFixture.write(to: source, atomically: true, encoding: .utf8)
    let result = try runCLI(
      .init(
        cli: cli,
        packageDirectory: package,
        source: source,
        sourceModule: "InvariantSwift",
        outputDirectory: outputDirectory
      )
    )

    #expect(result.status == 0, Comment(rawValue: result.output))
    #expect(
      result.output.contains("Type-checked DiffFormatPropertyTests.swift against InvariantSwift"),
      Comment(rawValue: result.output)
    )
    #expect(result.output.contains("type-check unavailable") == false)
    #expect(result.output.contains("warning:") == false, Comment(rawValue: result.output))
    let generated = try String(
      contentsOf: outputDirectory.appendingPathComponent("DiffFormatPropertyTests.swift"),
      encoding: .utf8
    )
    #expect(
      generated.hasPrefix(
        "// swiftlint:disable:next blanket_disable_command\n// swiftlint:disable all\n"
      )
    )
    #expect(generated.contains("// swiftformat:disable all"))
    #expect(generated.contains("// swift-format-ignore-file"))
    #expect(generated.contains("Gen.pure(ConsoleColor.black)"))
    #expect(generated.contains("test14_InvariantSwift_12_ConsoleColor_caseIterableContainsValue"))
    #expect(
      FileManager.default.fileExists(
        atPath: outputDirectory.appendingPathComponent("DiffFormatPropertyTests.swift").path
      ),
      Comment(rawValue: result.output)
    )
  }

  private func runCLI(_ request: RunRequest) throws -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = request.cli
    process.currentDirectoryURL = request.packageDirectory
    process.arguments = [
      "--source", request.source.path,
      "--output", request.outputDirectory.path,
      "--verbose",
    ]
    let buildContext = BuildContext(
      packageDirectory: request.packageDirectory.path,
      targets: [
        .init(
          sourceDirectory: request.source.deletingLastPathComponent().path,
          moduleName: request.sourceModule
        )
      ]
    )
    var environment = ProcessInfo.processInfo.environment
    let contextData = try JSONEncoder().encode(buildContext)
    environment["INVARIANTSWIFT_GHOSTWRITER_BUILD_CONTEXT"] = String(
      bytes: contextData,
      encoding: .utf8
    )
    process.environment = environment

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
  }

  private func packageRoot() throws -> URL {
    var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while candidate.path != "/" {
      let plugin = candidate.appendingPathComponent("Plugins/GhostwriterPlugin/plugin.swift")
      if FileManager.default.fileExists(atPath: plugin.path) {
        return candidate
      }
      candidate.deleteLastPathComponent()
    }
    throw PipelineTestError.packageRootNotFound
  }

  private func cliBinary(in package: URL) throws -> URL {
    let buildDirectory = package.appendingPathComponent(".build")
    guard
      let enumerator = FileManager.default.enumerator(
        at: buildDirectory,
        includingPropertiesForKeys: [.contentModificationDateKey]
      )
    else {
      throw PipelineTestError.cliNotFound
    }

    var matches: [URL] = []
    while let url = enumerator.nextObject() as? URL {
      if ["artifacts", "checkouts", "repositories"].contains(url.lastPathComponent) {
        enumerator.skipDescendants()
      } else if url.lastPathComponent == "GhostwriterCLI",
        FileManager.default.isExecutableFile(atPath: url.path)
      {
        matches.append(url)
      }
    }
    guard let cli = matches.max(by: { modificationDate($0) < modificationDate($1) }) else {
      throw PipelineTestError.cliNotFound
    }
    return cli
  }

  private func modificationDate(_ url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
      ?? .distantPast
  }

  private static let diffFormatFixture = """
    public struct DiffFormat: Sendable, Equatable {
      public let first: String
      public let second: String
      public let unchanged: String

      public init(first: String, second: String, unchanged: String) {
        self.first = first
        self.second = second
        self.unchanged = unchanged
      }
    }

    public enum ConsoleColor: String, CaseIterable, Sendable {
      case black = "30"
      case red = "31"
    }
    """
}

private struct BuildContext: Encodable {
  struct Target: Encodable {
    let sourceDirectory: String
    let moduleName: String
  }

  let packageDirectory: String
  let targets: [Target]
}

private struct RunRequest {
  let cli: URL
  let packageDirectory: URL
  let source: URL
  let sourceModule: String
  let outputDirectory: URL
}

private enum PipelineTestError: Error {
  case packageRootNotFound
  case cliNotFound
}
