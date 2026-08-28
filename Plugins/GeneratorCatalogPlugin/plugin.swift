import Foundation
import PackagePlugin

@main
struct GeneratorCatalogPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let tool = try context.tool(named: "invariant-cli")

    let process = Process()
    process.executableURL = tool.url
    process.arguments = ["generators"] + arguments
    process.currentDirectoryURL = context.package.directoryURL
    process.environment = ProcessInfo.processInfo.environment
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      throw GeneratorCatalogPluginError.nonZeroExit(status: process.terminationStatus)
    }
  }
}

enum GeneratorCatalogPluginError: Error {
  case nonZeroExit(status: Int32)
}
