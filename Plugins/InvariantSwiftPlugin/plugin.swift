import Foundation
import PackagePlugin

// MARK: - InvariantSwift Package Manager Plugin

/// **InvariantSwift Plugin for Advanced Property-Based Testing Integration**
///
/// This plugin enables seamless integration of property-based testing with Swift Package Manager,
/// providing build-time testing capabilities and comprehensive test automation.
///
/// **Features:**
/// - Integration with `swift package invariant` command
/// - Automatic test discovery and execution
/// - Build-time property testing with reporting
/// - Integration with CI/CD pipelines
/// - Test coverage analysis and reporting
/// - Corpus management and persistent example database
///
/// **Usage:**
/// ```bash
/// swift package invariant run --iterations 500 --report
/// swift package invariant corpus stats
/// swift package invariant benchmark --sizes 1,10,100
/// ```
///
/// **Mathematical Foundation:**
/// Based on property-based testing methodology from QuickCheck and Hypothesis,
/// integrated with Swift Package Manager's plugin architecture for seamless workflow integration.
///
/// **External References:**
/// - [Swift Package Manager Plugins](https://github.com/apple/swift-evolution/blob/main/proposals/0303-swiftpm-extensible-build-tools.md)
/// - [Property-Based Testing in Practice](https://hypothesis.readthedocs.io/en/latest/)

@main
struct InvariantSwiftPlugin: CommandPlugin {

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let characterizationCLIURL = try context.tool(named: "CharacterizationCLI").url
    let packageDirectoryURL = context.package.directoryURL

    // Parse command arguments
    var allArguments = [String]()
    let argumentExtractor = ArgumentExtractor(arguments)

    // Extract plugin-specific options
    let verbose = argumentExtractor.extractFlag(named: "verbose") != nil
    let reportPath = argumentExtractor.extractOption(named: "report")
    let iterations = argumentExtractor.extractOption(named: "iterations")
    let format = argumentExtractor.extractOption(named: "format")

    // Add remaining arguments
    allArguments.append(contentsOf: argumentExtractor.remainingArguments)

    if verbose {
      print("InvariantSwift Plugin Configuration:")
      print("   CLI Tool: \(characterizationCLIURL.path)")
      print("   Working Directory: \(packageDirectoryURL.path)")
      print("   Arguments: \(allArguments)")
      if let report = reportPath {
        print("   • Report Path: \(report)")
      }
      if let iter = iterations {
        print("   • Iterations: \(iter)")
      }
      print()
    }

    // Build additional arguments from plugin options
    if let reportPath = reportPath {
      allArguments.append("--report")
      allArguments.append(reportPath)
    }

    if let iterations = iterations {
      allArguments.append("--iterations")
      allArguments.append(iterations)
    }

    if let format = format {
      allArguments.append("--format")
      allArguments.append(format)
    }

    if verbose {
      allArguments.append("--verbose")
    }

    // Determine command (default to "run" if not specified)
    let command = allArguments.first ?? "run"
    var cliArguments = [command]
    if allArguments.count > 1 {
      cliArguments.append(contentsOf: Array(allArguments.dropFirst()))
    }

    // Execute the characterization CLI tool
    print("InvariantSwift: Running via Swift Package Manager Plugin")
    print("=" * 60)

    let process = Process()
    process.executableURL = characterizationCLIURL
    process.arguments = cliArguments
    process.currentDirectoryURL = packageDirectoryURL

    // Set up environment variables
    var environment = ProcessInfo.processInfo.environment
    environment["FUNCTEST_PLUGIN_MODE"] = "true"
    environment["FUNCTEST_PACKAGE_PATH"] = packageDirectoryURL.path
    environment["FUNCTEST_PACKAGE_NAME"] = context.package.displayName
    process.environment = environment

    if verbose {
      print("Executing: \(characterizationCLIURL.path) \(cliArguments.joined(separator: " "))")
      print()
    }

    do {
      try process.run()
      process.waitUntilExit()

      let exitCode = process.terminationStatus
      if exitCode != 0 {
        throw PluginError.executionFailed(
          "InvariantSwift CLI exited with code \(exitCode). Check the output above for details."
        )
      }

      if verbose {
        print("\nInvariantSwift plugin completed successfully!")
      }
    } catch {
      throw PluginError.executionFailed(
        "Failed to execute InvariantSwift CLI: \(error.localizedDescription)"
      )
    }
  }
}

// MARK: - Plugin Error Types

enum PluginError: Error, LocalizedError {
  case executionFailed(String)
  case configurationError(String)
  case missingDependency(String)

  var errorDescription: String? {
    switch self {
    case .executionFailed(let message):
      return "Execution failed: \(message)"

    case .configurationError(let message):
      return "Configuration error: \(message)"

    case .missingDependency(let message):
      return "Missing dependency: \(message)"
    }
  }
}

// MARK: - Plugin Utilities

extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}

// MARK: - ArgumentExtractor Helper

/// Helper class to extract plugin-specific arguments
private class ArgumentExtractor {
  private var arguments: [String]

  init(_ arguments: [String]) {
    self.arguments = arguments
  }

  var remainingArguments: [String] {
    arguments
  }

  func extractFlag(named name: String) -> String? {
    let patterns = ["--\(name)", "-\(name.prefix(1))"]

    for pattern in patterns {
      if let index = arguments.firstIndex(of: pattern) {
        arguments.remove(at: index)
        return pattern
      }
    }

    return nil
  }

  func extractOption(named name: String) -> String? {
    let patterns = ["--\(name)", "-\(name.prefix(1))"]

    for pattern in patterns {
      if let index = arguments.firstIndex(of: pattern),
        index + 1 < arguments.count
      {
        arguments.remove(at: index)  // Remove flag
        return arguments.remove(at: index)  // Remove and return value
      }
    }

    return nil
  }
}
