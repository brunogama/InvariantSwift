import Foundation
import Testing
@testable import InvariantCLIKit

@Suite("Invariant CLI compatibility")
struct InvariantCLITests {
  @Test("Canonical command tree and aliases are stable")
  func commandTree() async throws {
    let harness = CLIHarness()
    let result = await harness.run([])
    #expect(result.status == 0)
    let expectedTree = try fixture("command-tree.txt")
    #expect(result.stdout == expectedTree)
    #expect(result.stderr.isEmpty)

    let commands = [
      "run", "report", "corpus", "benchmark", "characterize", "ghostwrite",
      "generators", "interactive", "version", "help",
    ]
    for command in commands {
      #expect(InvariantCommandParser.parse([command]).command?.name == command)
    }
    #expect(InvariantCommandParser.parse(["--help"]).command?.name == "help")
    #expect(InvariantCommandParser.parse(["-h"]).command?.name == "help")
    #expect(InvariantCommandParser.parse(["generators", "-i"]).command?.name == "generators")
  }

  @Test("Defaults match the accepted compatibility matrix")
  func defaults() {
    #expect(InvariantCommandParser.parse(["run"]).command == .run(.init()))
    #expect(InvariantCommandParser.parse(["report"]).command == .report(.init()))
    #expect(InvariantCommandParser.parse(["benchmark"]).command == .benchmark(.init()))
    #expect(InvariantCommandParser.parse(["characterize"]).command == .characterize(.init()))
    #expect(InvariantCommandParser.parse(["ghostwrite"]).command == .ghostwrite(.init()))
    #expect(
      InvariantCommandParser.parse(["generators", "--interactive"]).command
        == .generators(.interactive)
    )
  }

  @Test("Short and long options produce equivalent requests")
  func optionAliases() {
    let shortRun = InvariantCommandParser.parse([
      "run", "-i", "7", "-s", "9", "-t", "2.5", "-r", "result.txt", "-v",
    ])
    let longRun = InvariantCommandParser.parse([
      "run", "--iterations", "7", "--max-shrinks", "9", "--timeout", "2.5",
      "--report", "result.txt", "--verbose",
    ])
    #expect(shortRun.command == longRun.command)

    let shortReport = InvariantCommandParser.parse([
      "report", "-o", "result", "-f", "csv", "--include-corpus", "--no-stats",
    ])
    let longReport = InvariantCommandParser.parse([
      "report", "--output", "result", "--format", "csv", "--include-corpus", "--no-stats",
    ])
    #expect(shortReport.command == longReport.command)

    let shortGhostwrite = InvariantCommandParser.parse([
      "ghostwrite", "-s", "Sources/A.swift", "-o", "Generated", "-v",
      "--include-internal", "--skip-compile-test", "--dry-run",
    ])
    let positionalGhostwrite = InvariantCommandParser.parse([
      "ghostwrite", "Sources/A.swift", "--output", "Generated", "--verbose",
      "--include-internal", "--skip-compile-test", "--dry-run",
    ])
    #expect(shortGhostwrite.command == positionalGhostwrite.command)
  }

  @Test("Usage errors use stderr and status two")
  func usageErrors() async {
    for arguments in [
      ["unknown"], ["run", "--iterations"], ["run", "--iterations", "nope"],
      ["report", "--format", "xml"], ["characterize", "--record", "--verify"],
      ["characterize", "--target"], ["generators", "--search"],
    ] {
      let result = await CLIHarness().run(arguments)
      #expect(result.status == 2)
      #expect(result.stdout.isEmpty)
      #expect(result.stderr.contains("error:"))
    }
  }

  @Test("Safe legacy unknown options warn for the compatibility window")
  func compatibilityWarning() async {
    let result = await CLIHarness().run(["run", "--legacy-safe-flag"])
    #expect(result.status == 0)
    #expect(result.stderr == "warning: ignoring deprecated unknown option '--legacy-safe-flag'\n")
  }

  @Test("JSON and CSV reports retain their machine schemas")
  func reportGoldens() throws {
    let date = try #require(ISO8601DateFormatter().date(from: "2026-01-02T03:04:05Z"))
    let renderer = ReportRenderer(now: { date })
    let expectedJSON = try fixture("report.json")
    let expectedCSV = try fixture("report.csv")
    #expect(renderer.render(format: .json) == expectedJSON)
    #expect(renderer.render(format: .csv) == expectedCSV)
  }

  @Test("Report resolves paths from cwd and writes only its selected format")
  func reportFileEffect() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("invariant-cli-report-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let harness = CLIHarness(currentDirectory: root.path)
    let result = await harness.run(["report", "--output", "artifacts/result", "--format", "csv"])
    #expect(result.status == 0)
    #expect(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("artifacts/result.csv").path
      )
    )
    #expect(
      !FileManager.default.fileExists(
        atPath: root.appendingPathComponent("artifacts/result.json").path
      )
    )
  }

  @Test("Characterize preserves child status, cwd, environment, and scratch isolation")
  func characterizeProcessContract() async throws {
    let runner = RecordingProcessRunner(status: 73)
    let harness = CLIHarness(
      currentDirectory: "/tmp/package-root",
      environment: ["CALLER_VALUE": "preserved"],
      processRunner: runner
    )
    let result = await harness.run([
      "characterize", "--record", "--target", "CharacterizationTests", "--parallel",
    ])

    #expect(result.status == 73)
    let request = await runner.lastRequest
    #expect(request?.executable == "/usr/bin/env")
    #expect(
      request?.arguments == [
        "swift", "test", "--disable-sandbox", "--scratch-path", ".build/invariant-characterization",
        "--filter", "CharacterizationTests", "--parallel",
      ]
    )
    #expect(request?.currentDirectory == "/tmp/package-root")
    #expect(request?.environment["CALLER_VALUE"] == "preserved")
    #expect(request?.environment["INVARIANT_CHARACTERIZATION_MODE"] == "record")
  }

  @Test("Read-only commands do not write package files")
  func readOnlyEffects() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("invariant-cli-read-only-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    for arguments in [["generators", "--list"], ["ghostwrite", "--dry-run", "Missing"]] {
      _ = await CLIHarness(currentDirectory: root.path).run(arguments)
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
  }
}

func fixture(_ name: String) throws -> String {
  let url = try #require(
    Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
  )
  return try String(contentsOf: url, encoding: .utf8)
}

private struct CLIResult {
  let status: Int32
  let stdout: String
  let stderr: String
}

private struct CLIHarness {
  var currentDirectory = FileManager.default.currentDirectoryPath
  var environment = ProcessInfo.processInfo.environment
  var processRunner: any ProcessRunning = RecordingProcessRunner(status: 0)

  func run(_ arguments: [String]) async -> CLIResult {
    let output = MemoryCLIOutput()
    let cli = InvariantCLI(
      output: output,
      processRunner: processRunner,
      currentDirectory: currentDirectory,
      environment: environment
    )
    let status = await cli.run(arguments: arguments)
    return CLIResult(status: status, stdout: output.stdout, stderr: output.stderr)
  }
}

private actor RecordingProcessRunner: ProcessRunning {
  let status: Int32
  private(set) var lastRequest: ProcessRequest?

  init(status: Int32) { self.status = status }

  func run(_ request: ProcessRequest) async throws -> Int32 {
    lastRequest = request
    return status
  }
}
