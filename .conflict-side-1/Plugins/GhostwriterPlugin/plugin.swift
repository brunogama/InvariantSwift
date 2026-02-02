import Foundation
import PackagePlugin

// MARK: - Ghostwriter Plugin

/// **Ghostwriter Plugin for Automatic Property Test Generation**
///
/// This plugin invokes the GhostwriterCLI (SwiftSyntax-powered) to analyze
/// Swift source files and generate property tests based on detected patterns.
///
/// **Usage:**
/// ```bash
/// swift package ghostwrite Sources/Models/
/// swift package ghostwrite --source Sources/User.swift --verbose
/// swift package ghostwrite --dry-run
/// ```

@main
struct GhostwriterPlugin: CommandPlugin {

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    // Find the GhostwriterCLI tool
    let tool = try context.tool(named: "GhostwriterCLI")
    let packageDirectory = context.package.directoryURL.path

    // Build the CLI arguments
    var cliArgs: [String] = []

    // Parse plugin arguments and translate to CLI arguments
    var i = 0
    var sources: [String] = []
    var outputDir: String?
    var dryRun = false
    var verbose = false

    while i < arguments.count {
      let arg = arguments[i]

      switch arg {
      case "--source", "-s":
        if i + 1 < arguments.count {
          let source = arguments[i + 1]
          if source.hasPrefix("/") {
            sources.append(source)
          } else {
            sources.append("\(packageDirectory)/\(source)")
          }
          i += 1
        }

      case "--output", "-o":
        if i + 1 < arguments.count {
          let output = arguments[i + 1]
          if output.hasPrefix("/") {
            outputDir = output
          } else {
            outputDir = "\(packageDirectory)/\(output)"
          }
          i += 1
        }

      case "--dry-run":
        dryRun = true

      case "--verbose", "-v":
        verbose = true

      case "--help", "-h":
        printHelp()
        return

      default:
        // Treat as source path
        if !arg.hasPrefix("-") {
          if arg.hasPrefix("/") {
            sources.append(arg)
          } else {
            sources.append("\(packageDirectory)/\(arg)")
          }
        }
      }

      i += 1
    }

    // Default to Sources/ if no sources specified
    if sources.isEmpty {
      sources = ["\(packageDirectory)/Sources/"]
    }

    // Build CLI arguments
    for source in sources {
      cliArgs.append("--source")
      cliArgs.append(source)
    }

    if let output = outputDir {
      cliArgs.append("--output")
      cliArgs.append(output)
    } else {
      cliArgs.append("--output")
      cliArgs.append("\(packageDirectory)/Tests/Generated/")
    }

    if dryRun {
      cliArgs.append("--dry-run")
    }

    if verbose {
      cliArgs.append("--verbose")
    }

    // Run the CLI
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool.url.path)
    process.arguments = cliArgs
    process.currentDirectoryURL = URL(fileURLWithPath: packageDirectory)

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    // Print output
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
      print(output)
    }

    if process.terminationStatus != 0 {
      throw GhostwriterPluginError.cliFailure(status: process.terminationStatus)
    }
  }

  private func printHelp() {
    print(
      """
      Ghostwriter - Automatic Property Test Generation (SwiftSyntax-Powered)

      USAGE:
          swift package ghostwrite [options] [sources...]

      OPTIONS:
          --source, -s <path>     Source file or directory to analyze
          --output, -o <path>     Output directory (default: Tests/Generated/)
          --dry-run               Preview without writing files
          --verbose, -v           Enable verbose output
          --help, -h              Show this help

      FEATURES:
          ✓ 100% accurate parsing with SwiftSyntax
          ✓ Detects extension conformances
          ✓ Detects @Arbitrary types
          ✓ Handles nested types correctly

      PATTERNS DETECTED:
          codable_roundtrip       Codable encode/decode roundtrip
          equatable_*             Equatable: reflexive, symmetric, transitive
          hashable_consistency    Hashable: equal values have equal hashes
          comparable_*            Comparable ordering laws

      EXAMPLES:
          swift package ghostwrite Sources/Models/
          swift package ghostwrite --source Sources/User.swift --verbose
          swift package ghostwrite --dry-run
      """
    )
  }
}

// MARK: - Errors

enum GhostwriterPluginError: Error, CustomStringConvertible {
  case cliFailure(status: Int32)

  var description: String {
    switch self {
    case .cliFailure(let status):
      return "GhostwriterCLI exited with status \(status)"
    }
  }
}
