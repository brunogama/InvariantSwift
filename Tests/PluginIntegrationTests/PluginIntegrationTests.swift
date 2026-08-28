import Foundation
import Testing

@Suite("SwiftPM plugin adapters", .serialized)
struct PluginIntegrationTests {
  @Test("Full and binary manifests expose the same command products")
  func manifestParity() throws {
    let expectedProducts = [
      "invariant-cli", "InvariantSwiftPlugin", "GhostwriterPlugin", "GeneratorCatalogPlugin",
    ]

    for manifest in ["Package.swift", "Package.binary.swift"] {
      let contents = try String(contentsOfFile: packageRoot.appendingPathComponent(manifest).path)
      for product in expectedProducts {
        #expect(contents.contains("name: \"\(product)\""), "\(manifest) is missing \(product)")
      }
      for plugin in expectedProducts.dropFirst() {
        let declaration = try pluginDeclaration(named: plugin, in: contents)
        #expect(declaration.contains("dependencies: [\"invariant-cli\"]"))
        #expect(!declaration.contains("allowNetworkConnections"))
      }
    }
  }


  @Test("Adapters inherit process streams, environment, and package root")
  func adapterSourceContract() throws {
    let sources = [
      "Plugins/InvariantSwiftPlugin/plugin.swift",
      "Plugins/GhostwriterPlugin/plugin.swift",
      "Plugins/GeneratorCatalogPlugin/plugin.swift",
    ]
    for source in sources {
      let contents = try String(contentsOfFile: packageRoot.appendingPathComponent(source).path)
      #expect(contents.contains("context.tool(named: \"invariant-cli\")"))
      #expect(contents.contains("process.currentDirectoryURL = "))
      #expect(contents.contains("process.environment = "))
      #expect(contents.contains("process.standardInput = FileHandle.standardInput"))
      #expect(contents.contains("process.standardOutput = FileHandle.standardOutput"))
      #expect(contents.contains("process.standardError = FileHandle.standardError"))
      #expect(!contents.contains("print("))
    }
  }

  @Test("Adapter routes preserve direct output and package-root effects")
  func adapterOutputParity() throws {
    let fixture = try makeFixturePackage()
    defer { try? FileManager.default.removeItem(at: fixture) }
    try preparePluginTools(at: fixture)

    for route in routes {
      let direct = try runCLI(route.cliArguments, at: fixture)
      let adapter = try runPlugin(route.pluginVerb, arguments: route.pluginArguments, at: fixture)
      #expect(adapter.status == direct.status)
      #expect(adapter.stdout == direct.stdout)
      #expect(adapter.stderr == direct.stderr)
    }

    let report = try runPlugin(
      "invariant",
      arguments: ["report", "--output", "AdapterRoot/report", "--format", "json"],
      at: fixture
    )
    #expect(report.status == 0)
    #expect(
      FileManager.default.fileExists(
        atPath: fixture.appendingPathComponent("AdapterRoot/report.json").path
      )
    )
  }

  @Test("Adapters convert nonzero tool status to plugin failure")
  func adapterFailureConversion() throws {
    let fixture = try makeAdapterProbePackage()
    defer { try? FileManager.default.removeItem(at: fixture) }
    try preparePluginTools(at: fixture)

    for route in routes {
      let direct = try runProcess(
        executable: fixture.appendingPathComponent(".build/debug/invariant-cli"),
        arguments: route.cliArguments + ["--fail"],
        at: fixture
      )
      let adapter = try runPlugin(
        route.pluginVerb,
        arguments: route.pluginArguments + ["--fail"],
        at: fixture
      )
      #expect(direct.status == 23)
      #expect(adapter.status != 0)
    }
  }

  @Test("Adapters preserve arguments, cwd, and environment")
  func adapterProbeContract() throws {
    let fixture = try makeAdapterProbePackage()
    defer { try? FileManager.default.removeItem(at: fixture) }
    try preparePluginTools(at: fixture)

    let environment = ["PARENT_SENTINEL": "preserved"]
    for route in routes {
      let pluginArguments = ["first", "second value"]
      let directArguments = route.cliArguments.dropLast() + pluginArguments
      var directEnvironment = environment
      if route.pluginVerb == "invariant" {
        directEnvironment["FUNCTEST_PLUGIN_MODE"] = "true"
        directEnvironment["FUNCTEST_PACKAGE_PATH"] = fixture.path
        directEnvironment["FUNCTEST_PACKAGE_NAME"] = "AdapterProbe"
      }
      let direct = try runProcess(
        executable: fixture.appendingPathComponent(".build/debug/invariant-cli"),
        arguments: Array(directArguments),
        at: fixture,
        environment: directEnvironment
      )
      let adapter = try runPlugin(
        route.pluginVerb,
        arguments: pluginArguments,
        at: fixture,
        environment: environment
      )
      #expect(adapter.status == direct.status)
      #expect(adapter.stdout == direct.stdout)
      #expect(adapter.stderr == direct.stderr)
      #expect(adapter.stdout.contains("cwd=\(fixture.path)"))
      #expect(adapter.stdout.contains("parent=preserved"))
    }
  }
}

private struct AdapterRoute {
  let pluginVerb: String
  let pluginArguments: [String]
  let cliArguments: [String]
  let invalidPluginArguments: [String]
  let invalidCLIArguments: [String]
}

private let routes = [
  AdapterRoute(
    pluginVerb: "invariant",
    pluginArguments: ["help"],
    cliArguments: ["help"],
    invalidPluginArguments: ["not-a-command"],
    invalidCLIArguments: ["not-a-command"]
  ),
  AdapterRoute(
    pluginVerb: "ghostwrite",
    pluginArguments: ["--help"],
    cliArguments: ["ghostwrite", "--help"],
    invalidPluginArguments: ["--output"],
    invalidCLIArguments: ["ghostwrite", "--output"]
  ),
  AdapterRoute(
    pluginVerb: "browse-generators",
    pluginArguments: ["--help"],
    cliArguments: ["generators", "--help"],
    invalidPluginArguments: ["--search"],
    invalidCLIArguments: ["generators", "--search"]
  ),
]

private struct ProcessResult {
  let status: Int32
  let stdout: String
  let stderr: String
}

private func runCLI(_ arguments: [String], at directory: URL) throws -> ProcessResult {
  try runProcess(
    executable: packageRoot.appendingPathComponent(".build/debug/invariant-cli"),
    arguments: arguments,
    at: directory
  )
}

private func preparePluginTools(at directory: URL) throws {
  let result = try runPlugin("invariant", arguments: ["help"], at: directory)
  guard result.status == 0 else {
    throw FixtureError.pluginBuildFailed(result.stderr)
  }
}

private enum FixtureError: Error {
  case pluginBuildFailed(String)
}

private func runPlugin(
  _ verb: String,
  arguments: [String],
  at directory: URL,
  environment: [String: String] = [:]
) throws -> ProcessResult {
  try runProcess(
    executable: URL(fileURLWithPath: "/usr/bin/env"),
    arguments: [
      "swift", "package", "--quiet", "--allow-writing-to-package-directory", verb,
    ] + arguments,
    at: directory,
    environment: environment
  )
}

private func runProcess(
  executable: URL,
  arguments: [String],
  at directory: URL,
  environment additions: [String: String] = [:]
) throws -> ProcessResult {
  let process = Process()
  process.executableURL = executable
  process.arguments = arguments
  process.currentDirectoryURL = directory
  var environment = ProcessInfo.processInfo.environment
  for (key, value) in additions { environment[key] = value }
  process.environment = environment
  let captureDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("invariant-process-capture-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: captureDirectory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: captureDirectory) }

  let stdoutURL = captureDirectory.appendingPathComponent("stdout")
  let stderrURL = captureDirectory.appendingPathComponent("stderr")
  try Data().write(to: stdoutURL)
  try Data().write(to: stderrURL)
  let stdout = try FileHandle(forWritingTo: stdoutURL)
  let stderr = try FileHandle(forWritingTo: stderrURL)
  defer {
    try? stdout.close()
    try? stderr.close()
  }

  process.standardInput = FileHandle.nullDevice
  process.standardOutput = stdout
  process.standardError = stderr
  try process.run()
  process.waitUntilExit()
  try stdout.close()
  try stderr.close()
  return ProcessResult(
    status: process.terminationStatus,
    stdout: try String(contentsOf: stdoutURL, encoding: .utf8),
    stderr: try String(contentsOf: stderrURL, encoding: .utf8)
  )
}

private func makeFixturePackage() throws -> URL {
  let fixture = FileManager.default.temporaryDirectory
    .appendingPathComponent("invariant-plugin-fixture-\(UUID().uuidString)")
  try FileManager.default.copyItem(
    at: packageRoot.appendingPathComponent("Tests/PluginIntegrationTests/Fixtures/PluginClient"),
    to: fixture
  )
  let manifest = fixture.appendingPathComponent("Package.swift")
  var contents = try String(contentsOf: manifest, encoding: .utf8)
  contents = contents.replacingOccurrences(of: "__INVARIANT_PACKAGE_PATH__", with: packageRoot.path)
  try contents.write(to: manifest, atomically: true, encoding: .utf8)
  return fixture
}

private func makeAdapterProbePackage() throws -> URL {
  let fixture = URL(fileURLWithPath: "/private/tmp")
    .appendingPathComponent("invariant-adapter-probe-\(UUID().uuidString)")
  try FileManager.default.copyItem(
    at: packageRoot.appendingPathComponent("Tests/PluginIntegrationTests/Fixtures/AdapterProbe"),
    to: fixture
  )
  let plugins = ["InvariantSwiftPlugin", "GhostwriterPlugin", "GeneratorCatalogPlugin"]
  for plugin in plugins {
    let destination = fixture.appendingPathComponent("Plugins/\(plugin)")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try FileManager.default.copyItem(
      at: packageRoot.appendingPathComponent("Plugins/\(plugin)/plugin.swift"),
      to: destination.appendingPathComponent("plugin.swift")
    )
  }
  return fixture
}

private func pluginDeclaration(named name: String, in manifest: String) throws -> Substring {
  let marker = ".plugin(\n    name: \"\(name)\""
  let start = try #require(manifest.range(of: marker)?.lowerBound)
  let suffix = manifest[start...]
  let end = try #require(suffix.range(of: "\n  ),")?.upperBound)
  return suffix[..<end]
}

private let packageRoot: URL = {
  var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  while !FileManager.default.fileExists(
    atPath: directory.appendingPathComponent("Package.swift").path
  ) {
    let parent = directory.deletingLastPathComponent()
    precondition(parent != directory, "Package.swift not found")
    directory = parent
  }
  return directory
}()
