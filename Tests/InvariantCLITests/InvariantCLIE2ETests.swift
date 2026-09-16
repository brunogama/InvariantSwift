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

  @Test("Saved searches persist across direct CLI processes")
  func savedFiltersPersist() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("invariant-filters-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let empty = try runCLI(["generators", "--filters"], currentDirectory: root)
    #expect(empty.status == 0)
    #expect(empty.stdout == "No saved filters.\n")
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)

    let saved = try runCLI(
      ["generators", "--save-filter", "numbers", "random", "integers"],
      currentDirectory: root
    )
    #expect(saved.status == 0)
    #expect(saved.stderr.isEmpty)
    let storage = root.appendingPathComponent(".invariant/saved-filters.json")
    let initial = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: storage))
    #expect(initial == ["numbers": "random integers"])

    let second = try runCLI(
      ["generators", "--save-filter", "strings", "printable ASCII"],
      currentDirectory: root
    )
    #expect(second.status == 0)

    let direct = try runCLI(["generators", "--search", "random integers"])
    let recalled = try runCLI(["generators", "--filter", "numbers"], currentDirectory: root)
    #expect(recalled.status == 0)
    #expect(recalled.stdout == direct.stdout)

    let replaced = try runCLI(
      ["generators", "--save-filter", "numbers", "random boolean"],
      currentDirectory: root
    )
    #expect(replaced.status == 0)
    let listed = try runCLI(["generators", "--filters"], currentDirectory: root)
    #expect(
      listed.stdout == "Saved filters:\n  numbers: random boolean\n  strings: printable ASCII\n"
    )
    let updated = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: storage))
    #expect(updated == ["numbers": "random boolean", "strings": "printable ASCII"])

    let deleted = try runCLI(["generators", "--delete-filter", "numbers"], currentDirectory: root)
    #expect(deleted.status == 0)
    #expect(
      try runCLI(["generators", "--filters"], currentDirectory: root).stdout
        == "Saved filters:\n  strings: printable ASCII\n"
    )
    #expect(
      try runCLI(["generators", "--delete-filter", "strings"], currentDirectory: root)
        .status == 0
    )
    #expect(
      try runCLI(["generators", "--filters"], currentDirectory: root).stdout
        == "No saved filters.\n"
    )
  }

  @Test("Saved search errors preserve corrupt storage")
  func savedFilterErrors() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("invariant-filter-errors-\(UUID().uuidString)")
    let directory = root.appendingPathComponent(".invariant")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let missing = try runCLI(["generators", "--filter", "missing"], currentDirectory: root)
    #expect(missing.status == 1)
    #expect(missing.stdout.isEmpty)
    #expect(missing.stderr.contains("unknown saved filter 'missing'"))

    let storage = directory.appendingPathComponent("saved-filters.json")
    let corrupt = Data("{broken json".utf8)
    try corrupt.write(to: storage)
    for arguments in [
      ["generators", "--filters"],
      ["generators", "--save-filter", "name", "query"],
      ["generators", "--delete-filter", "name"],
    ] {
      let result = try runCLI(arguments, currentDirectory: root)
      #expect(result.status == 1)
      #expect(result.stdout.isEmpty)
      #expect(result.stderr.contains("invalid saved filters"))
      #expect(try Data(contentsOf: storage) == corrupt)
    }

    let invalidMapping = Data("{\"bad name\":\"query\"}".utf8)
    try invalidMapping.write(to: storage)
    let invalid = try runCLI(["generators", "--filters"], currentDirectory: root)
    #expect(invalid.status == 1)
    #expect(invalid.stderr.contains("invalid saved filters"))

    try FileManager.default.removeItem(at: directory)
    try Data("not a directory".utf8).write(to: directory)
    let unwritable = try runCLI(
      ["generators", "--save-filter", "name", "query"],
      currentDirectory: root
    )
    #expect(unwritable.status == 1)
    #expect(unwritable.stderr.contains("failed to write"))
  }

  @Test("Interactive saved search commands accept the rest of the line")
  func interactiveSavedFilters() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("invariant-filter-interactive-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let input = """
      save-filter numbers random integers
      filters
      filter numbers
      delete-filter numbers
      quit
      """ + "\n"
    let result = try runCLI(
      ["generators", "--interactive"],
      currentDirectory: root,
      input: input
    )
    #expect(result.status == 0)
    #expect(result.stderr.isEmpty)
    #expect(result.stdout.contains("Saved filters:\n  numbers: random integers\n"))
    #expect(result.stdout.contains("Search Results for 'random integers'"))
    #expect(result.stdout.contains("Deleted filter 'numbers'."))
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
  environment additions: [String: String] = [:],
  input: String? = nil
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
  let standardInput = input.map { _ in Pipe() }
  if let standardInput { process.standardInput = standardInput }
  try process.run()
  if let input, let standardInput {
    standardInput.fileHandleForWriting.write(Data(input.utf8))
    try standardInput.fileHandleForWriting.close()
  }
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
