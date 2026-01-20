import Foundation
import PackagePlugin

@main
struct GeneratorCatalogPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let tool = try context.tool(named: "GeneratorCatalogCLI")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool.url.path)
    process.arguments = arguments

    // For interactive mode, connect to terminal
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      throw CatalogPluginError.nonZeroExit(status: process.terminationStatus)
    }
  }
}

enum CatalogPluginError: Error {
  case nonZeroExit(status: Int32)
}
