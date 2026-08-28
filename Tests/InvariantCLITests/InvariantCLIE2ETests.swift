import Foundation
import Testing

@Suite("invariant-cli direct executable")
struct InvariantCLIE2ETests {
  @Test("Direct help preserves stdout, stderr, and status")
  func directHelp() throws {
    let result = try runCLI(["help"])
    let expected = try fixture("command-tree.txt")
    #expect(result.status == 0)
    #expect(result.stdout == expected)
    #expect(result.stderr.isEmpty)
  }

  @Test("Direct unknown command is a usage error")
  func directUnknownCommand() throws {
    let result = try runCLI(["not-a-command"])
    #expect(result.status == 2)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr == "error: unknown command 'not-a-command'\n")
  }

  @Test("Direct characterize uses package cwd, inherited environment, and isolated scratch")
  func directCharacterizeContract() throws {
    let source = try #require(
      Bundle.module.url(
        forResource: "CharacterizationPackage",
        withExtension: nil,
        subdirectory: "Fixtures"
      )
    )
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("invariant-characterize-\(UUID().uuidString)")
    try FileManager.default.copyItem(at: source, to: root)
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runCLI(
      ["characterize", "--verify"],
      currentDirectory: root,
      environment: [
        "EXPECTED_PACKAGE_ROOT": root.path,
        "PARENT_SENTINEL": "preserved",
      ]
    )
    #expect(result.status == 0)
    #expect(result.stderr.contains("Building for debugging"))
    #expect(!result.stderr.contains("Failed to run Swift tests"))
    #expect(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent(".build/invariant-characterization").path
      )
    )
    #expect(
      !FileManager.default.fileExists(atPath: root.appendingPathComponent(".build/debug").path)
    )
  }
}

private struct ExecutableResult {
  let status: Int32
  let stdout: String
  let stderr: String
}

private func runCLI(
  _ arguments: [String],
  currentDirectory: URL? = nil,
  environment additions: [String: String] = [:]
) throws -> ExecutableResult {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: cliPath())
  process.arguments = arguments
  process.currentDirectoryURL = currentDirectory
  var environment = ProcessInfo.processInfo.environment
  for (key, value) in additions { environment[key] = value }
  process.environment = environment
  let standardOutput = Pipe()
  let standardError = Pipe()
  process.standardOutput = standardOutput
  process.standardError = standardError
  try process.run()
  process.waitUntilExit()
  let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
  let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
  return ExecutableResult(
    status: process.terminationStatus,
    stdout: String(data: outputData, encoding: .utf8) ?? "",
    stderr: String(data: errorData, encoding: .utf8) ?? ""
  )
}

private func cliPath() -> String {
  var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  while !FileManager.default.fileExists(
    atPath: directory.appendingPathComponent("Package.swift").path
  ) {
    let parent = directory.deletingLastPathComponent()
    if parent == directory { break }
    directory = parent
  }
  return directory.appendingPathComponent(".build/debug/invariant-cli").path
}
