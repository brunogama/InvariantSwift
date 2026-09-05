import Foundation
import PackagePlugin

@main
struct InvariantSwiftPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let tool = try context.tool(named: "invariant-cli")
    let packageDirectory = context.package.directoryURL

    let process = Process()
    process.executableURL = tool.url
    process.arguments = arguments
    process.currentDirectoryURL = packageDirectory
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    var environment = ProcessInfo.processInfo.environment
    environment["FUNCTEST_PLUGIN_MODE"] = "true"
    environment["FUNCTEST_PACKAGE_PATH"] = packageDirectory.path
    environment["FUNCTEST_PACKAGE_NAME"] = context.package.displayName
    process.environment = environment

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      throw InvariantPluginError.nonZeroExit(status: process.terminationStatus)
    }
  }
}

enum InvariantPluginError: Error {
  case nonZeroExit(status: Int32)
}
