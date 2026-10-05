import Foundation

struct GhostwriterTestingSupport {
  let frameworkSearchPaths: [URL]
  let compilerArguments: [String]
}

extension GhostwriterBuildContext {
  func testingSupport() -> GhostwriterTestingSupport? {
    #if os(macOS)
    return xcodeTestingSupport()
    #else
    let arguments =
      testingPluginPath(for: "swiftc")
      .map { ["-plugin-path", $0.path] } ?? []
    return GhostwriterTestingSupport(frameworkSearchPaths: [], compilerArguments: arguments)
    #endif
  }

  #if os(macOS)
  private func xcodeTestingSupport() -> GhostwriterTestingSupport? {
    let compilerLookup = ["/usr/bin/xcrun", "--toolchain", "default", "--find", "swiftc"]
    guard let sdkPath = commandOutput(["/usr/bin/xcrun", "--show-sdk-path"]),
      let compiler = commandOutput(compilerLookup),
      let plugin = testingPluginPath(for: compiler)
    else { return nil }

    let platformDeveloperDirectory = URL(fileURLWithPath: sdkPath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let xcodeDeveloperDirectory =
      platformDeveloperDirectory
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let toolchainsPath = xcodeDeveloperDirectory.appendingPathComponent("Toolchains").path + "/"
    let framework = platformDeveloperDirectory.appendingPathComponent("Library/Frameworks")
    guard compiler.hasPrefix(toolchainsPath), plugin.path.hasPrefix(toolchainsPath),
      FileManager.default.fileExists(
        atPath: framework.appendingPathComponent("Testing.framework").path
      )
    else { return nil }

    return GhostwriterTestingSupport(
      frameworkSearchPaths: [framework],
      compilerArguments: ["-plugin-path", plugin.path]
    )
  }
  #endif

  private func testingPluginPath(for compiler: String) -> URL? {
    guard let output = commandOutput([compiler, "-print-target-info"]),
      let data = output.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let paths = json["paths"] as? [String: Any],
      let runtimePath = paths["runtimeResourcePath"] as? String
    else { return nil }

    let resourceDirectory = URL(fileURLWithPath: runtimePath)
    let candidates = [resourceDirectory, resourceDirectory.deletingLastPathComponent()]
      .map { $0.appendingPathComponent("host/plugins/testing") }
    return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
  }

  private func commandOutput(_ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    return String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
