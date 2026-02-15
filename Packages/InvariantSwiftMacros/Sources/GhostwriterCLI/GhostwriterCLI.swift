// MARK: - Ghostwriter CLI
// Command-line interface for accurate source analysis and test generation.

import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Main Entry Point

@main
struct GhostwriterCLI {
  static let output: CLIOutput = StandardOutput()

  static func main() async throws {
    let arguments = CommandLine.arguments
    let config = parseArguments(arguments)

    if config.showHelp {
      printHelp(to: output)
      return
    }

    printBanner(to: output)
    printConfig(config, to: output)

    let result = try await run(config: config, output: output)

    printSummary(result, config: config, to: output)
  }
}

// MARK: - Configuration

extension GhostwriterCLI {
  struct Config {
    var sources: [String] = []
    var outputDirectory: String = "Tests/Generated/"
    var dryRun: Bool = false
    var verbose: Bool = false
    var showHelp: Bool = false
    var includeInternal: Bool = false
    var skipCompileTest: Bool = false
  }

  struct RunResult {
    var filesAnalyzed: Int = 0
    var typesFound: Int = 0
    var testableTypes: Int = 0
    var testsGenerated: Int = 0
    var generatedFiles: [String] = []
    var skippedCompile: Int = 0
  }
}

// MARK: - Argument Parsing

extension GhostwriterCLI {
  static func parseArguments(_ arguments: [String]) -> Config {
    var config = Config()
    var index = 1

    while index < arguments.count {
      index = processArgument(arguments, at: index, into: &config)
    }

    if config.sources.isEmpty {
      config.sources = ["Sources/"]
    }
    return config
  }

  private static func processArgument(
    _ arguments: [String],
    at index: Int,
    into config: inout Config
  ) -> Int {
    let arg = arguments[index]
    var nextIndex = index + 1

    if let handler = boolFlagHandlers[arg] {
      handler(&config)
      return nextIndex
    }

    if let handler = valueFlagHandlers[arg], nextIndex < arguments.count {
      handler(&config, arguments[nextIndex])
      return nextIndex + 1
    }

    if !arg.hasPrefix("-") {
      config.sources.append(arg)
    }

    return nextIndex
  }

  private static let boolFlagHandlers: [String: (inout Config) -> Void] = [
    "--dry-run": { $0.dryRun = true },
    "--verbose": { $0.verbose = true },
    "-v": { $0.verbose = true },
    "--help": { $0.showHelp = true },
    "-h": { $0.showHelp = true },
    "--include-internal": { $0.includeInternal = true },
    "--skip-compile-test": { $0.skipCompileTest = true },
  ]

  private static let valueFlagHandlers: [String: (inout Config, String) -> Void] = [
    "--source": { $0.sources.append($1) },
    "-s": { $0.sources.append($1) },
    "--output": { $0.outputDirectory = $1 },
    "-o": { $0.outputDirectory = $1 },
  ]
}

// MARK: - Output Helpers

extension GhostwriterCLI {
  static func printBanner(to out: CLIOutput) {
    out.write("Ghostwriter CLI - SwiftSyntax-Powered Test Generation")
    out.write(String(repeating: "=", count: 60))
  }

  static func printConfig(_ config: Config, to out: CLIOutput) {
    guard config.verbose else { return }
    out.write("Configuration:")
    out.write("   Sources: \(config.sources.joined(separator: ", "))")
    out.write("   Output: \(config.outputDirectory)")
    out.write("   Dry Run: \(config.dryRun)")
    out.write("")
  }

  static func printHelp(to out: CLIOutput) {
    out.write(
      """
      Ghostwriter CLI - SwiftSyntax-Powered Test Generation

      USAGE:
          GhostwriterCLI [options] [sources...]

      OPTIONS:
          --source, -s <path>     Source file or directory to analyze
          --output, -o <path>     Output directory (default: Tests/Generated/)
          --dry-run               Preview without writing files
          --verbose, -v           Enable verbose output
          --include-internal      Include internal types (default: only public/open)
          --skip-compile-test     Skip compile verification
          --help, -h              Show this help

      EXAMPLES:
          GhostwriterCLI Sources/Models/
          GhostwriterCLI --source Sources/User.swift --verbose
          GhostwriterCLI --dry-run Sources/
      """
    )
  }

  static func printSummary(_ result: RunResult, config: Config, to out: CLIOutput) {
    out.write("")
    out.write(String(repeating: "=", count: 60))
    out.write("Summary:")
    out.write("   Files Analyzed: \(result.filesAnalyzed)")
    out.write("   Types Found: \(result.typesFound)")
    out.write("   Testable Types: \(result.testableTypes)")
    out.write("   Tests Generated: \(result.testsGenerated)")

    if result.skippedCompile > 0 {
      out.write("\nSkipped \(result.skippedCompile) file(s) due to compilation errors")
      out.write("   Run with --verbose to see details or --skip-compile-test to write anyway")
    }

    if config.dryRun {
      out.write("\nDry run complete. No files were written.")
    } else if result.testsGenerated > 0 {
      out.write("\nTests generated successfully!")
      out.write("   Output: \(config.outputDirectory)")
    } else {
      out.write("\nNo tests generated.")
      out.write("   Ensure types conform to Codable, Equatable, Hashable, or Comparable.")
    }
  }
}
