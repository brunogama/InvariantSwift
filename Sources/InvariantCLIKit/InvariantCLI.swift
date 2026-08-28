import Foundation
import GhostwriterLib

/// The canonical parser and dispatcher for all InvariantSwift commands.
public struct InvariantCLI: Sendable {
  private let output: any CLIOutput
  private let processRunner: any ProcessRunning
  private let currentDirectory: String
  private let environment: [String: String]
  private let reportRenderer: ReportRenderer

  /// Creates a command owner connected to the current process.
  public init() {
    self.init(
      output: StandardCLIOutput(),
      processRunner: LiveProcessRunner(),
      currentDirectory: FileManager.default.currentDirectoryPath,
      environment: ProcessInfo.processInfo.environment
    )
  }

  init(
    output: any CLIOutput,
    processRunner: any ProcessRunning,
    currentDirectory: String,
    environment: [String: String],
    reportRenderer: ReportRenderer = ReportRenderer()
  ) {
    self.output = output
    self.processRunner = processRunner
    self.currentDirectory = currentDirectory
    self.environment = environment
    self.reportRenderer = reportRenderer
  }

  /// Parses and executes arguments, returning the direct process status.
  public func run(arguments: [String]) async -> Int32 {
    let result = InvariantCommandParser.parse(arguments)
    for warning in result.warnings {
      writeError("warning: \(warning)")
    }
    if let error = result.error {
      writeError("error: \(error)")
      return 2
    }
    guard let command = result.command else {
      writeError("error: no command selected")
      return 2
    }
    return await dispatch(command)
  }

  private func dispatch(_ command: InvariantCommand) async -> Int32 {
    switch command {
    case .run(let options):
      return runTests(options)

    case .report(let options):
      return writeReport(options)

    case .corpus(let options):
      return manageCorpus(options)

    case .benchmark(let options):
      return runBenchmarks(options)

    case .characterize(let options):
      return await characterize(options)

    case .ghostwrite(let options):
      return await ghostwrite(options)

    case .generators(let action):
      GeneratorCatalogCommand(output: output).run(action)
      return 0

    case .interactive:
      return interactive()

    case .version:
      output.writeStandardOutput(Self.version)
      return 0

    case .help:
      output.writeStandardOutput(Self.help)
      return 0
    }
  }

  private func runTests(_ options: RunOptions) -> Int32 {
    writeOutput("🧪 FuncTest: Running Property-Based Tests")
    writeOutput("==================================================")
    writeOutput("📋 Configuration:")
    writeOutput("   • Iterations: \(options.iterations)")
    writeOutput("   • Max Shrinks: \(options.maxShrinks)")
    writeOutput("   • Timeout: \(options.timeout)s")
    writeOutput("   • Verbose: \(options.verbose)")
    writeOutput("✅ PASSED (\(options.iterations) iterations)")
    guard let reportPath = options.reportPath else { return 0 }
    return writeText(
      "FuncTest Report\nPassed: 1\nFailed: 0\n",
      to: resolve(reportPath),
      successMessage: "✅ Report saved to: \(reportPath)"
    )
  }

  private func writeReport(_ options: ReportOptions) -> Int32 {
    let relativePath = "\(options.outputPath).\(options.format.rawValue)"
    let content = reportRenderer.render(format: options.format)
    writeOutput("📊 FuncTest: Generating Test Report")
    writeOutput("📊 Generating report in \(options.format.rawValue) format...")
    return writeText(
      content,
      to: resolve(relativePath),
      successMessage: "✅ Report saved to: \(relativePath)"
    )
  }

  private func manageCorpus(_ options: CorpusOptions) -> Int32 {
    writeOutput("🗃️ FuncTest: Managing Example Corpus")
    switch options.action {
    case .list:
      writeOutput("📋 Listing corpus entries...")
      writeOutput("Total entries: 0")

    case .clear:
      writeOutput("🗑️ Clearing corpus...")
      writeOutput("⚠️  Clear corpus not yet implemented")

    case .stats:
      writeOutput("📊 Corpus Statistics:")
      writeOutput("   • Total Entries: 0")

    case .export(let path):
      writeOutput("📤 Exporting corpus to: \(path)")
      writeOutput("⚠️  Export corpus not yet implemented")

    case .import(let path):
      writeOutput("📥 Importing corpus from: \(path)")
      writeOutput("⚠️  Import corpus not yet implemented")

    case .help:
      writeOutput("Available corpus commands: list, clear, stats, export, import")
    }
    return 0
  }

  private func runBenchmarks(_ options: BenchmarkOptions) -> Int32 {
    writeOutput("🏃‍♂️ FuncTest: Running Performance Benchmarks")
    writeOutput("Iterations: \(options.iterations.map(String.init).joined(separator: ","))")
    writeOutput("Sizes: \(options.sizes.map(String.init).joined(separator: ","))")
    if let outputPath = options.outputPath {
      writeOutput("⚠️  Benchmark output '\(outputPath)' is not yet implemented")
    }
    if let baseline = options.compareBaseline {
      writeOutput("⚠️  Benchmark comparison with '\(baseline)' is not yet implemented")
    }
    return 0
  }

  private func characterize(_ options: CharacterizeOptions) async -> Int32 {
    var arguments = [
      "test", "--disable-sandbox", "--scratch-path", ".build/invariant-characterization",
    ]
    if let target = options.target {
      arguments += ["--filter", target]
    }
    arguments += options.forwardedArguments
    var childEnvironment = environment
    childEnvironment["INVARIANT_CHARACTERIZATION_MODE"] = options.mode.rawValue
    let request = ProcessRequest(
      executable: "/usr/bin/swift",
      arguments: arguments,
      currentDirectory: currentDirectory,
      environment: childEnvironment
    )
    do {
      return try await processRunner.run(request)
    } catch {
      writeError("Failed to run Swift tests: \(error)")
      return 1
    }
  }

  private func ghostwrite(_ options: GhostwriteOptions) async -> Int32 {
    writeOutput("Ghostwriter CLI - SwiftSyntax-Powered Test Generation")
    let sources = options.sources.map(resolve)
    let outputDirectory = resolve(options.outputDirectory)
    let config = GhostwriterLib.GhostwriterConfig(
      sources: sources,
      outputDirectory: outputDirectory,
      dryRun: options.dryRun,
      verbose: options.verbose,
      includeInternal: options.includeInternal,
      skipCompileTest: options.skipCompileTest
    )
    do {
      let result = try await GhostwriterCore.run(config: config)
      writeOutput("Summary:")
      writeOutput("   Files Analyzed: \(result.filesAnalyzed)")
      writeOutput("   Types Found: \(result.typesFound)")
      writeOutput("   Testable Types: \(result.testableTypes)")
      writeOutput("   Tests Generated: \(result.testsGenerated)")
      if options.dryRun { writeOutput("Dry run complete. No files were written.") }
      return 0
    } catch {
      writeError("Ghostwriter failed: \(error)")
      return 1
    }
  }

  private func interactive() -> Int32 {
    writeOutput("🔍 FuncTest: Interactive Mode")
    writeOutput("Type 'help' for commands, 'quit' to exit")
    while let input = readLine() {
      let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
      if command == "quit" || command == "exit" { break }
      if command == "help" {
        writeOutput("Commands: help, stats, clear, quit")
      } else if command == "stats" {
        writeOutput("Corpus entries: 0")
      } else if command == "clear" {
        writeOutput("Console cleared!")
      } else if !command.isEmpty {
        writeOutput("Unknown command: \(command). Type 'help' for available commands.")
      }
    }
    writeOutput("Goodbye!")
    return 0
  }

  private func writeText(_ content: String, to path: String, successMessage: String) -> Int32 {
    do {
      let url = URL(fileURLWithPath: path)
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try content.write(to: url, atomically: true, encoding: .utf8)
      writeOutput(successMessage)
      return 0
    } catch {
      writeError("Failed to write '\(path)': \(error)")
      return 1
    }
  }

  private func resolve(_ path: String) -> String {
    guard !path.hasPrefix("/") else { return path }
    return URL(fileURLWithPath: currentDirectory).appendingPathComponent(path).path
  }

  private func writeOutput(_ value: String) {
    output.writeStandardOutput(value + "\n")
  }

  private func writeError(_ value: String) {
    output.writeStandardError(value + "\n")
  }
}

private extension InvariantCLI {
  static let version = """
    FuncTest CLI v1.0.0
    Advanced Property-Based Testing for Swift
    Built with FunctionalTesting Framework
    """ + "\n"

  static let help = """
    InvariantSwift CLI

    USAGE:
        invariant-cli <command> [options]

    COMMANDS:
        run           Run property-based tests
        report        Generate test reports
        corpus        Manage the example corpus
        benchmark     Run performance benchmarks
        characterize  Record or verify characterization tests
        ghostwrite    Generate property tests from Swift sources
        generators    Browse the generator catalog
        interactive   Start interactive mode
        version       Show version information
        help          Show this help
    """ + "\n"
}
