import Foundation

@main
struct CharacterizationCLI {
  static func main() {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.first == "characterize" else {
      write("Usage: characterize [--record|--verify] [--target <name>] [--filter <pattern>]")
      exit(arguments.isEmpty ? 0 : 2)
    }

    let mode = arguments.contains("--record") ? "record" : "verify"
    if arguments.contains("--record") && arguments.contains("--verify") {
      write("Use only one of --record or --verify.")
      exit(2)
    }

    if arguments.indices.contains(where: { targetIndex in
      arguments[targetIndex] == "--target"
        && (targetIndex + 1 >= arguments.count || arguments[targetIndex + 1].hasPrefix("--"))
    }) {
      write("--target requires a name.")
      exit(2)
    }

    let testArguments = swiftTestArguments(from: Array(arguments.dropFirst()))
    var environment = ProcessInfo.processInfo.environment
    environment["INVARIANT_CHARACTERIZATION_MODE"] = mode

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "test"] + testArguments
    process.currentDirectoryURL = URL(
      fileURLWithPath: FileManager.default.currentDirectoryPath
    )
    process.environment = environment

    do {
      try process.run()
      process.waitUntilExit()
      exit(process.terminationStatus)
    } catch {
      write("Failed to run Swift tests: \(error)")
      exit(1)
    }
  }

  private static func swiftTestArguments(from arguments: [String]) -> [String] {
    var result = [
      "--disable-sandbox",
      "--scratch-path",
      ".build/invariant-characterization",
    ]
    var index = 0
    while index < arguments.count {
      switch arguments[index] {
      case "--record", "--verify":
        index += 1

      case "--target":
        guard index + 1 < arguments.count else { return result }
        result += ["--filter", arguments[index + 1]]
        index += 2

      default:
        result.append(arguments[index])
        index += 1
      }
    }
    return result
  }

  private static func write(_ message: String) {
    let data = Data((message + "\n").utf8)
    FileHandle.standardError.write(data)
  }
}
