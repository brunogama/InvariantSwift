import Foundation
import PackagePlugin

private struct GhostwriterBuildContextPayload: Encodable {
  struct Target: Encodable {
    let sourceDirectory: String
    let moduleName: String
  }

  let packageDirectory: String
  let targets: [Target]

  init(context: PluginContext) {
    packageDirectory = context.package.directoryURL.path
    targets = context.package.targets.compactMap { target in
      guard let sourceTarget = target as? any SourceModuleTarget else { return nil }
      return Target(
        sourceDirectory: sourceTarget.directory.string,
        moduleName: sourceTarget.moduleName
      )
    }
  }

  func encoded() throws -> String {
    let data = try JSONEncoder().encode(self)
    guard let encoded = String(bytes: data, encoding: .utf8) else {
      throw GhostwriterPluginError.contextEncodingFailure
    }
    return encoded
  }
}

private struct GhostwriterInvocation {
  private(set) var sources: [String] = []
  private(set) var outputDirectory: String?
  private(set) var dryRun = false
  private(set) var verbose = false
  private(set) var skipCompileTest = false
  private(set) var showHelp = false
  private(set) var subcommand: String?

  init(arguments: [String], packageDirectory: String) {
    var index = 0
    if arguments.first == "lawforge" {
      subcommand = "lawforge"
      index = 1
    }
    while index < arguments.count {
      let argument = arguments[index]
      let nextValue = arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
      if applyFlag(argument) {
        index += 1
        continue
      }

      switch argument {
      case "--source", "-s":
        if let nextValue {
          sources.append(Self.resolve(nextValue, relativeTo: packageDirectory))
          index += 1
        }

      case "--output", "-o":
        if let nextValue {
          outputDirectory = Self.resolve(nextValue, relativeTo: packageDirectory)
          index += 1
        }

      default:
        appendPositional(argument, packageDirectory: packageDirectory)
      }
      index += 1
    }

    addDefaultSourceIfNeeded(packageDirectory: packageDirectory)
  }

  private mutating func applyFlag(_ argument: String) -> Bool {
    switch argument {
    case "--dry-run": dryRun = true
    case "--verbose", "-v": verbose = true
    case "--skip-compile-test": skipCompileTest = true
    case "--help", "-h": showHelp = true
    default: return false
    }
    return true
  }

  func cliArguments(packageDirectory: String) -> [String] {
    var arguments = subcommand.map { [$0] } ?? []
    arguments += sources.flatMap { ["--source", $0] }
    let defaultOutput = subcommand == "lawforge" ? "Tests/LawForgeGenerated/" : "Tests/Generated/"
    arguments += ["--output", outputDirectory ?? "\(packageDirectory)/\(defaultOutput)"]
    if dryRun {
      arguments.append("--dry-run")
    }
    if verbose {
      arguments.append("--verbose")
    }
    if skipCompileTest {
      arguments.append("--skip-compile-test")
    }
    return arguments
  }

  private static func resolve(_ path: String, relativeTo packageDirectory: String) -> String {
    path.hasPrefix("/") ? path : "\(packageDirectory)/\(path)"
  }

  private mutating func appendPositional(_ argument: String, packageDirectory: String) {
    guard !argument.hasPrefix("-") else { return }
    sources.append(Self.resolve(argument, relativeTo: packageDirectory))
  }

  private mutating func addDefaultSourceIfNeeded(packageDirectory: String) {
    guard sources.isEmpty else { return }
    sources = ["\(packageDirectory)/Sources/"]
  }
}

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
/// swift package ghostwrite lawforge Sources/Models/
/// ```

@main
struct GhostwriterPlugin: CommandPlugin {

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let packageDirectory = context.package.directoryURL.path
    let invocation = GhostwriterInvocation(
      arguments: arguments,
      packageDirectory: packageDirectory
    )
    if invocation.showHelp {
      writeHelp()
      return
    }

    let tool = try context.tool(named: "GhostwriterCLI")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool.url.path)
    process.arguments = invocation.cliArguments(packageDirectory: packageDirectory)
    process.currentDirectoryURL = URL(fileURLWithPath: packageDirectory)
    var environment = ProcessInfo.processInfo.environment
    environment["INVARIANTSWIFT_GHOSTWRITER_BUILD_CONTEXT"] = try GhostwriterBuildContextPayload(
      context: context
    ).encoded()
    process.environment = environment

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    FileHandle.standardOutput.write(data)

    if process.terminationStatus != 0 {
      throw GhostwriterPluginError.cliFailure(status: process.terminationStatus)
    }
  }

  private func writeHelp() {
    let help = """
      Ghostwriter - Automatic Property Test Generation (SwiftSyntax-Powered)

      USAGE:
          swift package ghostwrite [options] [sources...]
          swift package ghostwrite lawforge [options] [sources...]

      OPTIONS:
          --source, -s <path>     Source file or directory to analyze
          --output, -o <path>     Output directory (default: Tests/Generated/)
          --dry-run               Preview without writing files
          --verbose, -v           Enable verbose output
          --skip-compile-test     Write tests without compiler verification
          --help, -h              Show this help

      FEATURES:
          SwiftSyntax analysis of type and extension conformances
          LawForge discovery followed by protocol and field law generation
          Automatic tests when a law recipe and generator are available
          Protocol law metadata for recipes needing extra prerequisites
          lawforge subcommand generates only candidate algebraic laws in pure Swift

      AUTOMATIC LAW FAMILIES:
          Equatable, Comparable, AdditiveArithmetic, Strideable
          BinaryInteger, FixedWidthInteger, FloatingPoint
          RawRepresentable, LosslessStringConvertible, CaseIterable
          Collection, BidirectionalCollection, RandomAccessCollection
          SetAlgebra, OptionSet

      EXAMPLES:
          swift package ghostwrite Sources/Models/
          swift package ghostwrite --source Sources/User.swift --verbose
          swift package ghostwrite --dry-run
      """
    FileHandle.standardOutput.write(Data(help.utf8))
  }
}

// MARK: - Errors

enum GhostwriterPluginError: Error, CustomStringConvertible {
  case cliFailure(status: Int32)
  case contextEncodingFailure

  var description: String {
    switch self {
    case .cliFailure(let status):
      return "GhostwriterCLI exited with status \(status)"

    case .contextEncodingFailure:
      return "Could not encode the SwiftPM build context as UTF-8"
    }
  }
}
